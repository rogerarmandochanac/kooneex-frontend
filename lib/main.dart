import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/esperando_confirmacion.dart';
import 'screens/login_screen.dart';
import 'screens/viaje_screen.dart'; // La crearemos ahora
import 'screens/solicitudes_screen.dart'; // La crearemos ahora
import 'screens/register_screen.dart'; // La crearemos ahora
import 'screens/ofertas_screen.dart'; // La crearemos ahora
import 'screens/espera_viaje_screen.dart'; // La crearemos ahora
import 'screens/aceptar_viaje_screen.dart'; // La crearemos ahora
import 'screens/viaje_en_curso_screen.dart'; // La crearemos ahora
import 'screens/viaje_en_curso_pasajero_screen.dart'; // La crearemos ahora
import 'screens/cambiar_password_screen.dart';
import 'screens/update_screen.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'services/actualizaciones.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializaciones básicas
  await Firebase.initializeApp();

  // 2. Verificar versión antes de cualquier otra cosa
  final actualizacionRequerida = await verificarActualizacion();

  if (actualizacionRequerida != null) {
    // Si hay actualización, arrancamos la app con la pantalla de bloqueo
    runApp(KooneexApp(home: UpdateScreen(data: actualizacionRequerida)));
    return;
  }

  await PushNotificationService.initializeApp();
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapStore').manage.create();

  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('access_token');

  Widget pantallaInicial = const LoginScreen();

  if (token != null) {
    final authService = AuthService();

    // Obtenemos rol y estado del viaje simultáneamente
    final String? rol = await authService.getUsuarioRol(token);
    final estadoViaje = await authService.verificarEstadoViaje();

    if (rol == 'pasajero') {
      if (estadoViaje != null) {
        if (estadoViaje['mensaje'] == "tiene_viaje_activo") {
          pantallaInicial = const ViajeEnCursoPasajeroScreen();
        } else if (estadoViaje['mensaje'] == "tiene_viaje_pendiente") {
          pantallaInicial = const OfertasScreen();
        } else {
          pantallaInicial = const ViajeScreen();
        }
      } else {
        pantallaInicial = const ViajeScreen();
      }
    } else if (rol == 'mototaxista') {
      if (estadoViaje != null) {
        if (estadoViaje['mensaje'] == "tiene_viaje_aceptado") {
          pantallaInicial = const AceptarViajeScreen();
        } else if (estadoViaje['mensaje'] == "tiene_viaje_en_curso") {
          pantallaInicial = const ViajeEnCursoScreen();
        } else if (estadoViaje['mensaje'] == "tiene_viaje_ofertado") {
          pantallaInicial = const EsperandoConfirmacionScreen();
        } else {
          pantallaInicial = const SolicitudesScreen();
        }
      } else {
        pantallaInicial = const SolicitudesScreen();
      }
    }

    // Aprovechamos para asegurar que el token push esté vinculado
    PushNotificationService.registrarTokenEnServidor();
  }

  runApp(KooneexApp(home: pantallaInicial));
}

class KooneexApp extends StatelessWidget {
  const KooneexApp({super.key, required this.home});
  // 1. Declaramos la variable que recibirá la pantalla
  final Widget home;

  // 2. La agregamos al constructor como un parámetro requerido

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kooneex App',
      debugShowCheckedModeBanner: false,

      // CONFIGURACIÓN DE TEMA Y FUENTES (Reemplaza a LabelBase.register)
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.orange,
        fontFamily: 'Poppins', // Definida en tu pubspec.yaml
        scaffoldBackgroundColor: const Color(0xFFF7931E), // Naranja Kooneex
      ),

      // PANTALLA INICIAL (Reemplaza a self.sm.current = "login")
      home: home,

      // RUTAS DE NAVEGACIÓN (Equivalente a cargar_resto_de_pantallas)
      // Aquí iremos agregando las pantallas conforme las creemos
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registro': (context) => const RegisterScreen(),
        '/viaje': (context) => const ViajeScreen(), // Pantalla Pasajero
        '/solicitudes': (context) =>
            const SolicitudesScreen(), // Pantalla Mototaxista
        '/ofertas': (context) => const OfertasScreen(), // Antes era /tarifas
        '/esperando_confirmacion': (context) =>
            const EsperandoConfirmacionScreen(), // Antes era /tarifas
        '/espera_viaje': (context) => const EsperaViajeScreen(),
        '/aceptar_viaje': (context) => const AceptarViajeScreen(),
        '/viaje_en_curso': (context) => const ViajeEnCursoScreen(),
        '/viaje_en_curso_pasajero': (context) =>
            const ViajeEnCursoPasajeroScreen(),
        '/cambiar-password': (context) => const CambiarPasswordScreen(),
      },
    );
  }
}
