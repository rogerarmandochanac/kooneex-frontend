import 'package:web_socket_channel/web_socket_channel.dart';

class MototaxiSocketService {
  WebSocketChannel? _channel;
  // URL que usabas en Kivy: {WS_URL}/mototaxi/
  final String _url = "ws://192.168.1.105:8000/ws/mototaxi/";

  Stream<dynamic> conectar() {
    print("🔌 Conectando mototaxi al canal global...");
    _channel = WebSocketChannel.connect(Uri.parse(_url));
    return _channel!.stream;
  }

  void desconectar() {
    _channel?.sink.close();
  }
}