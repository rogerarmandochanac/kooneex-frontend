import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import './api_config.dart';

class OfflineService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), 'offline_gps.db'),
      onCreate: (db, version) => db.execute(
        "CREATE TABLE pendientes(id INTEGER PRIMARY KEY AUTOINCREMENT, lat REAL, lon REAL, timestamp TEXT)",
      ),
      version: 1,
    );
    return _db!;
  }

  // Guardar ubicación si falla el internet
  Future<void> guardarUbicacionOffline(double lat, double lon) async {
    final db = await database;
    await db.insert('pendientes', {
      'lat': lat,
      'lon': lon,
      'timestamp': DateTime.now().toIso8601String(),
    });
    print("📍 Ubicación guardada localmente (Modo Offline)");
  }

  // Intentar subir todo lo pendiente
  Future<void> subirPendientes() async {
    final db = await database;
    final List<Map<String, dynamic>> pendientes = await db.query('pendientes');

    if (pendientes.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    for (var p in pendientes) {
      try {
        final response = await http.post(
          Uri.parse(
              'http://${ApiConfig.currentIp}/api/usuarios/actualizar_ubicacion/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          body: jsonEncode({'lat': p['lat'], 'lon': p['lon']}),
        );

        if (response.statusCode == 200) {
          await db.delete('pendientes', where: 'id = ?', whereArgs: [p['id']]);
        }
      } catch (e) {
        break; // Si sigue sin internet, dejar de intentar
      }
    }
    print("✅ Sincronización offline completada");
  }
}
