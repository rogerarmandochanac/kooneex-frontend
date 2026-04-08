import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/mototaxi_socket_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  // CLAVE PARA CONTROLAR EL DRAWER
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final _socketService = MototaxiSocketService();
  final _authService = AuthService();
  
  List<dynamic> _viajes = [];
  bool _estaCargando = true;
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    _iniciarRastreoUbicacion();
    _configurarEscuchaSocket();
    _cargarViajes();
    _initPushNotifications();
  }

  // --- LÓGICA DE SOCKETS Y NOTIFICACIONES ---

  void _configurarEscuchaSocket() {
    _socketSubscription = _socketService.conectar().listen(
      (mensaje) {
        final data = jsonDecode(mensaje);
        if (data['type'] == 'nuevo_viaje' || data['type'] == 'cancelar_viaje') {
          _cargarViajes();
        }
      },
      onError: (err) => debugPrint("Error en socket solicitudes: $err"),
      cancelOnError: false,
    );
  }

  void _initPushNotifications() async {
    await PushNotificationService.initializeApp();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'nueva_solicitud') {
        _cargarViajes(); 
        _showSnackBar("${message.notification?.body}");
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

    String formatImageUrl(String? url) {
      if (url == null || url.isEmpty) return '';
      
      // Si la URL trae el puerto 8000, lo eliminamos para que pase por Nginx (puerto 80)
      if (url.contains(':8000')) {
        return url.replaceFirst(':8000', '');
      }
      
      return url;
    }

  // --- INTERFAZ: DRAWER (SIN FOTO DE PERFIL) ---

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.80,
      child: Column(
        children: [
          // Cabecera simple con Icono
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.white),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Color(0xFFF7931E),
              child: Icon(Icons.person, color: Colors.white, size: 40),
            ),
            accountName: Text("Conductor Kooneex", 
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            accountEmail: Text("Ver perfil", 
              style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.black87),
            title: const Text("Cambiar Contraseña"),
            onTap: () {
              Navigator.pop(context); 
              Navigator.pushNamed(context, '/cambiar-password'); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.black87),
            title: const Text("Mis Servicios"),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await _authService.logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/login', 
                (route) => false,
              );
              _showSnackBar("Sesión cerrada correctamente");
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF7931E)))
          : _viajes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _viajes.length,
                  itemBuilder: (context, index) => _buildSolicitudItem(_viajes[index]),
                ),
    );
  }

  // --- WIDGETS DE LA LISTA (Igual que antes) ---

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
    final TextEditingController tarifaController = TextEditingController(text: viaje['costo_estimado'].toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5)),
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
                  backgroundImage: NetworkImage(formatImageUrl(viaje['pasajero_foto']) ?? 'https://via.placeholder.com/150'),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(viaje['pasajero_nombre'] ?? "Usuario", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text("${viaje['cantidad_pasajeros']} pas. | ${viaje['distancia_total_km']} km", style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            if (viaje['referencia'] != null && viaje['referencia'].toString().isNotEmpty)
              Text("📍 ${viaje['referencia']}", style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end, // Alinea la base del input con el botón
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100], // Fondo sutil para el campo
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: tarifaController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 20, // Aumentado para mejor legibilidad del conductor
                        color: Colors.black87
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        labelText: "Tu Oferta",
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        prefixText: "\$ ",
                        prefixStyle: TextStyle(
                          color: Color(0xFFF7931E), 
                          fontWeight: FontWeight.bold, 
                          fontSize: 20
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 56, // Altura estándar para botones táctiles cómodos
                    child: ElevatedButton(
                      onPressed: () => _enviarOferta(viaje['id'], tarifaController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF7931E),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFFF7931E).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "ENVIAR OFERTA",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 13, 
                          letterSpacing: 0.5,
                          height: 1.1 // Ajuste de línea para el texto doble
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _enviarOferta(int viajeId, String monto) async {
    if (monto.isEmpty || double.tryParse(monto) == null || double.parse(monto) <= 0) {
      _showSnackBar("Monto inválido", isError: true);
      return;
    }
    final exito = await _authService.enviarOferta(viajeId, monto);
    if (exito && mounted) Navigator.pushNamed(context, '/esperando_confirmacion');
  }

  void _iniciarRastreoUbicacion() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition();
    await _authService.actualizarUbicacion(position.latitude, position.longitude);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.orange),
    );
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _socketService.desconectar();
    super.dispose();
  }
}