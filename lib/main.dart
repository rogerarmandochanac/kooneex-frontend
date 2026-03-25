import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kooneex_app/screens/esperando_confirmacion.dart';
import 'screens/login_screen.dart';
import 'screens/viaje_screen.dart'; // La crearemos ahora
import 'screens/solicitudes_screen.dart'; // La crearemos ahora
import 'screens/register_screen.dart'; // La crearemos ahora
import 'screens/ofertas_screen.dart'; // La crearemos ahora

void main() async {
  // Asegura que los servicios de Flutter estén listos antes de ejecutar la app
  WidgetsFlutterBinding.ensureInitialized();

  // Configuración opcional: Forzar orientación vertical (estilo móvil)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const KooneexApp());
}

class KooneexApp extends StatelessWidget {
  const KooneexApp({super.key});

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
      home: const LoginScreen(),

      // RUTAS DE NAVEGACIÓN (Equivalente a cargar_resto_de_pantallas)
      // Aquí iremos agregando las pantallas conforme las creemos
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registro': (context) => const RegisterScreen(),
        '/viaje': (context) => const ViajeScreen(), // Pantalla Pasajero
        '/solicitudes': (context) => const SolicitudesScreen(), // Pantalla Mototaxista
        '/ofertas': (context) => const OfertasScreen(), // Antes era /tarifas
        '/esperando_confirmacion': (context) => const EsperandoConfirmacionScreen(), // Antes era /tarifas
      },
    );
  }
}