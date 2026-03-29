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

class _EsperandoConfirmacionScreenState extends State<EsperandoConfirmacionScreen> with SingleTickerProviderStateMixin {
  final _socketService = ViajeSocketService();
  final _authService = AuthService();
  bool _cancelando = false;
  
  // Controlador para la animación de radar
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _escucharDecisionPasajero();
    
    // Configuración de la animación de pulso
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0.5,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  void _escucharDecisionPasajero() async {
    final prefs = await SharedPreferences.getInstance();
    final viajeId = prefs.getInt('current_viaje_id');

    if (viajeId != null) {
      _socketService.conectar(viajeId).listen((mensaje) {
        final data = jsonDecode(mensaje);
        
        if (data['type'] == 'oferta_aceptada') {
          if (mounted) Navigator.pushReplacementNamed(context, '/viaje_en_curso_moto');
        }
        
        if (data['type'] == 'viaje_cancelado') {
          _volverASolicitudes("El pasajero ha cancelado el viaje o aceptó otra oferta.");
        }
      });
    }
  }

  void _retirarOferta() async {
    setState(() => _cancelando = true);
    final exito = await _authService.cancelarOfertaPropia();
  
    if (exito) {
      if (mounted) Navigator.pushReplacementNamed(context, '/solicitudes');
    } else {
      if (mounted) {
        setState(() => _cancelando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo retirar la oferta")),
        );
      }
    }
  }

  void _volverASolicitudes(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      Navigator.pushReplacementNamed(context, '/solicitudes');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _socketService.desconectar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Animación de Radar/Pulso
              Stack(
                alignment: Alignment.center,
                children: [
                  _buildPulse(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7931E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.moped, color: Colors.white, size: 40),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              
              // 2. Textos Informativos
              const Text(
                "Oferta enviada",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 12),
              Text(
                "El pasajero está revisando tu propuesta. Mantente atento a la confirmación.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.4),
              ),
              
              const SizedBox(height: 60),

              // 3. Tarjeta de "Tips" o Estado (Opcional, mejora la estética)
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFF7931E), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "No cierres esta pantalla para no perder la conexión.",
                        style: TextStyle(color: Colors.orange[900], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 4. Botón de Retirar Oferta (Estilo Limpio)
              if (!_cancelando)
                TextButton(
                  onPressed: _retirarOferta,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  child: const Text(
                    "RETIRAR MI OFERTA",
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                )
              else
                const CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  // Widget que crea el efecto de ondas de radar
  Widget _buildPulse() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _buildCircle(150 * _controller.value, 1.0 - _controller.value),
            _buildCircle(200 * _controller.value, 1.0 - _controller.value),
          ],
        );
      },
    );
  }

  Widget _buildCircle(double radius, double opacity) {
    return Container(
      width: radius,
      height: radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF7931E).withOpacity(opacity),
      ),
    );
  }
}