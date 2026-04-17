import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kooneex/services/api_config.dart';
import 'package:kooneex/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/viaje_socket_service.dart';
import '../utils/ui_utils.dart';
import './calificacion_screen.dart';

class ViajeEnCursoPasajeroScreen extends StatefulWidget {
  const ViajeEnCursoPasajeroScreen({super.key});

  @override
  State<ViajeEnCursoPasajeroScreen> createState() =>
      _ViajeEnCursoPasajeroScreenState();
}

class _ViajeEnCursoPasajeroScreenState
    extends State<ViajeEnCursoPasajeroScreen> {
  final String _baseUrl = "http://${ApiConfig.currentIp}/api";
  final MapController _mapController = MapController();
  final _viajeSocket = ViajeSocketService();

  Map<String, dynamic>? _viaje;
  bool _estaCargando = true;
  bool _estaOnline = true;
  List<latLng.LatLng> _puntosRuta = [];
  bool _mapaListo = false;

  Timer? _timerRefresco;
  StreamSubscription? _internetSubscription;

  @override
  void initState() {
    super.initState();
    _monitorearInternet();
    _cargarViajeActual(esPrimeraVez: true);
    _configurarSockets();

    _timerRefresco = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_estaOnline) _cargarViajeActual(esPrimeraVez: false);
    });
  }

  void _configurarSockets() async {
    final prefs = await SharedPreferences.getInstance();
    final viajeId = prefs.getInt('current_viaje_id');

    if (viajeId != null) {
      _viajeSocket.conectar(viajeId).listen((mensaje) {
        final data = jsonDecode(mensaje);
        if (data['type'] == 'viaje_completado') {
          _finalizarFlujoViaje();
        }
        if (data['type'] == 'posicion_actualizada') {
          setState(() {
            _viaje!['conductor_lat'] = data['lat'];
            _viaje!['conductor_lon'] = data['lon'];
            // Actualizamos la ruta con la nueva posición del conductor
            _obtenerRutaOSRM(data['lat'], data['lon']);
          });
        }
      });
    }
  }

  void _finalizarFlujoViaje() {
    if (mounted) {
      _timerRefresco?.cancel();
      _viajeSocket.desconectar();
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('current_viaje_id');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("¡Has llegado a tu destino!"),
            backgroundColor: Colors.green),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CalificacionScreen(viajeId: _viaje!['id']),
          ),
        );
      }
    }
  }

  void _monitorearInternet() {
    _internetSubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      setState(() => _estaOnline = result != ConnectivityResult.none);
    });
  }

  @override
  void dispose() {
    _viajeSocket.desconectar();
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
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        List viajes = jsonDecode(response.body);
        final viajeActivo = viajes.firstWhere((v) => v["estado"] == "en_curso",
            orElse: () => null);

        if (viajeActivo != null) {
          setState(() {
            _viaje = viajeActivo;

            double cLat = double.tryParse(
                    viajeActivo['conductor_lat']?.toString() ?? "0") ??
                0.0;
            double cLon = double.tryParse(
                    viajeActivo['conductor_lon']?.toString() ?? "0") ??
                0.0;

            if (cLat != 0.0) {
              _obtenerRutaOSRM(cLat, cLon);
            }
          });
        } else {
          if (mounted) Navigator.pushReplacementNamed(context, '/viaje');
        }
      }
    } catch (e) {
      debugPrint("Error carga pasajero: $e");
    } finally {
      if (esPrimeraVez) setState(() => _estaCargando = false);
    }
  }

  Future<void> _obtenerRutaOSRM(double cLat, double cLon) async {
    if (!_estaOnline || _viaje == null) return;

    double pLat =
        double.tryParse(_viaje!['origen_lat']?.toString() ?? "0") ?? 0.0;
    double pLon =
        double.tryParse(_viaje!['origen_lon']?.toString() ?? "0") ?? 0.0;

    if (pLat == 0.0) return;

    // Feedback instantáneo: Línea recta mientras carga la ruta real
    if (_puntosRuta.isEmpty) {
      setState(() {
        _puntosRuta = [latLng.LatLng(cLat, cLon), latLng.LatLng(pLat, pLon)];
      });
    }

    final url =
        "https://router.project-osrm.org/route/v1/driving/$cLon,$cLat;$pLon,$pLat?overview=full&geometries=geojson&steps=false";
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        if (mounted) {
          setState(() {
            _puntosRuta = coords
                .map((c) => latLng.LatLng(c[1].toDouble(), c[0].toDouble()))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error ruta OSRM Pasajero: $e");
    }
  }

  void _llamarConductor() async {
    final tel = _viaje?['conductor_telefono'];
    if (tel == null) return;
    final url = Uri.parse("tel:$tel");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_estaCargando)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    double cLat =
        double.tryParse(_viaje?['conductor_lat']?.toString() ?? "20.1373") ??
            20.1373;
    double cLon =
        double.tryParse(_viaje?['conductor_lon']?.toString() ?? "-90.1749") ??
            -90.1749;
    double pLat =
        double.tryParse(_viaje?['origen_lat']?.toString() ?? "20.1373") ??
            20.1373;
    double pLon =
        double.tryParse(_viaje?['origen_lon']?.toString() ?? "-90.1749") ??
            -90.1749;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: latLng.LatLng(cLat, cLon),
              initialZoom: 16.5,
              onMapReady: () => setState(() => _mapaListo = true),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kooneex.app',
              ),
              if (_puntosRuta.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                        points: _puntosRuta,
                        strokeWidth: 5,
                        color: Colors.orange.withOpacity(0.7)),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: latLng.LatLng(cLat, cLon),
                    width: 60,
                    height: 60,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          color: Colors.white,
                          child: const Text("Moto",
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const Icon(Icons.motorcycle,
                            color: Color(0xFFF7931E), size: 40),
                      ],
                    ),
                  ),
                  Marker(
                    point: latLng.LatLng(pLat, pLon),
                    child: const Icon(Icons.person_pin_circle,
                        color: Colors.blue, size: 45),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                _buildDriverCard(),
                const Spacer(),
                _buildStatusBanner(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("TU MOTOTAXISTA ESTÁ EN CAMINO",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange)),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  radius: 25,
                  backgroundColor: Color(0xFFF7931E),
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
                title: Text(_viaje?['mototaxista_nombre'] ?? "Conductor",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                trailing: IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green, size: 30),
                  onPressed: _llamarConductor,
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniInfo(Icons.star, "4.8", Colors.amber),
                  _buildMiniInfo(Icons.payments, "\$${_viaje?['costo_final']}",
                      Colors.green),
                  _buildMiniInfo(Icons.timer, "Llega en ~5 min", Colors.blue),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFFF7931E))),
          SizedBox(width: 15),
          Text("ESPERANDO TU LLEGADA AL DESTINO",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  void _mostrarDialogoCalificacion(BuildContext context, int viajeId) {
    double ratingSeleccionado = 5.0;
    final TextEditingController comentarioController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible:
          false, // Obligamos a que califique o use el botón de cerrar
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "¡Has llegado a tu destino!",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("¿Cómo calificarías el servicio del mototaxista?"),
            const SizedBox(height: 20),
            // Si no tienes la librería de estrellas, puedes usar iconos simples o un Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    Icons.star,
                    color: index < ratingSeleccionado
                        ? const Color(0xFFF7931E)
                        : Colors.grey[300],
                    size: 32,
                  ),
                  onPressed: () {
                    // Actualizar el estado del diálogo (necesitarás un StatefulBuilder dentro si quieres que cambien de color)
                  },
                );
              }),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: comentarioController,
              decoration: InputDecoration(
                hintText: "Escribe un comentario...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // LIMPIEZA CRÍTICA: Eliminar el ID antes de salir
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('current_viaje_id');

              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/viaje', (route) => false);
              }
            },
            child: const Text("OMITIR", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7931E),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              UIUtils.showLoading(context);
              // Aquí llamas a tu API de Django para guardar la calificación
              await AuthService().enviarCalificacionBackend(context, viajeId,
                  ratingSeleccionado, comentarioController.text);

              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('current_viaje_id');

              if (context.mounted) {
                UIUtils.dismissLoading(context);
                // Una vez calificado, regresamos a la pantalla principal
                Navigator.pushNamedAndRemoveUntil(
                    context, '/viaje', (route) => false);
              }
            },
            child:
                const Text("CALIFICAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
