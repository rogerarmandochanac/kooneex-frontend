import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';

class ViajeScreen extends StatefulWidget {
  const ViajeScreen({super.key});

  @override
  State<ViajeScreen> createState() => _ViajeScreenState();
}

class _ViajeScreenState extends State<ViajeScreen> {
  final _authService = AuthService();
  
  bool _origenDetectado = false;
  double? _origenLat, _origenLon;
  double? _destinoLat, _destinoLon;
  String _destinoNombre = "Selecciona hacia dónde vas";
  
  final _cantidadController = TextEditingController(text: "1");
  final _referenciaController = TextEditingController();

  final Map<String, List<double>> _destinosPredefinidos = {
    "Plaza Principal": [18.1234, -92.5678],
    "Hospital General": [18.1250, -92.5700],
    "Terminal de Autobuses": [18.1210, -92.5600],
  };

  @override
  void initState() {
    super.initState();
    _determinarPosicion();
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
    if (!_origenDetectado || _destinoLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Falta ubicación u origen")),
      );
      return;
    }

    final datos = {
      "origen_lat": _origenLat,
      "origen_lon": _origenLon,
      "destino_lat": _destinoLat,
      "destino_lon": _destinoLon,
      "cantidad_pasajeros": int.parse(_cantidadController.text),
      "referencia": _referenciaController.text,
    };

    // Aquí llamarías a tu servicio (lo crearemos a continuación)
    final exito = await _authService.crearViaje(datos);

    if (exito) {
      // Si el viaje se crea, vas a la pantalla de tarifas (como en tu Kivy)
      Navigator.pushReplacementNamed(context, '/ofertas');
    }
  }

  void _abrirSeleccionDestino() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text("Destinos Frecuentes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._destinosPredefinidos.keys.map((nombre) {
                return ListTile(
                  leading: const Icon(Icons.location_on, color: Color(0xFFF7931E)),
                  title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w500)),
                  onTap: () {
                    setState(() {
                      _destinoNombre = nombre;
                      _destinoLat = _destinosPredefinidos[nombre]![0];
                      _destinoLon = _destinosPredefinidos[nombre]![1];
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text("Nuevo Viaje", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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

            // Tarjeta de Ruta (Origen y Destino)
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

            // Input de Pasajeros
            _buildCustomInput(
              controller: _cantidadController,
              label: "Número de pasajeros",
              icon: Icons.people_outline,
              type: TextInputType.number,
            ),
            const SizedBox(height: 20),

            // Input de Referencia
            _buildCustomInput(
              controller: _referenciaController,
              label: "Referencia (Ej: Casa portón azul)",
              icon: Icons.notes,
              maxLines: 2,
            ),
            
            const SizedBox(height: 40),

            // Botón Principal Estilo Pro
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
}