import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kooneex/screens/ayuda_screen.dart';
import '../services/auth_service.dart';
import '../services/mototaxi_socket_service.dart';
import 'package:geolocator/geolocator.dart';
import '../services/push_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/ui_utils.dart';
import 'historial_viaje_screen.dart';

class SolicitudesScreen extends StatefulWidget {
  const SolicitudesScreen({super.key});

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final _socketService = MototaxiSocketService();
  final _authService = AuthService();

  List<dynamic> _viajes = [];
  bool _estaCargando = true;
  StreamSubscription? _socketSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addObserver(this); // Para detectar cuando vuelve a la app
    _iniciarRastreoUbicacion();
    _configurarEscuchaSocket();
    _cargarViajes();
    _initPushNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _socketSubscription?.cancel();
    super.dispose();
  }

  // Si el conductor sale de la app y vuelve, refrescamos automáticamente
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarViajes();
      _socketService.conectar();
    }
  }

  void _iniciarRastreoUbicacion() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    Position position = await Geolocator.getCurrentPosition();
    await _authService.actualizarUbicacion(
        position.latitude, position.longitude);
  }

  void _configurarEscuchaSocket() {
    _socketService.conectar();
    _socketSubscription = _socketService.stream.listen((mensaje) {
      try {
        final data = jsonDecode(mensaje);
        if (data['type'] == 'nuevo_viaje' || data['type'] == 'cancelar_viaje') {
          _cargarViajes();
        }
      } catch (e) {
        debugPrint("Error socket: $e");
      }
    });
  }

  void _initPushNotifications() async {
    await PushNotificationService.initializeApp();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['type'] == 'nueva_solicitud') {
        _cargarViajes();
        if (!mounted) return;
        UIUtils.showSnackBar(context, "${message.notification?.body}");
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

  void _enviarOferta(int viajeId, String monto) async {
    if (monto.isEmpty ||
        double.tryParse(monto) == null ||
        double.parse(monto) <= 0) {
      UIUtils.showError(context, "Monto inválido");
      return;
    }

    UIUtils.showLoading(context);
    try {
      final exito = await _authService.enviarOferta(viajeId, monto);
      if (!mounted) return;
      UIUtils.dismissLoading(context);

      if (exito) {
        Navigator.pushReplacementNamed(context, '/esperando_confirmacion');
      } else {
        UIUtils.showError(context, "No se pudo enviar la oferta");
        _cargarViajes();
      }
    } catch (e) {
      if (mounted) {
        UIUtils.dismissLoading(context);
        UIUtils.showError(context, "Error de conexión");
      }
    }
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: const CircleAvatar(
              backgroundColor: Color(0xFFF7931E),
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ),
        ),
        title: const Text("Viajes Solicitados",
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFF7931E)),
            onPressed: _cargarViajes,
          )
        ],
      ),
      body: _estaCargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF7931E)))
          : _viajes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _viajes.length,
                  itemBuilder: (context, index) => SolicitudItem(
                      viaje: _viajes[index], onEnviar: _enviarOferta),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.moped_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 20),
          const Text("Sin viajes cerca",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54)),
          const Text("Te avisaremos cuando alguien pida un viaje",
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      // Añadimos bordes redondeados a la derecha del Drawer para un look moderno
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // --- CABECERA PERSONALIZADA ---
          Container(
            padding:
                const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFF7931E),
                  Color(0xFFFFB35C)
                ], // Degradado de tu naranja
              ),
              borderRadius: BorderRadius.only(topRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFFF7931E), size: 40),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Conductor Kooneex",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "ID: #MOT-042", // Un detalle "pro" simulando un ID de empleado
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // --- OPCIONES DEL MENÚ ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.edit_note_rounded,
                    title: "Editar mi Perfil",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/editar-perfil');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.lock_outline,
                    title: "Cambiar Contraseña",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/cambiar-password');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: "Mis Viajes",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const HistorialScreen(esMototaxista: true)));
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline,
                    title: "Centro de Ayuda",
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AyudaScreen()));
                    },
                  ),
                ],
              ),
            ),
          ),

          // --- BOTÓN DE CIERRE DE SESIÓN ---
          const Divider(indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
            child: ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              leading:
                  const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text(
                "Cerrar Sesión",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
              tileColor: Colors.red.withOpacity(0.05), // Fondo sutil rojo
              onTap: () async {
                UIUtils.showLoading(context);
                await _authService.logout();
                if (!mounted) return;
                UIUtils.dismissLoading(context);
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
            ),
          ),
        ],
      ),
    );
  }

// Helper para crear los items del drawer con diseño consistente
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// --- CLASE PARA EL ITEM DE LA LISTA (Mantiene tu estilo original) ---
class SolicitudItem extends StatefulWidget {
  final dynamic viaje;
  final Function(int, String) onEnviar;

  const SolicitudItem({super.key, required this.viaje, required this.onEnviar});

  @override
  State<SolicitudItem> createState() => _SolicitudItemState();
}

class _SolicitudItemState extends State<SolicitudItem> {
  late TextEditingController _tarifaController;

  @override
  void initState() {
    super.initState();
    _tarifaController =
        TextEditingController(text: widget.viaje['costo_estimado'].toString());
  }

  @override
  void dispose() {
    _tarifaController.dispose();
    super.dispose();
  }

  String formatImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.contains(':8000') ? url.replaceFirst(':8000', '') : url;
  }

  @override
  Widget build(BuildContext context) {
    final viaje = widget.viaje;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 15,
              offset: const Offset(0, 5)),
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
                  backgroundImage: NetworkImage(viaje['pasajero_foto'] ??
                      'https://via.placeholder.com/150'),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(viaje['pasajero_nombre'] ?? "Usuario",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text(
                          "Pasajeros: ${viaje['cantidad_pasajeros']} | Distancia: ${viaje['distancia_total_km']} km",
                          style: TextStyle(color: Colors.grey[600])),
                      Text("Destino: ${viaje['destino']['nombre']}",
                          style: TextStyle(color: Colors.grey[600]))
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            if (viaje['referencia'] != null &&
                viaje['referencia'].toString().isNotEmpty)
              Text("📍 Recoger en: ${viaje['referencia']}",
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _tarifaController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black87),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        labelText: "Tu Oferta",
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        prefixText: "\$ ",
                        prefixStyle: TextStyle(
                            color: Color(0xFFF7931E),
                            fontWeight: FontWeight.bold,
                            fontSize: 20),
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () =>
                          widget.onEnviar(viaje['id'], _tarifaController.text),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF7931E),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor:
                            const Color(0xFFF7931E).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "ENVIAR OFERTA",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                            height: 1.1),
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
}
