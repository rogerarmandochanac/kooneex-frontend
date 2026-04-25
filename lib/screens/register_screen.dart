import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';

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

  // Estado para comunidades
  List<dynamic> _comunidades = [];
  String? _selectedComunidadId; // Almacenará el ID seleccionado
  bool _cargandoComunidades = true;

  @override
  void initState() {
    super.initState();
    _cargarComunidades();
  }

  Future<void> _cargarComunidades() async {
    try {
      // Necesitarás crear este método en AuthService o usar uno existente
      final lista = await _authService.getComunidadesPublicas();
      setState(() {
        _comunidades = lista;
        _cargandoComunidades = false;
      });
    } catch (e) {
      setState(() => _cargandoComunidades = false);
    }
  }

  /// Captura de foto optimizada
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 60,
        maxWidth: 800,
        maxHeight: 800);

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      _showSnackBar("La foto es obligatoria", isError: true);
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
      rol: "pasajero",
      foto: _imageFile!,
      comunidad: _selectedComunidadId!,
    );

    if (mounted) Navigator.pop(context); // Cierra el loading

    if (result['success']) {
      // 1. Iniciar sesión automáticamente para obtener el token JWT
      final loginResult = await _authService.login(
        _userController.text.trim(),
        _passController.text,
      );

      if (loginResult['success']) {
        // 2. Guardar el token de notificaciones push en Django
        await PushNotificationService.registrarTokenEnServidor();

        // 3. Evaluar el rol y redirigir (Igual que en Login)
        if (_selectedRol == 'mototaxista') {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
              context, '/solicitudes', (route) => false);
        } else {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
              context, '/viaje', (route) => false);
        }
      } else {
        // Si el login falla por alguna razón, enviamos al login normal
        _showSnackBar("Cuenta creada. Por favor, inicia sesión.",
            isError: false);
        if (!mounted) return;
        Navigator.pop(context);
      }
    } else {
      _showSnackBar(result['message'] ?? "Error al registrarte", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFFF7931E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Registro pasajero",
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                    backgroundImage:
                        _imageFile != null ? FileImage(_imageFile!) : null,
                    child: _imageFile == null
                        ? const Icon(Icons.add_a_photo,
                            size: 40, color: brandColor)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Inputs de Texto
              _buildField(
                  _userController, "Nombre de usuario", Icons.account_circle),
              const Padding(
                padding: EdgeInsets.only(top: 2, left: 8, bottom: 10),
                child: Text(
                  "Escribe tu usuario sin espacios (Ej: juanperez)",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              _buildField(_nameController, "Nombre", Icons.person),
              _buildField(
                  _lastNameController, "Apellido", Icons.person_outline),
              _buildField(_emailController, "Correo", Icons.email,
                  type: TextInputType.emailAddress),
              _buildField(_phoneController, "Teléfono", Icons.phone,
                  type: TextInputType.phone),

              const SizedBox(height: 10),
              const Text("¿En qué comunidad te encuentras?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                initialValue: _selectedComunidadId,
                decoration: InputDecoration(
                  labelText: "Selecciona tu comunidad",
                  prefixIcon:
                      const Icon(Icons.location_city, color: Color(0xFFF7931E)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: _comunidades.map((com) {
                  return DropdownMenuItem<String>(
                    value: com['id'].toString(),
                    child: Text(com['nombre']),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedComunidadId = value),
                // VALIDACIÓN: Evita que el valor sea nulo o blanco
                validator: (value) => (value == null || value.isEmpty)
                    ? "Debes seleccionar una comunidad"
                    : null,
              ),
              const SizedBox(height: 25),

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
                  if (value == null || value.isEmpty)
                    return "Confirma tu contraseña";
                  if (value != _passController.text)
                    return "Las contraseñas no coinciden";
                  return null;
                },
              ),

              // const SizedBox(height: 15),
              // const Text("¿Cuál será tu rol?",
              //     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              // const SizedBox(height: 15),

              // // Selector de Rol Mejorado (Tarjetas visuales)
              // Row(
              //   children: [
              //     Expanded(
              //         child: _roleCard('pasajero', 'Soy Pasajero',
              //             Icons.directions_walk, brandColor)),
              //     const SizedBox(width: 15),
              //     Expanded(
              //         child: _roleCard('mototaxista', 'Soy Conductor',
              //             Icons.motorcycle, brandColor)),
              //   ],
              // ),

              const SizedBox(height: 35),

              ElevatedButton(
                onPressed: _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandColor,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("FINALIZAR REGISTRO",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de selección de rol con feedback visual claro
  Widget _roleCard(
      String role, String label, IconData icon, Color activeColor) {
    bool isSelected = _selectedRol == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRol = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isSelected ? activeColor : Colors.grey[300]!, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: activeColor.withValues(alpha: .3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 32, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// Generador de inputs estilizados
  Widget _buildField(
      TextEditingController controller, String label, IconData icon,
      {bool obscure = false,
      bool isPassword = false,
      TextInputType type = TextInputType.text,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        validator:
            validator ?? (value) => value!.isEmpty ? "Campo obligatorio" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFFF7931E)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                      _isObscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                )
              : null,
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
      builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFF7931E))),
    );
  }
}
