class ApiConfig {
  static const bool isLocal = false; // Cambia a false para producción

  static const String ipCloud = '3.21.34.42';
  static const String ipLocal = '192.168.1.103:8000';

  static String get currentIp => isLocal ? ipLocal : ipCloud;
}
