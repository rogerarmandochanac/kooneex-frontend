import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/offline_service.dart';

class ViajeEnCursoScreen extends StatefulWidget {
  const ViajeEnCursoScreen({super.key});

  @override
  State<ViajeEnCursoScreen> createState() => _ViajeEnCursoScreenState();
}

class _ViajeEnCursoScreenState extends State<ViajeEnCursoScreen> {
  // --- ESTADO Y SUBSCRIPCIONES ---
  StreamSubscription<Position>? _posicionSub;
  StreamSubscription? _internetSubscription;
  Timer? _timerRefresco;

  final MapController _mapController = MapController();
  final String _baseUrl = "http://3.21.34.42:8000/api";

  Map<String, dynamic>? _viaje;
  List<latLng.LatLng> _puntosRuta = [];

  bool _estaCargando = true;
  bool _estaOnline = true;
  bool _seguirConductor = true;
  bool _referenciaExpandida = false;
  bool _mapaListo = false;

  double _bearing = 0.0;
  latLng.LatLng? _posicionActualConductor;
  double? _ultimaLatDestino;

  @override
  void initState() {
    super.initState();
    _monitorearInternet();
    LocationService().iniciarRastreo();
    _cargarViajeActual(esPrimeraVez: true);

    // Refresco de datos del servidor cada 15 segundos
    _timerRefresco = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_estaOnline) _cargarViajeActual(esPrimeraVez: false);
    });

    // ESCUCHA GPS: Actualiza posición, rotación y recorta la ruta
    _posicionSub = LocationService().posicionStream.listen((Position pos) {
      final nuevaPos = latLng.LatLng(pos.latitude, pos.longitude);

      setState(() {
        _posicionActualConductor = nuevaPos;
        _bearing = pos.heading;

        if (_puntosRuta.isNotEmpty) {
          _optimizarTrazoRuta(nuevaPos);
        }
      });

      if (_mapaListo && _seguirConductor) {
        _mapController.move(nuevaPos, _mapController.camera.zoom);
      }
    });
  }

  // --- LÓGICA DE NEGOCIO ---

  void _monitorearInternet() {
    _internetSubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      final bool conectado = result != ConnectivityResult.none;
      if (conectado && !_estaOnline) OfflineService().subirPendientes();
      setState(() => _estaOnline = conectado);
    });
  }

  void _optimizarTrazoRuta(latLng.LatLng posicionActual) {
    const double umbralMetros = 20.0;
    final distance = const latLng.Distance();
    int puntosAEliminar = 0;

    for (int i = 0; i < _puntosRuta.length; i++) {
      double d =
          distance.as(latLng.LengthUnit.Meter, posicionActual, _puntosRuta[i]);
      if (d < umbralMetros) {
        puntosAEliminar = i + 1;
      } else {
        break;
      }
    }

    if (puntosAEliminar > 0) {
      setState(() {
        _puntosRuta.removeRange(0, puntosAEliminar);
        _puntosRuta.insert(0, posicionActual);
      });
    }
  }

  // 1. Modificamos la carga para que dispare el dibujo de la ruta
  Future<void> _cargarViajeActual({bool esPrimeraVez = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('$_baseUrl/viajes/'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        List viajes = jsonDecode(response.body);
        final viajeActivo = viajes.firstWhere((v) => v["estado"] == "en_curso",
            orElse: () => null);

        if (viajeActivo != null) {
          setState(() {
            _viaje = viajeActivo;

            // Sacamos las coordenadas del JSON del backend
            double cLat = double.tryParse(
                    viajeActivo['conductor_lat']?.toString() ?? "") ??
                0.0;
            double cLon = double.tryParse(
                    viajeActivo['conductor_lon']?.toString() ?? "") ??
                0.0;

            // Si es la primera vez o la ruta está vacía, la pedimos a OSRM
            if (esPrimeraVez || _puntosRuta.isEmpty) {
              _obtenerRutaOSRM(cLat, cLon);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error cargando viaje: $e");
    } finally {
      if (esPrimeraVez) setState(() => _estaCargando = false);
    }
  }

  // 2. Aseguramos que OSRM devuelva los puntos correctamente
  Future<void> _obtenerRutaOSRM(double cLat, double cLon) async {
    if (!_estaOnline || _viaje == null) return;

    double pLat =
        double.tryParse(_viaje!['origen_lan']?.toString() ?? "") ?? 0.0;
    double pLon =
        double.tryParse(_viaje!['origen_lon']?.toString() ?? "") ?? 0.0;

    // PASO A: Dibujar línea recta temporal para feedback instantáneo
    if (_puntosRuta.isEmpty) {
      setState(() {
        _puntosRuta = [
          latLng.LatLng(cLat, cLon),
          latLng.LatLng(pLat, pLon),
        ];
      });
    }

    // PASO B: Pedir la ruta real por calles
    // Usamos 'overview=full' para curvas suaves, pero 'steps=false' para que sea más ligera
    final url =
        "https://router.project-osrm.org/route/v1/driving/$cLon,$cLat;$pLon,$pLat?overview=full&geometries=geojson&steps=false";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];

        if (mounted) {
          setState(() {
            // Reemplazamos la línea recta por la ruta real detallada
            _puntosRuta = coords
                .map((c) => latLng.LatLng(c[1].toDouble(), c[0].toDouble()))
                .toList();
            _ultimaLatDestino = pLat;
          });
        }
      }
    } catch (e) {
      debugPrint("Error OSRM: $e");
    }
  }

  // --- ACCIONES DE INTERFAZ ---

  void _llamarPasajero() async {
    final tel = _viaje?['pasajero_telefono'];
    if (tel == null) return;
    final url = Uri.parse("tel:$tel");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _enviarWhatsApp() async {
    final tel = _viaje?['pasajero_telefono'];
    if (tel == null) return;
    String numero = tel.replaceAll(RegExp(r'[^0-9]'), '');
    final url = Uri.parse("https://wa.me/$numero?text=Hola, estoy en camino.");
    if (await canLaunchUrl(url))
      await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _marcarCompletado() async {
    if (_viaje == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.patch(
      Uri.parse('$_baseUrl/viajes/${_viaje!['id']}/completar/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200)
      Navigator.pushReplacementNamed(context, '/solicitudes');
  }

  // --- CONSTRUCCIÓN DE UI ---

  @override
  Widget build(BuildContext context) {
    if (_estaCargando)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    double cLat =
        double.tryParse(_viaje!['conductor_lat']?.toString() ?? "0") ?? 0;
    double cLon =
        double.tryParse(_viaje!['conductor_lon']?.toString() ?? "0") ?? 0;
    double pLat =
        double.tryParse(_viaje!['origen_lan']?.toString() ?? "0") ?? 0;
    double pLon =
        double.tryParse(_viaje!['origen_lon']?.toString() ?? "0") ?? 0;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: latLng.LatLng(cLat, cLon),
              initialZoom: 17,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() => _seguirConductor = false);
              },
              onMapReady: () => setState(() => _mapaListo = true),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kooneex.app',
                tileProvider: const FMTCStore('mapStore').getTileProvider(),
              ),
              if (_puntosRuta.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                        points: _puntosRuta,
                        strokeWidth: 5,
                        color: const Color(0xFFF7931E)),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point:
                        _posicionActualConductor ?? latLng.LatLng(cLat, cLon),
                    width: 60,
                    height: 60,
                    child: Transform.rotate(
                      angle: _bearing * (3.14159 / 180),
                      child: const Icon(Icons.motorcycle,
                          color: Color(0xFFF7931E), size: 40),
                    ),
                  ),
                  Marker(
                    point: latLng.LatLng(pLat, pLon),
                    child: const Icon(Icons.person_pin_circle,
                        color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          if (!_estaOnline) _buildOfflineWarning(),
          SafeArea(
            child: Column(
              children: [
                _buildCardInfo(),
                const Spacer(),
                if (!_seguirConductor) _buildRecenterBtn(),
                _buildBottomActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTES DE UI REUTILIZADOS ---

  Widget _buildOfflineWarning() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 10),
            Text("Modo Offline",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecenterBtn() {
    return Padding(
      padding: const EdgeInsets.only(right: 20, bottom: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.white,
          onPressed: () => setState(() => _seguirConductor = true),
          child: const Icon(Icons.my_location, color: Color(0xFFF7931E)),
        ),
      ),
    );
  }

  Widget _buildCardInfo() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF7931E),
                    child: Icon(Icons.person, color: Colors.white)),
                title: Text(_viaje?['pasajero_nombre'] ?? "Pasajero",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "Destino: ${_viaje?['destino']?['nombre'] ?? 'No especificado'}"),
                trailing: Text("\$${_viaje?['costo_final'] ?? '0'}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green)),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                      Icons.group, "${_viaje?['cantidad_pasajeros'] ?? '1'}"),
                  _buildInfoItem(Icons.straighten,
                      "${_viaje?['distancia_total_km'] ?? '0'} km"),
                  _buildInfoItem(Icons.phone_android,
                      "${_viaje?['pasajero_telefono'] ?? 'S/N'}"),
                ],
              ),
              if (_viaje?['referencia'] != null &&
                  _viaje!['referencia'].toString().isNotEmpty)
                _buildReferenciaSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferenciaSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () =>
            setState(() => _referenciaExpandida = !_referenciaExpandida),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  const Text("Recoger en:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(_referenciaExpandida
                      ? Icons.expand_less
                      : Icons.expand_more),
                ],
              ),
              Text(
                "${_viaje?['referencia']}",
                maxLines: _referenciaExpandida ? null : 2,
                overflow: _referenciaExpandida
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              _buildActionBtn(Icons.phone, Colors.green, _llamarPasajero),
              const SizedBox(height: 10),
              _buildActionBtn(Icons.message, Colors.blue, _enviarWhatsApp),
            ],
          ),
          FloatingActionButton.large(
            backgroundColor: Colors.green,
            onPressed: _confirmarFinalizarViaje,
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return FloatingActionButton(
        mini: true,
        backgroundColor: color,
        onPressed: onTap,
        child: Icon(icon, color: Colors.white));
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Column(children: [
      Icon(icon, size: 20, color: Colors.grey),
      Text(text, style: const TextStyle(fontSize: 12))
    ]);
  }

  void _confirmarFinalizarViaje() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Finalizar viaje?"),
        content: const Text("Confirma si has llegado al destino."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCELAR")),
          ElevatedButton(
              onPressed: _marcarCompletado, child: const Text("FINALIZAR")),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _posicionSub?.cancel();
    _timerRefresco?.cancel();
    _internetSubscription?.cancel();
    super.dispose();
  }
}
