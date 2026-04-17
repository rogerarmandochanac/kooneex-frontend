import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import './api_config.dart';

class LocationService {
  // 1. Implementación de Singleton
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final String _baseUrl = "http://${ApiConfig.currentIp}/api";
  StreamSubscription<Position>? _positionStreamSubscription;

  // NUEVO: Controlador para notificar a la UI sobre cambios de posición
  final _posicionController = StreamController<Position>.broadcast();

  // NUEVO: Stream público que escucharemos en la pantalla del mapa
  Stream<Position> get posicionStream => _posicionController.stream;

  // 2. Método para enviar la ubicación al servidor (PATCH/POST)
  Future<void> enviarUbicacionAlServidor(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        debugPrint("⚠️ No hay token disponible para actualizar ubicación.");
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/usuarios/actualizar_ubicacion/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lat': lat,
          'lon': lon,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("📍 Ubicación sincronizada con Django: $lat, $lon");
      } else {
        debugPrint("❌ Error Django (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error de red al actualizar ubicación: $e");
    }
  }

  // 3. Lógica de permisos y rastreo activo
  Future<void> iniciarRastreo() async {
    if (_positionStreamSubscription != null) {
      debugPrint("ℹ️ El rastreo ya está activo.");
      return;
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("GPS desactivado en el dispositivo");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Actualización inicial
    Geolocator.getCurrentPosition().then((position) {
      enviarUbicacionAlServidor(position.latitude, position.longitude);
      _posicionController
          .add(position); // Notificar a la UI la posición inicial
    }).catchError((e) => debugPrint("Error al obtener posición inicial: $e"));

    // Configuración del rastro constante
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Se actualiza cada 10 metros para Kooneex
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        // ACCIÓN 1: Sincronizar con el backend
        enviarUbicacionAlServidor(position.latitude, position.longitude);

        // ACCIÓN 2: Enviar al Stream para que el mapa se mueva en tiempo real
        _posicionController.add(position);
      },
      onError: (error) {
        debugPrint("❌ Error en el stream de ubicación: $error");
        detenerRastreo();
      },
    );
  }

  // 4. Método para detener el rastreo
  void detenerRastreo() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    debugPrint("🛑 Rastreo de ubicación detenido.");
  }
}
