import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class AceptarViajeScreen extends StatefulWidget {
  const AceptarViajeScreen({super.key});

  @override
  State<AceptarViajeScreen> createState() => _AceptarViajeScreenState();
}

class _AceptarViajeScreenState extends State<AceptarViajeScreen> {
  final _authService = AuthService();
  String _infoViaje = "Cargando datos del viaje...";
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDetallesViaje();
  }

  void _cargarDetallesViaje() async {
    // Al igual que en cargar_viaje_en_curso de Kivy [cite: 35]
    final viaje = await _authService.obtenerViajeActual();
    
    if (viaje != null) {
      setState(() {
        _infoViaje = "Oferta Aceptada por el pasajero ${viaje['pasajero_nombre']}\n"
                     "Distancia: ${viaje['distancia_km']} km\n"
                     "Total a cobrar: \$${viaje['costo_final']}";
        _cargando = false;
      });
    } else {
      // Si no hay viaje, volvemos a solicitudes [cite: 35]
      Navigator.pushReplacementNamed(context, '/solicitudes');
    }
  }

  void _iniciarViaje() async {
    final viaje = await _authService.obtenerViajeActual();
    // Implementación de iniciar_viaje 
    final exito = await _authService.cambiarEstadoViaje(viaje!["id"]);
    
    if (exito) {
      // Si el cambio de estado en Django es exitoso, vamos a la pantalla de ruta
      Navigator.pushReplacementNamed(context, '/viaje_en_curso');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al iniciar el viaje")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/moto_koonex.png", // [cite: 36]
                height: 100,
              ),
              const SizedBox(height: 30),
              Text(
                _infoViaje, // [cite: 37]
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),
              if (!_cargando)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _iniciarViaje, // 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF7931E), // Naranja Koonex [cite: 42]
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25), // [cite: 43]
                      ),
                    ),
                    child: const Text(
                      "Iniciar viaje",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}