import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/register_screen.dart';
import '../services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}


class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  String _mensaje = "";
  bool _isObscure = true;

  void _handleLogin() async {
    _showLoading(); // Muestra el spinner de carga

    final result = await _authService.login(
      _usernameController.text,
      _passwordController.text,
    );

    if (result['success']) {
      // 1. Obtenemos el rol del usuario (igual que en login.py)
      String? rol = await _authService.getUsuarioRol(result['token']);

      // 2. Iniciar rastreo (Usando el Singleton)
      // Nota: No usamos 'await' aquí para que no se congele la pantalla
      LocationService().iniciarRastreo().catchError((e) {
        debugPrint("Error al activar GPS: $e");
      });
      
      // 2. Verificamos el estado del viaje en el backend
      final estadoViaje = await _authService.verificarEstadoViaje();
      final prefs = await SharedPreferences.getInstance();
      
      Navigator.pop(context); // Quitamos el spinner
      // 🔥 GUARDAR EL ID DEL VIAJE SI EXISTE
      // Asumiendo que el backend lo envía como estadoViaje['viaje_id']
      if (estadoViaje['viaje_id'] != null) {
        await prefs.setInt('current_viaje_id', estadoViaje['viaje_id']); //
      } else {
        // Si no hay viaje activo, es vital limpiar cualquier ID viejo
        await prefs.remove('current_viaje_id'); //
      }
      // 3. Lógica de redirección basada en tu código Kivy 
      if (rol == "pasajero") {
        if (estadoViaje['mensaje'] == "tiene_viaje_activo") {
          Navigator.pushReplacementNamed(context, '/espera_viaje');
        } else if (estadoViaje['mensaje'] == "tiene_viaje_pendiente") {
          Navigator.pushReplacementNamed(context, '/ofertas');
        } else {
          Navigator.pushReplacementNamed(context, '/viaje');
        }
      } 
      else if (rol == "mototaxista") {
        if (estadoViaje['mensaje'] == "tiene_viaje_aceptado") {
          Navigator.pushReplacementNamed(context, '/aceptar_viaje');
        } else if (estadoViaje['mensaje'] == "tiene_viaje_en_curso") {
          Navigator.pushReplacementNamed(context, '/viaje_en_curso');
        } else if(estadoViaje['mensaje'] == "tiene_viaje_ofertado"){
          Navigator.pushReplacementNamed(context, '/esperando_confirmacion');
        }
        
        else {
          Navigator.pushReplacementNamed(context, '/solicitudes');
        }
      }
    } else {
      Navigator.pop(context); // Quitar spinner
      setState(() { _mensaje = result['message']; });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7931E), // Tu color naranja de Kivy
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/logo_blanco.png", height: 120),
                const SizedBox(height: 15),
                const Text(
                  "Iniciar Sesión",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 35),
                // Campo Usuario
                TextField(
                  controller: _usernameController,
                  decoration: _inputDecoration("Usuario", Icons.person),
                ),
                const SizedBox(height: 15),
                // Campo Contraseña
                TextField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  decoration: _inputDecoration("Contraseña", Icons.lock).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                // Botón Ingresar
                _buildButton("Ingresar", Colors.white, const Color(0xFFF7931E), _handleLogin),
                const SizedBox(height: 15),
                // Botón Registro
                _buildButton("Crear Cuenta", Colors.transparent, Colors.white, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                }, outline: true),
                const SizedBox(height: 30),
                Text(_mensaje, style: const TextStyle(color: Colors.white, fontFamily: 'Poppins')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white),
      filled: true,
      fillColor: Colors.white.withOpacity(0.25),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
    );
  }

  Widget _buildButton(String text, Color bg, Color textColor, VoidCallback onPressed, {bool outline = false}) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: outline ? const BorderSide(color: Colors.white, width: 1.5) : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: Text(text, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
      ),
    );
  }

  // Método para mostrar el círculo de carga (Spinner)
  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false, // Evita que se cierre tocando fuera
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Colors.white, // O el color que prefieras
        ),
      ),
    );
  }

  // Método para mostrar errores (Snackbar)
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

}