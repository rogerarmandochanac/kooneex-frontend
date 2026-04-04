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

import '../services/location_service.dart';
import '../services/offline_service.dart';

class ViajeEnCursoScreen extends StatefulWidget {
  const ViajeEnCursoScreen({super.key});

  @override
  State<ViajeEnCursoScreen> createState() => _ViajeEnCursoScreenState();
}

class _ViajeEnCursoScreenState extends State<ViajeEnCursoScreen> {
  final String _baseUrl = "http://192.168.1.105:8000/api";
  final MapController _mapController = MapController();
  
  Map<String, dynamic>? _viaje;
  bool _estaCargando = true;
  bool _estaOnline = true; 
  List<latLng.LatLng> _puntosRuta = [];
  bool _referenciaExpandida = false;
  bool _mapaListo = false;
  double? _ultimaLatDestino;
  
  Timer? _timerRefresco;
  StreamSubscription? _internetSubscription;

  @override
  void initState() {
    super.initState();
    
    // 1. Iniciar servicios de rastreo y monitoreo de red
    _monitorearInternet();
    LocationService().iniciarRastreo();
    
    // 2. Carga inicial de datos
    _cargarViajeActual(esPrimeraVez: true);

    // 3. Timer de refresco (solo actúa si hay internet)
    _timerRefresco = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_estaOnline) {
        _cargarViajeActual(esPrimeraVez: false);
      }
    });
  }

  void _monitorearInternet() {
    _internetSubscription = Connectivity().onConnectivityChanged.listen((result) {
      final bool conectado = result != ConnectivityResult.none;
      if (conectado && !_estaOnline) {
        // Si recuperamos internet, intentamos subir lo guardado en SQLite
        OfflineService().subirPendientes();
      }
      setState(() => _estaOnline = conectado);
    });
  }

  @override
  void dispose() {
    _timerRefresco?.cancel();
    _internetSubscription?.cancel();
    super.dispose();
  }

  Future<void> _cargarViajeActual({bool esPrimeraVez = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('$_baseUrl/viajes/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        List viajes = jsonDecode(response.body);
        final viajeActivo = viajes.firstWhere(
          (v) => v["estado"] == "en_curso",
          orElse: () => null,
        );

        if (viajeActivo != null) {
          double cLat = double.tryParse(viajeActivo['conductor_lat']?.toString() ?? "") ?? 0.0;
          double cLon = double.tryParse(viajeActivo['conductor_lon']?.toString() ?? "") ?? 0.0;
          double pLat = double.tryParse(viajeActivo['pasajero_lat']?.toString() ?? "") ?? 0.0;
          double pLon = double.tryParse(viajeActivo['pasajero_lon']?.toString() ?? "") ?? 0.0;
            setState(() {
              _viaje = viajeActivo;
              if (esPrimeraVez) _estaCargando = false;
              _obtenerRutaOSRM(cLat, cLon);
            });
          
          if (cLat != 0.0 && _mapaListo) {
            _mapController.move(latLng.LatLng(cLat, cLon), _mapController.camera.zoom);
            _obtenerRutaOSRM(cLat, cLon);
          }
        }
      }
    } catch (e) {
      debugPrint("Error de conexión: $e");
    } finally {
      if (esPrimeraVez) setState(() => _estaCargando = false);
    }
  }

  Future<void> _obtenerRutaOSRM(double cLat, double cLon) async {
    
    if (!_estaOnline && _viaje == null) return; // No gastar recursos si no hay red
    
    double pLat = double.tryParse(_viaje!['pasajero_lat']?.toString() ?? "") ?? 0.0;
    double pLon = double.tryParse(_viaje!['pasajero_lon']?.toString() ?? "") ?? 0.0;

    if (_ultimaLatDestino == pLat && _puntosRuta.length > 2) return;

    if (pLat == 0.0) return;

    final url = "https://router.project-osrm.org/route/v1/driving/$cLon,$cLat;$pLon,$pLat?overview=simplified&geometries=geojson&steps=false";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          _puntosRuta = coords.map((c) => latLng.LatLng(c[1].toDouble(), c[0].toDouble())).toList();
        });
        print("🚀 RUTA TRAZADA: ${_puntosRuta.length} puntos encontrados");
      }
      else{
        print("❌ Error de OSRM: ${response.body}");
      }
    } catch (e) {
      print("❌ Error de red en OSRM: $e");
      debugPrint("Error ruta: $e");
    }
  }

  // --- MÉTODOS DE CONTACTO ---
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
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _marcarCompletado() async {
    if (_viaje == null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    final response = await http.patch(
      Uri.parse('$_baseUrl/viajes/${_viaje!['id']}/completar/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) Navigator.pushReplacementNamed(context, '/solicitudes');
  }

  @override
  Widget build(BuildContext context) {
    if (_estaCargando) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    double cLat = double.tryParse(_viaje!['conductor_lat']?.toString() ?? "20.1373") ?? 20.1373;
    double cLon = double.tryParse(_viaje!['conductor_lon']?.toString() ?? "-90.1749") ?? -90.1749;
    double pLat = double.tryParse(_viaje!['pasajero_lat']?.toString() ?? "20.1373") ?? 20.1373;
    double pLon = double.tryParse(_viaje!['pasajero_lon']?.toString() ?? "-90.1749") ?? -90.1749;

    return Scaffold(
      body: Stack(
        children: [
          // MAPA CON CACHÉ
          FlutterMap(
            
            mapController: _mapController,
            options: MapOptions(
              initialCenter: latLng.LatLng(cLat, cLon),
              initialZoom: 17,
              onMapReady: () {
                setState(() => _mapaListo = true);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kooneex.app',
                tileProvider: const FMTCStore('mapStore').getTileProvider(),
              ),
              if(_puntosRuta.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(points: _puntosRuta, strokeWidth: 5, color: Colors.blueAccent),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: latLng.LatLng(cLat, cLon),
                    child: const Icon(Icons.motorcycle, color: Color(0xFFF7931E), size: 35),
                  ),
                  Marker(
                    point: latLng.LatLng(pLat, pLon),
                    child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),

          // AVISO SIN CONEXIÓN
          if (!_estaOnline)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white),
                    SizedBox(width: 10),
                    Text("Modo Offline - Guardando en KINGKONG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // PANEL INFO
          SafeArea(
            child: Column(
              children: [
                _buildCardInfo(),
                const Spacer(),
                _buildBottomActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS DE UI ---

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
                leading: const CircleAvatar(backgroundColor: Color(0xFFF7931E), child: Icon(Icons.person, color: Colors.white)),
                title: Text(_viaje?['pasajero_nombre'] ?? "Pasajero", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Destino: ${_viaje?['destino']?['nombre'] ?? 'No especificado'}"),
                trailing: Text("\$${_viaje?['costo_final'] ?? '0'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(Icons.group, "${_viaje?['cantidad_pasajeros'] ?? '1'}"),
                  _buildInfoItem(Icons.straighten, "${_viaje?['distancia_total_km'] ?? '0'} km"),
                  _buildInfoItem(Icons.phone_android, "${_viaje?['pasajero_telefono'] ?? 'S/N'}"),
                ],
              ),
              _buildReferenciaSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferenciaSection() {
    if (_viaje?['referencia'] == null || _viaje!['referencia'].toString().isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: () => setState(() => _referenciaExpandida = !_referenciaExpandida),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  const Text("Referencia", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(_referenciaExpandida ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              Text(
                "${_viaje?['referencia']}",
                maxLines: _referenciaExpandida ? null : 2,
                overflow: _referenciaExpandida ? TextOverflow.visible : TextOverflow.ellipsis,
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
            onPressed: _marcarCompletado,
            child: const Icon(Icons.check, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return FloatingActionButton(mini: true, backgroundColor: color, onPressed: onTap, child: Icon(icon, color: Colors.white));
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Column(children: [Icon(icon, size: 20, color: Colors.grey), Text(text, style: const TextStyle(fontSize: 12))]);
  }

  void _confirmarFinalizarViaje() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("¿Finalizar viaje?"),
        content: const Text("Asegúrate de haber llegado al destino antes de terminar el servicio."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Cierra el diálogo sin hacer nada
            child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context); // Cierra el diálogo
              _marcarCompletado(); // Ejecuta tu función de patch a Django
            },
            child: const Text("FINALIZAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}

}