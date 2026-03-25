import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/viaje_socket_service.dart'; // El servicio creado arriba

class OfertasScreen extends StatefulWidget {
  const OfertasScreen({super.key});
  

  @override
  State<OfertasScreen> createState() => _OfertasScreenState();
}

class _OfertasScreenState extends State<OfertasScreen> {
  final _socketService = ViajeSocketService();
  final _authService = AuthService();
  List<dynamic> _ofertas = [];
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    // Aquí es donde en Kivy llamabas a conectar_ws_viaje()
    _escucharOfertas();
  }

  Future<void> _escucharOfertas() async {
    // 1. Obtener el ID del viaje guardado (como hacías en App.get_running_app())
    final prefs = await SharedPreferences.getInstance();
    final viajeId = prefs.getInt('current_viaje_id');
    if (viajeId != null) {
      // 2. Cargar ofertas iniciales vía HTTP (como en on_enter de tarifa.py) 
      await _cargarOfertasIniciales();

      // 3. Conectar al Stream del WebSocket
      _socketService.conectar(viajeId).listen((mensaje) {
        final data = jsonDecode(mensaje);
        
        // Manejar tipos de mensajes igual que en Kivy 
        if (data['type'] == 'nueva_oferta' || data['type'] == 'oferta_cancelada') {
          print("💰 Cambio en ofertas detectado vía WS");
          _cargarOfertasIniciales(); // Recargamos la lista
        }
      });
    }
  }

  Future<void> _cargarOfertasIniciales() async {
    setState(() => _estaCargando = true);
    // Llamada a tu API de /ofertas/
    final resultado = await _authService.obtenerOfertas(); 
    setState(() {
      _ofertas = resultado;
      _estaCargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFA), // Color sutil de tu MDCard [cite: 26]
      appBar: AppBar(
        title: const Text("Ofertas de Mototaxistas"),
        backgroundColor: const Color(0xFFF7931E),
        automaticallyImplyLeading: false, // Evita volver atrás [cite: 25]
      ),
      body: _estaCargando || _ofertas.isEmpty
          ? _buildWaitingState()
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _ofertas.length,
              itemBuilder: (context, index) => _buildOfertaItem(_ofertas[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _cancelarViaje,
        backgroundColor: Colors.red,
        child: const Icon(Icons.close, color: Colors.white), // Botón cancelar de Kivy [cite: 25]
      ),
    );
  }

  // Estado de espera con Spinner (Equivalente al MDSpinner de tarifa.kv )
  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFF7931E)),
          const SizedBox(height: 20),
          const Text(
            "Esperando ofertas disponibles...",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            child: Text(
              "Las nuevas solicitudes aparecerán aquí automáticamente.", // Texto original 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  // Elemento de la lista (Equivalente a TarifaItem [cite: 26])
  Widget _buildOfertaItem(dynamic oferta) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(oferta['foto'] ?? 'https://via.placeholder.com/150'),
              ),
              title: Text("Mototaxista: ${oferta['nombre']}", 
                  style: const TextStyle(fontWeight: FontWeight.bold)), // [cite: 30]
              subtitle: Text("Tarifa sugerida: \$${oferta['monto']} MXN",
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)), // [cite: 31]
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _aceptarOferta(oferta['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Aceptar", style: TextStyle(color: Colors.white)), // [cite: 35]
              ),
            )
          ],
        ),
      ),
    );
  }

  void _aceptarOferta(int id) {
    // Lógica para enviar el PATCH a /ofertas/{id}/aceptar/ 
  }

  void _cancelarViaje() {
    // Lógica para el DELETE de /viajes/{id}/eliminar/ 
  }
}