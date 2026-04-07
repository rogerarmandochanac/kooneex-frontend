import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PushNotificationService {
  static FirebaseMessaging messaging = FirebaseMessaging.instance;
  static String? token;

  static Future initializeApp() async {
    // 1. Pedir permisos (Vital para Android 13+)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Obtener el Token del dispositivo
    token = await messaging.getToken();
    print("FCM TOKEN: $token");

    // 3. Enviar el token a Django (Si el usuario ya está logueado)
    if (token != null) {
      await _actualizarTokenEnServidor(token!);
    }
  }

  static Future _actualizarTokenEnServidor(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('access_token');
    
    if (authToken == null) return;

    // Tu endpoint en Django para guardar el token del mototaxista
    await http.post(
      Uri.parse('http://3.21.34.42:8000/api/usuarios/guardar_token/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'fcm_token': token,
      }),
    );
  }
}