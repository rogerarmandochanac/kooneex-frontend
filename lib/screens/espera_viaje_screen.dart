import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/viaje_socket_service.dart';
import '../services/auth_service.dart';

class EsperaViajeScreen extends StatefulWidget {
  const EsperaViajeScreen({super.key});

  @override
  State<EsperaViajeScreen> createState() => _EsperaViajeScreenState();
}

class _EsperaViajeScreenState extends State<EsperaViajeScreen> {
  final _socketService = ViajeSocketService();
  final _authService = AuthService();
  String _nombreMototaxista = "Cargando...";

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  void _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final viajeId = prefs.getInt('current_viaje_id');
    
    // Opcional: Podrías traer el nombre del moto desde SharedPreferences si lo guardaste al aceptar
    setState(() {
      _nombreMototaxista = prefs.getString('moto_nombre_actual') ?? "el mototaxista";
    });

    if (viajeId != null) {
      _socketService.conectar(viajeId).listen((mensaje) {
        final data = jsonDecode(mensaje);
        
        // 🔥 Cuando el mototaxista inicia el viaje en su app
        if (data['type'] == 'viaje_en_curso') {
          Navigator.pushReplacementNamed(context, '/viaje_en_curso');
        }

        // Si por alguna razón se cancela
        if (data['type'] == 'viaje_cancelado') {
          Navigator.pushReplacementNamed(context, '/home_pasajero');
        }
      });
    }
  }

  @override
  void dispose() {
    _socketService.desconectar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(30),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de espera animado o imagen
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 30),
            Text(
              "¡Oferta aceptada!",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Esperando que $_nombreMototaxista inicie el recorrido.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Color(0xFFF7931E)),
            const SizedBox(height: 50),
            
            // Botón de emergencia o cancelación por si el moto no llega
            TextButton(
              onPressed: () => _confirmarCancelacion(),
              child: const Text("¿El mototaxista no responde? Cancelar", style: TextStyle(color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }

  void _confirmarCancelacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Cancelar viaje?"),
        content: const Text("Si el mototaxista tarda demasiado puedes cancelar, pero esto podría afectar tu reputación."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ESPERAR")),
          TextButton(
            onPressed: () async {
              await _authService.eliminarViaje();
              Navigator.pushNamedAndRemoveUntil(context, '/home_pasajero', (route) => false);
            }, 
            child: const Text("SÍ, CANCELAR", style: TextStyle(color: Colors.red))
          ),
        ],
      )
    );
  }
}