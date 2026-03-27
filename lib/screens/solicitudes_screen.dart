import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/mototaxi_socket_service.dart';
import 'package:geolocator/geolocator.dart';

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
    // Reemplaza el hilo de threading.Thread en Kivy
    _socketService.conectar().listen((mensaje) {
      final data = jsonDecode(mensaje);
      // Si hay un nuevo_viaje o cancelacion, recargamos la lista
      if (data['type'] == 'nuevo_viaje' || data['type'] == 'cancelar_viaje') {
        _cargarViajes();
      }
    });
  }

  Future<void> _cargarViajes() async {
    final viajes = await _authService.obtenerViajesDisponibles(); // Hay que crear este en AuthService
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
      appBar: AppBar(
        title: const Text("Viajes Disponibles"),
        backgroundColor: const Color(0xFFF7931E),
      ),
      body: _estaCargando || _viajes.isEmpty
          ? _buildWaitingState()
          : ListView.builder(
              itemCount: _viajes.length,
              itemBuilder: (context, index) => _buildSolicitudItem(_viajes[index]),
            ),
    );
  }

  // Equivalente al MDSpinner y etiquetas de pendientes.kv
  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFF7931E)),
          const SizedBox(height: 20),
          const Text("No hay solicitudes disponibles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text("Las nuevas solicitudes aparecerán aquí automáticamente.", style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Equivalente a tu PendienteItem de Kivy
  Widget _buildSolicitudItem(dynamic viaje) {
    final TextEditingController _tarifaController = TextEditingController(text: viaje['costo_estimado'].toString());

    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(viaje['pasajero_foto'] ?? 'https://via.placeholder.com/150'),
              ),
              title: Text("Usuario: ${viaje['pasajero_nombre']}"),
              subtitle: Text("Pasajeros: ${viaje['cantidad_pasajeros']}\nDistancia: ${viaje['distancia_km']} km"),
            ),
            // Referencia (como el MDDialog que mostrabas en Kivy)
            if (viaje['referencia'] != null)
              Text("📍 Ref: ${viaje['referencia']}", style: const TextStyle(fontStyle: FontStyle.italic)),
            
            // Campo para que el mototaxista sugiera su propia tarifa
            TextField(
              controller: _tarifaController,
              decoration: const InputDecoration(hintText: "Tu tarifa"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _enviarOferta(viaje['id'], _tarifaController.text),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF7931E)),
              child: const Text("Sugerir Tarifa", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _enviarOferta(int viajeId, String monto) async {
    final exito = await _authService.enviarOferta(viajeId, monto);
    if (exito) {
      // Si la oferta se envía, el mototaxista pasa a esperar respuesta
      Navigator.pushNamed(context, '/esperando_confirmacion');
    }
  }

  @override
  void dispose() {
    _socketService.desconectar();
    super.dispose();
  }

void _iniciarRastreoUbicacion() async {
  // 1. Verificar permisos
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) return;
  }

  // 2. Obtener ubicación actual una vez para limpiar el error de Django inmediatamente
  Position position = await Geolocator.getCurrentPosition();
  await _authService.actualizarUbicacion(position.latitude, position.longitude);

  // // 3. Escuchar cambios de movimiento (opcional, para mantenerlo fresco)
  // Geolocator.getPositionStream(
  //   locationSettings: const LocationSettings(
  //     accuracy: LocationAccuracy.high,
  
  //     distanceFilter: 50, // Se actualiza cada 50 metros
  //   ),
  // ).listen((Position position) {
  //   _authService.actualizarUbicacion(position.latitude, position.longitude);
  //   print("📍 Ubicación actualizada: ${position.latitude}, ${position.longitude}");
  // });
}
}