import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/viaje_socket_service.dart';
import '../services/auth_service.dart';

class EsperandoConfirmacionScreen extends StatefulWidget {
  const EsperandoConfirmacionScreen({super.key});

  @override
  State<EsperandoConfirmacionScreen> createState() => _EsperandoConfirmacionScreenState();
}

class _EsperandoConfirmacionScreenState extends State<EsperandoConfirmacionScreen> {
  final _socketService = ViajeSocketService();
  final _authService = AuthService();
  bool _cancelando = false;

  @override
  void initState() {
    super.initState();
    _escucharDecisionPasajero();
  }

  void _escucharDecisionPasajero() async {
    final prefs = await SharedPreferences.getInstance();
    final viajeId = prefs.getInt('current_viaje_id');

    if (viajeId != null) {
      _socketService.conectar(viajeId).listen((mensaje) {
        final data = jsonDecode(mensaje);
        
        // Si el pasajero acepta nuestra oferta
        if (data['type'] == 'oferta_aceptada') {
          // Aquí podrías guardar datos extras si el socket los envía
          Navigator.pushReplacementNamed(context, '/viaje_en_curso_moto');
        }
        
        // Si el pasajero rechaza o el viaje se cancela
        if (data['type'] == 'viaje_cancelado') {
          _volverASolicitudes("El viaje ha sido cancelado por el pasajero.");
        }
      });
    }
  }

  void _retirarOferta() async {
    setState(() => _cancelando = true);
    // Llamamos a la lógica de 'rechazar' que tienes en tu ViewSet de Django
    final exito = await _authService.cancelarOfertaPropia();
    
    if (exito) {
      Navigator.pop(context); // Volver a la lista de solicitudes
    } else {
      setState(() => _cancelando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo cancelar la oferta")),
      );
    }
  }

  void _volverASolicitudes(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
    Navigator.pushReplacementNamed(context, '/solicitudes');
  }

  @override
  void dispose() {
    _socketService.desconectar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Un Spinner grande y naranja como en tu diseño Kivy
            const CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF7931E)),
            ),
            const SizedBox(height: 40),
            const Text(
              "Esperando confirmación",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Tu oferta ha sido enviada al pasajero. Mantente en esta pantalla para recibir la respuesta.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 50),
            
            // Botón para arrepentirse (como el 'close' de tarifa.kv)
            if (!_cancelando)
              OutlinedButton.icon(
                onPressed: _retirarOferta,
                icon: const Icon(Icons.close, color: Colors.red),
                label: const Text("Retirar oferta", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              )
            else
              const Text("Cancelando...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}