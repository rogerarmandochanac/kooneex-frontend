import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/viaje_socket_service.dart';

class EsperaViajeScreen extends StatefulWidget {
  const EsperaViajeScreen({super.key});

  @override
  State<EsperaViajeScreen> createState() => _EsperaViajeScreenState();
}

class _EsperaViajeScreenState extends State<EsperaViajeScreen> with SingleTickerProviderStateMixin {
  final _socketService = ViajeSocketService();
  String _nombreMototaxista = "Cargando...";
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _inicializar();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0.6,
    )..repeat();
  }

  void _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final viajeId = prefs.getInt('current_viaje_id');
    
    setState(() {
      _nombreMototaxista = prefs.getString('moto_nombre_actual') ?? "el mototaxista";
    });

    if (viajeId != null) {
      _socketService.conectar(viajeId).listen((mensaje) {
        final data = jsonDecode(mensaje);
        
        if (data['type'] == 'viaje_en_curso') {
          if(mounted) Navigator.pushReplacementNamed(context, '/viaje_en_curso');
        }

        if (data['type'] == 'viaje_cancelado') {
          if(mounted) Navigator.pushReplacementNamed(context, '/viaje');
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _socketService.desconectar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centrado vertical total
            children: [
              // 1. Área de Animación con tamaño fijo (SizedBox)
              // Esto evita que el texto se desplace cuando la onda crece
              SizedBox(
                height: 200, 
                width: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildPulse(),
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 50),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 2. Textos informativos centrados
              const Text(
                "¡Oferta Aceptada!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 15),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 17, color: Colors.grey, height: 1.5),
                  children: [
                    const TextSpan(text: "Estamos esperando que "),
                    TextSpan(
                      text: _nombreMototaxista,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const TextSpan(text: " inicie el recorrido hacia tu ubicación."),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              // 3. Indicador de carga
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF7931E)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulse() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          // Definimos que el pulso no exceda el tamaño del SizedBox padre
          width: 180 * _pulseController.value,
          height: 180 * _pulseController.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withOpacity(1.0 - _pulseController.value),
          ),
        );
      },
    );
  }
}