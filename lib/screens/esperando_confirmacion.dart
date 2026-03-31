import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/viaje_socket_service.dart';
import '../services/mototaxi_socket_service.dart';
import '../services/auth_service.dart';

class EsperandoConfirmacionScreen extends StatefulWidget {
  const EsperandoConfirmacionScreen({super.key});

  @override
  State<EsperandoConfirmacionScreen> createState() => _EsperandoConfirmacionScreenState();
}

class _EsperandoConfirmacionScreenState extends State<EsperandoConfirmacionScreen> with SingleTickerProviderStateMixin {
  final _viajeSocket = ViajeSocketService();
  final _motoSocket = MototaxiSocketService();
  final _authService = AuthService();
  
  bool _cancelando = false;
  int? _viajeId; // Variable local para evitar leer SharedPreferences múltiples veces
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _iniciarConexiones();
    
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0.5,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  void _iniciarConexiones() async {
    final prefs = await SharedPreferences.getInstance();
    final idGuardado = prefs.getInt('current_viaje_id');

    if (idGuardado != null) {
      setState(() => _viajeId = idGuardado);
      print("DEBUG: Conectando sockets para viaje ID: $_viajeId");

      // 1. Canal específico del viaje
      _viajeSocket.conectar(_viajeId!).listen((mensaje) {
        final data = jsonDecode(mensaje);
        print("DEBUG WS VIAJE: ${data['type']}");

        if (data['type'] == 'oferta_aceptada') {
          // Navegar a la pantalla de éxito (asegúrate que el nombre coincida en main.dart)
          if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/aceptar_viaje', (route) => false);
        }
        
        if (data['type'] == 'viaje_cancelado') {
          _finalizarYSalir("El pasajero canceló el viaje.");
        }
      }, onError: (err) => print("Error en WS Viaje: $err"));

      // 2. Canal general de mototaxi
      _motoSocket.conectar().listen((mensaje) {
        final data = jsonDecode(mensaje);
        // Comparación segura convirtiendo ambos a String
        if (data['type'] == 'cancelar_viaje') {
          _finalizarYSalir("Este viaje ya no está disponible.");
        }
      });
    } else {
      print("⚠️ Error: viajeId no encontrado en SharedPreferences.");
      if (mounted) Navigator.pushReplacementNamed(context, '/solicitudes');
    }
  }

  void _finalizarYSalir(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
      Navigator.pushNamedAndRemoveUntil(context, '/solicitudes', (route) => false);
    }
  }

  void _retirarOferta() async {
    if (_viajeId == null) return; // Seguridad contra null

    setState(() => _cancelando = true);
    // Asegúrate que tu authService.cancelarOfertaPropia() use el ID local o lo busque bien
    final exito = await _authService.cancelarOfertaPropia();
  
    if (mounted) {
      if (exito) {
        Navigator.pushNamedAndRemoveUntil(context, '/solicitudes', (route) => false);
      } else {
        setState(() => _cancelando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo retirar la oferta")),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _viajeSocket.desconectar();
    _motoSocket.desconectar();
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
              // Tamaño fijo para que el pulso no desplace el texto
              SizedBox(
                height: 220,
                child: Stack(
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
              ),
              const SizedBox(height: 30),
              const Text(
                "Oferta enviada",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "El pasajero está revisando tu propuesta.\nMantente atento.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 50),
              if (!_cancelando)
                TextButton(
                  onPressed: _viajeId == null ? null : _retirarOferta,
                  child: const Text(
                    "RETIRAR MI OFERTA",
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                )
              else
                const CircularProgressIndicator(color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

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