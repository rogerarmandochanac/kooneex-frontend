// lib/models/destino.dart
class Destino {
  final String nombre;
  final double latitud;
  final double longitud;

  Destino({required this.nombre, required this.latitud, required this.longitud});

  factory Destino.fromJson(Map<String, dynamic> json) {
    return Destino(
      nombre: json['nombre'],
      latitud: json['latitud'],
      longitud: json['longitud'],
    );
  }
}