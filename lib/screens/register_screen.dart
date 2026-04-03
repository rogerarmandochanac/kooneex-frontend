import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  
  // Controladores (Equivalente a los id en registro.kv)
  final _userController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  
  String _selectedRol = 'pasajero';
  File? _imageFile; // Para la foto de registro [cite: 50]
  final bool _isObscure = true;

  // Lógica de captura de foto (Sustituye a abrir_camara_nativa) [cite: 50]
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _handleRegister() async {
    // 1. Validaciones (Equivalente a registrar() en registro.py) [cite: 34, 40, 41, 47]
    if (!_formKey.currentState!.validate()) return;
    
    if (_imageFile == null) {
      _showError("Tómate una foto para el registro."); // [cite: 50]
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      _showError("Las contraseñas no coinciden."); // [cite: 47]
      return;
    }

    // Mostrar Spinner (Flutter lo hace con un Dialog)
    _showLoading();

    final result = await _authService.register(
      username: _userController.text,
      password: _passController.text,
      email: _emailController.text,
      firstName: _nameController.text,
      lastName: _lastNameController.text,
      telefono: _phoneController.text,
      rol: _selectedRol,
      foto: _imageFile!, // Enviamos el archivo de imagen
    );

    Navigator.pop(context); // Quitar spinner

    if (result['success']) {
      Navigator.pop(context); // Volver al login
      _showSuccess("Usuario creado correctamente");
    } else {
      _showError(result['message']);
    }
  }

  // --- MÉTODOS DE APOYO (UI) ---
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFF7931E))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Crear cuenta", style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: const Color(0xFFF7931E),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildInput(_userController, "Username", Icons.person, (v) => v!.length < 8 ? "Mínimo 8 caracteres" : null),
              _buildInput(_nameController, "Nombre(s)", Icons.badge, (v) => v!.isEmpty ? "Campo obligatorio" : null),
              _buildInput(_lastNameController, "Apellido(s)", Icons.badge, (v) => v!.isEmpty ? "Campo obligatorio" : null),
              _buildInput(_emailController, "Correo Electrónico", Icons.email, (v) => !v!.contains("@") ? "Email inválido" : null),
              _buildInput(_phoneController, "Teléfono", Icons.phone, (v) => v!.length != 10 ? "Deben ser 10 dígitos" : null, type: TextInputType.phone),
              _buildInput(_passController, "Contraseña", Icons.lock, (v) => v!.isEmpty ? "Campo obligatorio" : null, obscure: _isObscure),
              _buildInput(_confirmPassController, "Confirmar Contraseña", Icons.lock_outline, (v) => v != _passController.text ? "No coinciden" : null, obscure: _isObscure),
              
              const SizedBox(height: 20),
              const Text("Tipo de usuario", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF7931E))),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Radio(value: 'pasajero', groupValue: _selectedRol, onChanged: (v) => setState(() => _selectedRol = v!)),
                  const Text("Pasajero"),
                  Radio(value: 'mototaxista', groupValue: _selectedRol, onChanged: (v) => setState(() => _selectedRol = v!)),
                  const Text("Mototaxista"),
                ],
              ),
              
              const SizedBox(height: 20),
              // Botón de Foto [cite: 50]
              ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: Icon(Icons.camera_alt, color: _imageFile == null ? Colors.white : Colors.green),
                label: Text(_imageFile == null ? "Tomar Foto" : "Foto cargada", style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: _imageFile == null ? Colors.grey : Colors.green),
              ),

              const SizedBox(height: 40),
              // Botón Registrar (Equivalente al FloatingActionButton check) [cite: 52]
              ElevatedButton(
                onPressed: _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931E),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Registrarme", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, String? Function(String?)? validator, {bool obscure = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFFF7931E)),
          border: const UnderlineInputBorder(),
        ),
        validator: validator,
      ),
    );
  }
}