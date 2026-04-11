import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class MototaxiSocketService {
  // Singleton para usar la misma instancia en toda la app
  static final MototaxiSocketService _instance = MototaxiSocketService._internal();
  factory MototaxiSocketService() => _instance;
  MototaxiSocketService._internal();

  WebSocketChannel? _channel;
  final String _url = "ws://3.21.34.42:8000/ws/mototaxi/";
  
  // Este controlador enviará los mensajes a la UI
  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();
  bool _intentandoReconectar = false;

  Stream<dynamic> get stream => _controller.stream;

  void conectar() {
    if (_intentandoReconectar) return;
    
    print("🔌 Conectando mototaxi al canal global...");
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      
      _channel!.stream.listen(
        (data) {
          _controller.add(data); // Enviamos el mensaje al stream principal
        },
        onError: (error) {
          print("❌ Error en Socket: $error");
          _reconectar();
        },
        onDone: () {
          print("⚠️ Conexión de Socket cerrada.");
          _reconectar();
        },
      );
    } catch (e) {
      print("🚀 No se pudo conectar: $e");
      _reconectar();
    }
  }

  void _reconectar() {
    if (_intentandoReconectar) return;
    _intentandoReconectar = true;

    print("🔄 Reintentando conexión en 5 segundos...");
    Timer(const Duration(seconds: 5), () {
      _intentandoReconectar = false;
      conectar();
    });
  }

  void enviarMensaje(Map<String, dynamic> data) {
    _channel?.sink.add(data);
  }

  void desconectar() {
    _channel?.sink.close();
  }
}