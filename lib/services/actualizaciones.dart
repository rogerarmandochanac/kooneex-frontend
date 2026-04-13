import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // También asegúrate de tener este para usar jsonDecode

Future<Map<String, dynamic>?> verificarActualizacion() async {
  try {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String versionActual = packageInfo.version;

    final response =
        await http.get(Uri.parse('http://3.21.34.42/api/check_version/'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['version_minima'] != versionActual) {
        return data; // Retorna los datos si las versiones no coinciden
      }
    }
  } catch (e) {
    print("Error al verificar versión: $e");
  }
  return null;
}
