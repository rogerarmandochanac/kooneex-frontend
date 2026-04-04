import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/destino.dart';

class AuthService {
  // Cambia esta URL por la de tu servidor Django
  final String _baseUrl = "http://192.168.1.105:8000/api"; 

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('current_viaje_id');
        await prefs.setString('access_token', data['access']);
        return {'success': true, 'token': data['access']};
      } else {
        return {'success': false, 'message': 'Credenciales incorrectas'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }



  // ESTA ES LA FUNCIÓN QUE FALTA O ESTÁ MAL DEFINIDA
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String email,
    required String firstName,
    required String lastName,
    required String telefono,
    required String rol,
    required File foto, // Importante para tu lógica de registro.py 
  }) async {
    try {
      // Usamos MultipartRequest para enviar la imagen igual que en tu código Kivy 
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/usuarios/registro/'));
      
      request.fields.addAll({
        'username': username,
        'password': password,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'telefono': telefono,
        'rol': rol,
      });

      // Adjuntamos la foto tomada desde la cámara
      request.files.add(await http.MultipartFile.fromPath('foto', foto.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'message': errorData['error'] ?? 'Error al crear usuario'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  Future<String?> getUsuarioRol(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/usuario/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['rol'];
      }
    } catch (e) {
      print("Error obteniendo rol: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> verificarEstadoViaje() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('$_baseUrl/viajes/verificar_viajes_activos/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error verificando viaje: $e");
    }
    return {'mensaje': 'none'};
  }

  Future<List<Destino>> getDestinos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      final response = await http.get(
        Uri.parse('$_baseUrl/destino/'),
        headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Decodificamos el cuerpo de la respuesta que es una List
        List<dynamic> data = json.decode(response.body);
        
        // Convertimos cada mapa de la lista en un objeto Destino
        return data.map((json) => Destino.fromJson(json)).toList();
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      print("Error en getDestinos: $e");
      return []; // Devolvemos lista vacía para evitar que la UI falle
    }
  }

Future<bool> crearViaje(Map<String, dynamic> datos) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.post(
      Uri.parse('$_baseUrl/viajes/'), 
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(datos),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      // Guardamos el ID del viaje recién creado para seguimiento
      await prefs.setInt('current_viaje_id', data['id']);
      return true;
    }
    return false;
  } catch (e) {
    print("Error en crearViaje: $e");
    return false;
  }
}

Future<List<dynamic>> obtenerOfertas() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final viajeId = prefs.getInt('current_viaje_id'); // El ID que guardamos al crear el viaje

    if (viajeId == null) return [];

    final response = await http.get(
      Uri.parse('$_baseUrl/ofertas/?viaje_id=$viajeId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      print("Error al obtener ofertas: ${response.statusCode}");
      return [];
    }
  } catch (e) {
    print("Error de conexión en obtenerOfertas: $e");
    return [];
  }
}

Future<bool> aceptarOferta(int ofertaId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.patch(
      Uri.parse('$_baseUrl/ofertas/$ofertaId/aceptar/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  } catch (e) {
    print("Error al aceptar oferta: $e");
    return false;
  }
}

Future<bool> eliminarViaje() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final viajeId = prefs.getInt('current_viaje_id');

    if (viajeId == null) return false;

    final response = await http.delete(
      Uri.parse('$_baseUrl/viajes/$viajeId/eliminar/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      await prefs.remove('current_viaje_id'); // Limpiamos el ID local
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}

Future<List<dynamic>> obtenerViajesDisponibles() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  final response = await http.get(
    Uri.parse('$_baseUrl/viajes/'), // Django filtrará los "pendientes"
    headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
  );
  return response.statusCode == 200 ? jsonDecode(response.body) : [];
}

Future<bool> enviarOferta(int viajeId, String monto) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  await prefs.setInt('current_viaje_id', viajeId);
  
  final response = await http.post(
    Uri.parse('$_baseUrl/ofertas/'),
    headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      "viaje": viajeId,
      "monto": double.parse(monto),
      "tiempo_estimado": 30, // Valor fijo como tenías en Python
    }),
  );
  return response.statusCode == 201;
}

Future<bool> actualizarUbicacion(double lat, double lng) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  try {
    final response = await http.post(
      Uri.parse('$_baseUrl/usuarios/actualizar_ubicacion/'), // Ajusta a tu endpoint de perfil
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "lat": lat,
        "lon": lng,
      }),
    );
    return response.statusCode == 200;
  } catch (e) {
    return false;
  }
}

// lib/services/auth_service.dart
Future<bool> cancelarOfertaPropia() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');// Usamos el ID del viaje actual
  final viajeId = prefs.getInt('current_viaje_id');
  
  final response = await http.delete(
    Uri.parse('$_baseUrl/ofertas/$viajeId/rechazar/'), // Tu endpoint de Django
     headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
  );
  return response.statusCode == 200;
}


// lib/services/auth_service.dart

Future<bool> cambiarEstadoViaje(int viaje) async {
  final prefs = await SharedPreferences.getInstance();
  final viajeId = prefs.getInt('current_viaje_id');
  final token = prefs.getString('access_token');

  final response = await http.patch(
    Uri.parse('$_baseUrl/viajes/$viaje/en_curso/'), // Endpoint: .../viajes/ID/en_curso/ 
    headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    body: jsonEncode({"estado": "en_curso"}),
  );
  
  return response.statusCode == 200 || response.statusCode == 202;
}

Future<Map<String, dynamic>?> obtenerViajeActual() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    final response = await http.get(
      Uri.parse('$_baseUrl/viajes/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> viajes = jsonDecode(response.body);
      
      // Filtramos el viaje activo (aceptado o en_curso)
      final viajeActivo = viajes.firstWhere(
        (v) => v["estado"] == "aceptado" || v["estado"] == "en_curso",
        orElse: () => null,
      );

      return viajeActivo;
    }
    return null;
  } catch (e) {
    print("Error en obtenerViajeActual: $e");
    return null;
  }
}

Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear(); // Borra todo: token, viajeId, etc.
}

}