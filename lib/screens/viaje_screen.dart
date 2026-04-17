import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../models/destino.dart';
import '../utils/ui_utils.dart';
import 'package:kooneex/screens/historial_viaje_screen.dart';
import 'package:kooneex/screens/ayuda_screen.dart';

class ViajeScreen extends StatefulWidget {
  const ViajeScreen({super.key});

  @override
  State<ViajeScreen> createState() => _ViajeScreenState();
}

class _ViajeScreenState extends State<ViajeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _authService = AuthService();

  // Estado de Ubicación
  bool _origenDetectado = false;
  double? _origenLat, _origenLon;

  // Estado de Destinos y Colonias
  List<Destino> _destinos = [];
  bool _cargandoDestinos = true;

  // Selección de Colonia (Recogida)
  String _coloniaTexto = "Selecciona tu barrio/colonia";
  Destino? _coloniaSeleccionada;

  // Selección de Destino (Hacia dónde va)
  String _destinoTexto = "Selecciona hacia dónde vas";
  Destino? _destinoSeleccionado;

  final _cantidadController = TextEditingController(text: "1");
  final _referenciaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _determinarPosicion();
    _cargarDestinos();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _referenciaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDestinos() async {
    try {
      final lista = await _authService.getDestinos();
      if (mounted) {
        setState(() {
          _destinos = lista;
          _cargandoDestinos = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoDestinos = false);
      UIUtils.showError(context, "Error al cargar destinos");
    }
  }

  Future<void> _determinarPosicion() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _origenLat = position.latitude;
        _origenLon = position.longitude;
        _origenDetectado = true;
      });
    }
  }

  void _solicitarViaje() async {
    if (!_origenDetectado ||
        _destinoSeleccionado == null ||
        _coloniaSeleccionada == null) {
      UIUtils.showSnackBar(context, "Completa los datos y espera al GPS",
          isError: true);
      return;
    }

    // CONCATENACIÓN: Colonia + Referencia manual
    final referenciaFinal =
        "Col: ${_coloniaSeleccionada!.nombre}. Ref: ${_referenciaController.text.trim()}";

    final datosViaje = {
      "origen_lat": double.parse(_origenLat!.toStringAsFixed(6)),
      "origen_lon": double.parse(_origenLon!.toStringAsFixed(6)),
      "destino_id": _destinoSeleccionado!.id,
      "cantidad_pasajeros": int.tryParse(_cantidadController.text) ?? 1,
      "referencia": referenciaFinal,
    };

    UIUtils.showLoading(context);
    final exito = await _authService.crearViaje(datosViaje);
    await _authService.actualizarUbicacion(
        double.parse(_origenLat!.toStringAsFixed(6)),
        double.parse(_origenLon!.toStringAsFixed(6)));

    if (mounted) {
      UIUtils.dismissLoading(context);
      if (exito) {
        Navigator.pushReplacementNamed(context, '/ofertas');
      } else {
        UIUtils.showError(context, "No se pudo crear el viaje");
      }
    }
  }

  // --- SELECTORES MODALES ---

  void _abrirSeleccionColonia() {
    _mostrarPicker(
      titulo: "Selecciona tu Colonia",
      onSelect: (destino) {
        setState(() {
          _coloniaSeleccionada = destino;
          _coloniaTexto = destino.nombre;
        });
      },
    );
  }

  void _abrirSeleccionDestino() {
    _mostrarPicker(
      titulo: "¿A dónde vas?",
      onSelect: (destino) {
        setState(() {
          _destinoSeleccionado = destino;
          _destinoTexto = destino.nombre;
        });
      },
    );
  }

  void _mostrarPicker(
      {required String titulo, required Function(Destino) onSelect}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) {
          if (_cargandoDestinos)
            return const Center(child: CircularProgressIndicator());
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _destinos.length,
                  itemBuilder: (context, index) {
                    final item = _destinos[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined,
                          color: Color(0xFFF7931E)),
                      title: Text(item.nombre),
                      onTap: () {
                        onSelect(item);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
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
        title: const Text("Nuevo Viaje",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status GPS
            _buildGPSStatus(),
            const SizedBox(height: 30),

            // Selector: Colonia de Origen
            _buildLabel("¿En qué colonia estás?"),
            _buildSelectorTile(
              texto: _coloniaTexto,
              icono: Icons.maps_home_work_outlined,
              estaSeleccionado: _coloniaSeleccionada != null,
              onTap: _abrirSeleccionColonia,
            ),
            const SizedBox(height: 25),

            // Selector: Destino
            _buildLabel("¿Hacia dónde vas?"),
            _buildSelectorTile(
              texto: _destinoTexto,
              icono: Icons.location_on_outlined,
              estaSeleccionado: _destinoSeleccionado != null,
              onTap: _abrirSeleccionDestino,
            ),
            const SizedBox(height: 30),

            // Detalles
            _buildLabel("Detalles del viaje"),
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
              label: "Referencia donde estas.",
              icon: Icons.notes,
              maxLines: 3,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
              child: Text(
                "Indica el color de tu casa, nombre de un negocio o punto exacto donde el mototaxista debe recogerte. Esto ayuda a evitar retrasos.",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Botón Principal
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _solicitarViaje,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("SOLICITAR MOTOTAXI",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE ESTILO ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSelectorTile(
      {required String texto,
      required IconData icono,
      required bool estaSeleccionado,
      required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Icon(icono, color: const Color(0xFFF7931E)),
        title: Text(texto,
            style: TextStyle(
                color: estaSeleccionado ? Colors.black : Colors.grey[600],
                fontSize: 14)),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: onTap,
      ),
    );
  }

  Widget _buildGPSStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _origenDetectado ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_origenDetectado ? Icons.gps_fixed : Icons.gps_not_fixed,
              size: 16, color: _origenDetectado ? Colors.green : Colors.orange),
          const SizedBox(width: 8),
          Text(_origenDetectado ? "GPS Listo" : "Localizando...",
              style: TextStyle(
                  color:
                      _origenDetectado ? Colors.green[700] : Colors.orange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCustomInput(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      TextInputType type = TextInputType.text,
      int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFF7931E)),
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF7931E))),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      // Bordes redondeados a la derecha para un look moderno
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // --- CABECERA PERSONALIZADA CON DEGRADADO ---
          Container(
            padding:
                const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7931E), Color(0xFFFFB35C)],
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
                  "Usuario Kooneex",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Cliente verificado",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
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
                                  const HistorialScreen(esMototaxista: false)));
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
              tileColor: Colors.red.withOpacity(0.05),
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
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // Widget auxiliar para mantener el estilo consistente
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
