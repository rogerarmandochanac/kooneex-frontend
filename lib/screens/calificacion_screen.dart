import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/ui_utils.dart';

class CalificacionScreen extends StatefulWidget {
  final int viajeId;
  const CalificacionScreen({super.key, required this.viajeId});

  @override
  State<CalificacionScreen> createState() => _CalificacionScreenState();
}

class _CalificacionScreenState extends State<CalificacionScreen> {
  double _rating = 5.0;
  final TextEditingController _comentarioController = TextEditingController();

  // Función para obtener el icono según la calificación
  IconData _getReactionIcon() {
    if (_rating <= 2) return Icons.sentiment_very_dissatisfied;
    if (_rating <= 3) return Icons.sentiment_neutral;
    if (_rating <= 4) return Icons.sentiment_satisfied;
    return Icons.sentiment_very_satisfied;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Fondo suave
      appBar: AppBar(
        title: const Text("Finalizar Viaje",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF7931E),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false, //
      ),
      body: SingleChildScrollView(
        // Evita errores de overflow con el teclado
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            children: [
              // Card principal de calificación
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      _getReactionIcon(),
                      size: 80,
                      color: const Color(0xFFF7931E),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "¿Cómo estuvo tu viaje?",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tu opinión ayuda a mejorar la comunidad de Kooneex",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    // Estrellas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () => setState(() => _rating = index + 1.0),
                          child: Icon(
                            index < _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFF7931E),
                            size: 50,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Campo de comentario
              TextField(
                controller: _comentarioController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Cuéntanos más sobre el servicio...",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Color(0xFFF7931E), width: 1),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Botones de acción
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7931E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    UIUtils.showLoading(context);
                    await AuthService().enviarCalificacionBackend(context,
                        widget.viajeId, _rating, _comentarioController.text);

                    if (context.mounted) {
                      UIUtils.dismissLoading(context);
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/viaje', (route) => false);
                    }
                  },
                  child: const Text(
                    "ENVIAR CALIFICACIÓN",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/viaje', (route) => false),
                child: Text(
                  "Ahora no, omitir",
                  style: TextStyle(
                      color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
