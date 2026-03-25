import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViajeSocketService {
  WebSocketChannel? _channel;

  // URL base para el socket (usa tu IP de Django)
  final String _wsBaseUrl = "ws://192.168.1.105:8000/ws/viaje";

  Stream<dynamic> conectar(int viajeId) {
    final url = "$_wsBaseUrl/$viajeId/";
    print("🔌 Conectando a WS: $url");
    
    _channel = WebSocketChannel.connect(Uri.parse(url));
    return _channel!.stream;
  }

  void desconectar() {
    _channel?.sink.close();
    print("🔌 WS desconectado manualmente");
  }
}