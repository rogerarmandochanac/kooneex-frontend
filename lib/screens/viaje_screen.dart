import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../models/destino.dart';

class ViajeScreen extends StatefulWidget {
  const ViajeScreen({super.key});

  @override
  State<ViajeScreen> createState() => _ViajeScreenState();
}

class _ViajeScreenState extends State<ViajeScreen> {
  // CLAVE PARA CONTROLAR EL DRAWER
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final _authService = AuthService();
  
  bool _origenDetectado = false;
  double? _origenLat, _origenLon;
  double? _destinoLat, _destinoLon;
  String _destinoNombre = "Selecciona hacia dónde vas";
  List<Destino> _destinos = []; 
  Destino? _destinoSeleccionado;
  bool _cargandoDestinos = true;
  
  final _cantidadController = TextEditingController(text: "1");
  final _referenciaController = TextEditingController();

  // (Se mantienen tus destinos predefinidos y lógica existente...)
  @override
  void initState() {
    super.initState();
    _determinarPosicion();
    _cargarDestinos();
  }

  // --- MÉTODOS DE LÓGICA (Sin cambios) ---

  Future<void> _cargarDestinos() async {
    try {
      final lista = await _authService.getDestinos();
      setState(() {
        _destinos = lista;
        _cargandoDestinos = false;
      });
    } catch (e) {
      setState(() => _cargandoDestinos = false);
      _showSnackBar("Error al cargar destinos", isError: true);
    }
  }

  Future<void> _determinarPosicion() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _origenLat = position.latitude;
      _origenLon = position.longitude;
      _origenDetectado = true;
    });
  }

  void _solicitarViaje() async {
    if (!_origenDetectado || _destinoSeleccionado == null) {
      _showSnackBar("Selecciona un destino y espera al GPS", isError: true);
      return;
    }
    final datosViaje = {
      "origen_lat": double.parse(_origenLat!.toStringAsFixed(6)),
      "origen_lon": double.parse(_origenLon!.toStringAsFixed(6)),
      "destino_id": _destinoSeleccionado!.id,
      "cantidad_pasajeros": int.tryParse(_cantidadController.text) ?? 1,
      "referencia": _referenciaController.text.trim(),
    };
    _showLoading();
    final exito = await _authService.crearViaje(datosViaje);
    if (mounted) Navigator.pop(context);
    if (exito) {
      Navigator.pushReplacementNamed(context, '/ofertas');
    } else {
      _showSnackBar("No se pudo crear el viaje", isError: true);
    }
  }

  void _abrirSeleccionDestino() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) {
          if (_cargandoDestinos) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            controller: scrollController,
            itemCount: _destinos.length,
            itemBuilder: (context, index) {
              final destino = _destinos[index];
              return ListTile(
                leading: const Icon(Icons.location_on, color: Color(0xFFF7931E)),
                title: Text(destino.nombre),
                onTap: () {
                  setState(() {
                    _destinoSeleccionado = destino;
                    _destinoNombre = destino.nombre;
                    _destinoLat = destino.latitud;
                    _destinoLon = destino.longitud;
                  });
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/cambiar-password');
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- INTERFAZ ESTILO X ---

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.80, // 80% de la pantalla
      child: Column(
        children: [
          // Cabecera estilo perfil
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Color(0xFFF7931E),
              child: Icon(Icons.person, color: Colors.white, size: 40),
            ),
            accountName: const Text("Usuario Kooneex", 
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            accountEmail: const Text("Ver perfil", 
              style: TextStyle(color: Colors.grey)),
          ),
          // Opciones
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Colors.black87),
            title: const Text("Cambiar Contraseña"),
            onTap: () {
              Navigator.pop(context); // Cerrar drawer
              // Navegar a tu screen de cambio de contraseña
              Navigator.pushNamed(context, '/cambiar-password'); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.black87),
            title: const Text("Mis Viajes"),
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.red)),
            onTap:  () async {
              await _authService.logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/login', 
                (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sesión cerrada correctamente")),
              );
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
      key: _scaffoldKey, // ASIGNAR LLAVE
      drawer: _buildDrawer(), // ASIGNAR DRAWER
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(), // ABRIR MENÚ
            child: const CircleAvatar(
              backgroundColor: Color(0xFFF7931E),
              child: Icon(Icons.person, size: 20, color: Colors.white),
            ),
          ),
        ),
        title: const Text("Nuevo Viaje", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status del GPS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _origenDetectado ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _origenDetectado ? Icons.gps_fixed : Icons.gps_not_fixed,
                    size: 16,
                    color: _origenDetectado ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _origenDetectado ? "GPS Listo" : "Localizando...",
                    style: TextStyle(
                      color: _origenDetectado ? Colors.green[700] : Colors.orange[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Tarjeta de Ruta
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _buildLocationRow(Icons.radio_button_checked, Colors.blue, "Mi ubicación actual", subtitle: "Origen detectado"),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Align(alignment: Alignment.centerLeft, child: Container(width: 2, height: 20, color: Colors.grey[200])),
                  ),
                  _buildLocationRow(
                    Icons.location_on, 
                    Colors.red, 
                    _destinoNombre, 
                    isAction: true,
                    onTap: _abrirSeleccionDestino,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            const Text("Detalles del viaje", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _buildCustomInput(
              controller: _cantidadController,
              label: "Número de pasajeros",
              icon: Icons.people_outline,
              type: TextInputType.number,
            ),
            const SizedBox(height: 20),

            _buildCustomInput(
              controller: _referenciaController,
              label: "Referencia donde sera \nrecogido(Ej: Casa portón azul)",
              icon: Icons.notes,
              maxLines: 4,
            ),
            
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _solicitarViaje,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("SOLICITAR MOTOTAXI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES (Sin cambios) ---

  Widget _buildLocationRow(IconData icon, Color color, String title, {String? subtitle, bool isAction = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: isAction ? FontWeight.bold : FontWeight.w500, color: isAction && _destinoLat == null ? Colors.grey : Colors.black)),
                if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          if (isAction) const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildCustomInput({required TextEditingController controller, required String label, required IconData icon, TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFF7931E)),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF7931E))),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF7931E)),
      ),
    );
  }
}