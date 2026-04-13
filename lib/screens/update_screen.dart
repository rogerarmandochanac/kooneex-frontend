import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Para abrir el link de descarga

class UpdateScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const UpdateScreen({super.key, required this.data});

  // Función interna para abrir el navegador de forma segura
  Future<void> _lanzarDescarga(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("No se pudo abrir la URL: $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extraemos los datos del mapa que viene de Django
    final String urlDescarga = data['url_descarga'] ?? '';
    final String novedades =
        data['novedades'] ?? 'Mejoras generales en el servicio.';
    final String versionRequerida = data['version_minima'] ?? 'Nueva';

    return Scaffold(
      // Usamos el color naranja corporativo de Kooneex
      backgroundColor: const Color(0xFFF7931E),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono animado o estático de actualización
            const Icon(
              Icons.system_update_rounded,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 30),

            const Text(
              "¡Actualización Disponible!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 10),

            Text(
              "Versión requerida: $versionRequerida",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(height: 25),

            // Caja de novedades
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "¿Qué hay de nuevo?",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    novedades,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Botón de acción principal
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => _lanzarDescarga(urlDescarga),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFF7931E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  "DESCARGAR Y ACTUALIZAR",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Es necesario actualizar para seguir recibiendo o solicitando viajes.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
