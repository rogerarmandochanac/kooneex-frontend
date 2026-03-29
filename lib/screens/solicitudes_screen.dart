import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/mototaxi_socket_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  final _socketService = MototaxiSocketService();
  final _authService = AuthService();
  List<dynamic> _viajes = [];
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    _iniciarRastreoUbicacion();
    _iniciarEscucha();
    _cargarViajes();
  }

  void _iniciarEscucha() {
    _socketService.conectar().listen((mensaje) {
      final data = jsonDecode(mensaje);
      if (data['type'] == 'nuevo_viaje' || data['type'] == 'cancelar_viaje') {
        _cargarViajes();
      }
    });
  }

  Future<void> _cargarViajes() async {
    final viajes = await _authService.obtenerViajesDisponibles();
    if (mounted) {
      setState(() {
        _viajes = viajes;
        _estaCargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Viajes Solicitados",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFF7931E)),
            onPressed: _cargarViajes,
          )
        ],
      ),
      body: _estaCargando 
          ? _buildLoadingState()
          : _viajes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _viajes.length,
                  itemBuilder: (context, index) => _buildSolicitudItem(_viajes[index]),
                ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFF7931E), strokeWidth: 5),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.moped_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 20),
          const Text("Sin viajes cerca", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)),
          const Text("Te avisaremos cuando alguien pida un viaje", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSolicitudItem(dynamic viaje) {
    // Usamos un controlador local para cada item de la lista
    final TextEditingController _tarifaController = TextEditingController(text: viaje['costo_estimado'].toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: NetworkImage(viaje['pasajero_foto'] ?? 'https://via.placeholder.com/150'),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viaje['pasajero_nombre'] ?? "Usuario",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text("${viaje['cantidad_pasajeros']} pas.", style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(width: 12),
                          Icon(Icons.near_me_outlined, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text("${viaje['distancia_km']} km", style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 30, thickness: 0.5),

            if (viaje['referencia'] != null && viaje['referencia'].toString().isNotEmpty) ...[
              const Text("REFERENCIA", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 5),
              Text(
                "📍 ${viaje['referencia']}",
                style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87),
              ),
              const SizedBox(height: 20),
            ],

            const Text("TU OFERTA (\$)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 10),
            
            Row(
              children: [
                // Input de Tarifa más Pro
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TextField(
                      controller: _tarifaController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        prefixText: "\$ ",
                        prefixStyle: TextStyle(color: Color(0xFFF7931E), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // Botón de Enviar
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _enviarOferta(viaje['id'], _tarifaController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF7931E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("ENVIAR OFERTA", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _enviarOferta(int viajeId, String monto) async {
    // Pequeña validación antes de enviar
    if (monto.isEmpty || double.tryParse(monto) == null || double.parse(monto) <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ingresa un monto válido")),
      );
      return;
    }

    final exito = await _authService.enviarOferta(viajeId, monto);
    if (exito) {
      if (mounted) Navigator.pushNamed(context, '/esperando_confirmacion');
    } else {
      if (mounted) {
        final prefs = await await SharedPreferences.getInstance();
        await prefs.setInt('current_viaje_id', viajeId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al enviar oferta. Intenta de nuevo.")),
        );
      }
    }
  }

  @override
  void dispose() {
    _socketService.desconectar();
    super.dispose();
  }

  void _iniciarRastreoUbicacion() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    await _authService.actualizarUbicacion(position.latitude, position.longitude);
  }
}