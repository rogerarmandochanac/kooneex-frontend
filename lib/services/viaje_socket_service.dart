import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class ViajeSocketService {
  WebSocketChannel? _channel;
  StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();
  bool _estaConectado = false;
  int _reintentos = 2; // Segundos para el primer reintento

  // Quitamos el puerto :8000 para que pase por Nginx (puerto 80)
  final String _wsBaseUrl = "ws://3.21.34.42:8000/ws/viaje";

  Stream<dynamic> conectar(int viajeId) {
    if (_estaConectado) return _controller.stream;
    
    _intentarConexion(viajeId);
    return _controller.stream;
  }

  void _intentarConexion(int viajeId) {
    final url = "$_wsBaseUrl/$viajeId/";
    print("🔌 Intentando conectar a: $url");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _estaConectado = true;

      _channel!.stream.listen(
        (mensaje) {
          _reintentos = 2; // Resetear reintentos si recibimos datos
          if (!_controller.isClosed) _controller.add(mensaje);
        },
        onDone: () => _manejarDesconexion(viajeId),
        onError: (error) => _manejarDesconexion(viajeId),
      );
    } catch (e) {
      _manejarDesconexion(viajeId);
    }
  }

  void _manejarDesconexion(int viajeId) {
    _estaConectado = false;
    print("❌ Conexión perdida. Reintentando en $_reintentos segundos...");
    
    Timer(Duration(seconds: _reintentos), () {
      if (_reintentos < 30) _reintentos *= 2; // Incremento exponencial
      _intentarConexion(viajeId);
    });
  }

  void desconectar() {
    _estaConectado = false;
    _channel?.sink.close();
    if (!_controller.isClosed) _controller.close();
    // Reiniciamos el controlador para la próxima vez
    _controller = StreamController<dynamic>.broadcast();
  }
}