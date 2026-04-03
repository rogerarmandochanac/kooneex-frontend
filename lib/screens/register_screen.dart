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

  // Controladores de texto
  final _userController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  String _selectedRol = 'pasajero';
  File? _imageFile;
  bool _isObscure = true;

  /// Captura de foto optimizada
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _handleRegister() async {
    // 1. Validaciones de formulario (Campos vacíos, formatos, etc.)
    if (!_formKey.currentState!.validate()) return;

    // 2. Validación manual de la foto
    if (_imageFile == null) {
      _showSnackBar("Por favor, tómate una foto para continuar.", isError: true);
      return;
    }

    _showLoading();

    final result = await _authService.register(
      username: _userController.text.trim(),
      password: _passController.text,
      email: _emailController.text.trim(),
      firstName: _nameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      telefono: _phoneController.text.trim(),
      rol: _selectedRol,
      foto: _imageFile!,
    );

    if (mounted) Navigator.pop(context); // Quitar spinner

    if (result['success']) {
      _showSnackBar("Cuenta creada con éxito", isError: false);
      if (mounted) Navigator.pop(context);
    } else {
      _showSnackBar(result['message'], isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFF7931E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Registro", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar de Perfil
              Center(
                child: GestureDetector(
                  onTap: _takePhoto,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                    child: _imageFile == null 
                      ? const Icon(Icons.add_a_photo, size: 40, color: brandColor) 
                      : null,
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Inputs de Texto
              _buildField(_userController, "Usuario", Icons.account_circle),
              _buildField(_nameController, "Nombre", Icons.person),
              _buildField(_lastNameController, "Apellido", Icons.person_outline),
              _buildField(_emailController, "Correo", Icons.email, type: TextInputType.emailAddress),
              _buildField(_phoneController, "Teléfono", Icons.phone, type: TextInputType.phone),

              // Campo Contraseña
              _buildField(
                _passController, 
                "Contraseña", 
                Icons.lock_outline, 
                obscure: _isObscure,
                isPassword: true,
              ),

              // Verificación de Contraseña (Validación cruzada)
              _buildField(
                _confirmPassController,
                "Repetir Contraseña",
                Icons.lock_reset,
                obscure: _isObscure,
                isPassword: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Confirma tu contraseña";
                  if (value != _passController.text) return "Las contraseñas no coinciden";
                  return null;
                },
              ),

              const SizedBox(height: 15),
              const Text("¿Cuál será tu rol?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),

              // Selector de Rol Mejorado (Tarjetas visuales)
              Row(
                children: [
                  Expanded(child: _roleCard('pasajero', 'Soy Pasajero', Icons.directions_walk, brandColor)),
                  const SizedBox(width: 15),
                  Expanded(child: _roleCard('mototaxista', 'Soy Conductor', Icons.motorcycle, brandColor)),
                ],
              ),

              const SizedBox(height: 35),

              ElevatedButton(
                onPressed: _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("FINALIZAR REGISTRO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de selección de rol con feedback visual claro
  Widget _roleCard(String role, String label, IconData icon, Color activeColor) {
    bool isSelected = _selectedRol == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRol = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? activeColor : Colors.grey[300]!, width: 2),
          boxShadow: isSelected ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// Generador de inputs estilizados
  Widget _buildField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {bool obscure = false, bool isPassword = false, TextInputType type = TextInputType.text, String? Function(String?)? validator}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        validator: validator ?? (value) => value!.isEmpty ? "Campo obligatorio" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFFF7931E)),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _isObscure = !_isObscure),
          ) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFF7931E))),
    );
  }
}