import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AceptarViajeScreen extends StatefulWidget {
  const AceptarViajeScreen({super.key});

  @override
  State<AceptarViajeScreen> createState() => _AceptarViajeScreenState();
}

class _AceptarViajeScreenState extends State<AceptarViajeScreen> {
  final _authService = AuthService();
  
  // Variables de estado originales
  String _pasajeroNombre = "";
  String _distancia = "";
  String _costoFinal = "";
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDetallesViaje();
  }

  void _cargarDetallesViaje() async {
    // Tu lógica original de AuthService
    final viaje = await _authService.obtenerViajeActual();
    
    if (mounted) {
      if (viaje != null) {
        setState(() {
          // Separamos los datos para darles estilos individuales Pro
          _pasajeroNombre = viaje['pasajero_nombre'] ?? "Pasajero";
          _distancia = "${viaje['distancia_km']} km";
          _costoFinal = "\$${viaje['costo_final']}";
          _cargando = false;
        });
      } else {
        // Tu lógica original de navegación
        Navigator.pushReplacementNamed(context, '/solicitudes');
      }
    }
  }

  void _iniciarViaje() async {
    // Tu lógica original de inicio de viaje
    setState(() => _cargando = true); // Mostramos carga en el botón
    
    final viaje = await _authService.obtenerViajeActual();
    if (viaje != null) {
      final exito = await _authService.cambiarEstadoViaje(viaje["id"]);
      
      if (mounted) {
        if (exito) {
          // Tu navegación original
          Navigator.pushReplacementNamed(context, '/viaje_en_curso');
        } else {
          setState(() => _cargando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error al iniciar el viaje en el servidor"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo Blanco Pro
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false, // Sin botón de atrás
        title: const Text("Confirmación de Viaje", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _cargando && _pasajeroNombre.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF7931E)))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    const Spacer(),
                    
                    // 1. Icono visual de éxito (Trato Hecho)
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green[100]!, width: 2),
                      ),
                      child: const Icon(Icons.handshake_rounded, color: Colors.green, size: 70),
                    ),
                    const SizedBox(height: 30),
                    
                    const Text(
                      "¡Oferta Aceptada!",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "El pasajero ha confirmado tu tarifa. Revisa los detalles finales antes de arrancar.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.4),
                    ),
                    
                    const SizedBox(height: 50),

                    // 2. Tarjeta de Detalles del Viaje (Estilo Pro con Sombras Suaves)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: Colors.grey[100]!),
                      ),
                      child: Column(
                        children: [
                          // Fila del Pasajero
                          _buildDetailRow(Icons.person_outline, "Pasajero", _pasajeroNombre, isBold: true),
                          const Divider(height: 30, thickness: 0.5),
                          // Fila de Distancia
                          _buildDetailRow(Icons.map_outlined, "Distancia", _distancia),
                          const Divider(height: 30, thickness: 0.5),
                          // Fila del Costo (Resaltado)
                          _buildDetailRow(
                            Icons.payments_outlined, 
                            "Total a cobrar", 
                            _costoFinal, 
                            valueColor: const Color(0xFFF7931E),
                            isPrice: true
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // 3. Botón Principal (Ancho completo y alto para pulgar fácil)
                    if (!_cargando)
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _iniciarViaje, // Tu función original
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF7931E), // Naranja Koonex
                            foregroundColor: Colors.white,
                            elevation: 0, // Diseño plano Pro
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "COMENZAR RECORRIDO",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ),
                      )
                    else
                      const CircularProgressIndicator(color: Color(0xFFF7931E)),
                      
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget auxiliar para las filas de detalles dentro de la tarjeta
  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor, bool isBold = false, bool isPrice = false}) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 22),
        const SizedBox(width: 15),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: isPrice ? 22 : 16, 
            fontWeight: (isBold || isPrice) ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}