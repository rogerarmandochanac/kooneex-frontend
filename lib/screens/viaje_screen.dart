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
  
  // Variables de estado (equivalentes a tus StringProperty/BooleanProperty)
  bool _origenDetectado = false;
  double? _origenLat, _origenLon;
  double? _destinoLat, _destinoLon;
  String _destinoNombre = "Selecciona el destino";
  
  final _cantidadController = TextEditingController(text: "1");
  final _referenciaController = TextEditingController();

  // Lista de destinos (Basada en tu config.py de Kivy)
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // Obtener posición actual
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _origenLat = position.latitude;
      _origenLon = position.longitude;
      _origenDetectado = true;
    });
    print("📍 Origen detectado: $_origenLat, $_origenLon");
  }

  void _abrirSeleccionDestino() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: _destinosPredefinidos.keys.map((nombre) {
            return ListTile(
              title: Text(nombre),
              onTap: () {
                setState(() {
                  _destinoNombre = nombre;
                  _destinoLat = _destinosPredefinidos[nombre]![0];
                  _destinoLon = _destinosPredefinidos[nombre]![1];
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
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
      Navigator.pushReplacementNamed(context, '/tarifas');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Solicitar Viaje"),
        backgroundColor: const Color(0xFFF7931E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Indicador de GPS (Equivalente al BoxLayout con MDIcon en viaje.kv)
            Row(
              children: [
                Icon(
                  _origenDetectado ? Icons.check_circle : Icons.watch_later,
                  color: _origenDetectado ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 10),
                Text(_origenDetectado ? "Ubicación detectada" : "Buscando GPS..."),
              ],
            ),
            const SizedBox(height: 20),
            
            // Selector de Destino
            ListTile(
              title: const Text("Destino"),
              subtitle: Text(_destinoNombre),
              trailing: const Icon(Icons.map),
              tileColor: Colors.orange.withOpacity(0.1),
              onTap: _abrirSeleccionDestino,
            ),

            TextField(
              controller: _cantidadController,
              decoration: const InputDecoration(labelText: "No. Pasajeros"),
              keyboardType: TextInputType.number,
            ),

            TextField(
              controller: _referenciaController,
              decoration: const InputDecoration(labelText: "Referencia"),
              maxLines: 2,
            ),

            const Spacer(),
            
            FloatingActionButton(
              backgroundColor: Colors.green,
              onPressed: _solicitarViaje,
              child: const Icon(Icons.check, color: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}