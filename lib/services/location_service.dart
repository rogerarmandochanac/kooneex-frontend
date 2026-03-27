import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  // 1. Implementación de Singleton
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final String _baseUrl = "http://192.168.1.105:8000/api";
  StreamSubscription<Position>? _positionStreamSubscription;

  // 2. Método para enviar la ubicación al servidor (PATCH)
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
    // Si ya hay un rastreo activo, no iniciamos otro para evitar el "frieze"
    if (_positionStreamSubscription != null) {
      debugPrint("ℹ️ El rastreo ya está activo.");
      return;
    }

    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el GPS está encendido
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("GPS desactivado en el dispositivo");
      return;
    }

    // Manejo de permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Actualización inmediata asíncrona (no bloquea la UI)
    Geolocator.getCurrentPosition().then((position) {
      enviarUbicacionAlServidor(position.latitude, position.longitude);
    }).catchError((e) => debugPrint("Error al obtener posición inicial: $e"));

    // Configuración del rastro constante
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Se actualiza cada 50 metros
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        enviarUbicacionAlServidor(position.latitude, position.longitude);
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