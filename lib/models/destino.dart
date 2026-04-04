// models/destino.dart
class Destino {
  final int id;
  final String nombre;
  final double latitud;
  final double longitud;

  Destino({
    required this.id,
    required this.nombre,
    required this.latitud,
    required this.longitud,
  });

  // Constructor para convertir el JSON de Django a objeto Dart
  factory Destino.fromJson(Map<String, dynamic> json) {
    return Destino(
      id: json['id'],
      nombre: json['nombre'],
      latitud: double.parse(json['latitud'].toString()),
      longitud: double.parse(json['longitud'].toString()),
    );
  }
}