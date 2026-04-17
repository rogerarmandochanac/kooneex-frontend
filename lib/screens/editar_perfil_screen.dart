import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../utils/ui_utils.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  String? _currentPhotoUrl;
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService(); // Instancia única del servicio

  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _imageFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatosUsuario();
    }); // Cargar datos al abrir la pantalla
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70 // Calidad optimizada para Kooneex
        );

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    UIUtils.showLoading(context);

    final result = await _authService.actualizarPerfil(
      username: _usernameController.text.trim(),
      firstName: _nameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      telefono: _phoneController.text.trim(),
      foto: _imageFile,
    );

    if (mounted) {
      UIUtils.dismissLoading(context);
      if (result['success']) {
        UIUtils.showSnackBar(context, "Perfil actualizado con éxito");
        Navigator.pop(context);
      } else {
        UIUtils.showError(context, result['message'] ?? "Error al actualizar");
      }
    }
  }

  Widget _buildField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: (value) =>
            (value == null || value.isEmpty) ? "Este campo es requerido" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon:
              Icon(icon, color: const Color(0xFFF7931E)), // Naranja Kooneex
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFF7931E)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Editar Perfil",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _takePhoto,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                              as ImageProvider // Foto nueva local
                          : (_currentPhotoUrl != null &&
                                  _currentPhotoUrl!.isNotEmpty)
                              ? NetworkImage(_currentPhotoUrl!)
                                  as ImageProvider // Foto remota del servidor
                              : null,
                      child: (_imageFile == null && _currentPhotoUrl == null)
                          ? const Icon(Icons.person,
                              size: 60, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      // Usamos Positioned directamente para evitar errores
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF7931E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildField(
                  _usernameController, "Nombre de usuario", Icons.person),
              _buildField(_nameController, "Nombre", Icons.person),
              _buildField(
                  _lastNameController, "Apellido", Icons.person_outline),
              _buildField(_emailController, "Email", Icons.email,
                  type: TextInputType.emailAddress),
              _buildField(_phoneController, "Teléfono", Icons.phone,
                  type: TextInputType.phone),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _guardarCambios,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("GUARDAR CAMBIOS",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/cambiar-password'),
                icon: const Icon(Icons.lock_outline, color: Colors.grey),
                label: const Text("Cambiar contraseña",
                    style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      if (!mounted) return;
      UIUtils.showLoading(context); // Opcional: mostrar loading mientras carga

      // Suponiendo que tienes un método getPerfil en tu AuthService
      final userData = await _authService.getPerfil();

      if (userData != null && mounted) {
        setState(() {
          _usernameController.text = userData['username'] ?? '';
          _nameController.text = userData['first_name'] ?? '';
          _lastNameController.text = userData['last_name'] ?? '';
          _emailController.text = userData['email'] ?? '';
          _phoneController.text = userData['telefono'] ?? '';
          _currentPhotoUrl = userData['foto'];
          // Nota: La foto no se asigna al _imageFile porque es un String URL,
          // manejaremos la previsualización en el build.
        });
      }
    } catch (e) {
      UIUtils.showError(context, "Error al cargar datos del perfil");
    } finally {
      if (mounted) UIUtils.dismissLoading(context);
    }
  }
}
