import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Asegúrate de tener esta dependencia en pubspec.yaml

class AyudaScreen extends StatelessWidget {
  const AyudaScreen({super.key});

  // Método para abrir WhatsApp o Soporte
  Future<void> _contactarSoporte() async {
    const url = "https://wa.me/9961028404";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Centro de Ayuda",
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Buscador visual (solo diseño)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  hintText: "¿En qué podemos ayudarte?",
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 30),

            _buildSeccionTitulo("Para Pasajeros"),
            _buildPregunta("¿Cómo pido un servicio en Kooneex?",
                "Indica tu ubicación, destino, numero de pasajeros y una referencia del lugar donde te encuentras (ej. color de casa o negocio cercano) para que el mototaxista te encuentre rápido, luego solo espera las ofertas de los mototaxistas cercanos."),
            _buildPregunta("¿Cómo se calculan los precios?",
                "Usamos tarifas fijas por zona, más una comisión de \$1 por el uso de la aplicación."),

            const SizedBox(height: 20),

            _buildSeccionTitulo("Para Mototaxistas"),
            _buildPregunta("¿Cómo acepto nuevas solicitudes?",
                "Revisa la ubicación y destino. Envía tu oferta (puedes ajustarla si es necesario) y espera la aceptación del cliente. Al terminar el recorrido, usa el botón verde para finalizar."),
            _buildPregunta("Requisitos para ser conductor",
                "Por el momento, solo necesitas ser mayor de edad para empezar a ofrecer tus servicios."),

            const SizedBox(height: 40),

            // Botón de contacto directo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF7931E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: const Color(0xFFF7931E).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    "¿Aún tienes dudas?",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Nuestro equipo de soporte está disponible para ayudarte 24/7.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _contactarSoporte,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text("Contactar Soporte"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF7931E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFFF7931E),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPregunta(String pregunta, String respuesta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ExpansionTile(
        shape: const Border(), // Quita la línea divisoria por defecto
        leading:
            const Icon(Icons.help_outline, color: Color(0xFFF7931E), size: 20),
        title: Text(
          pregunta,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(
              respuesta,
              style: const TextStyle(
                  color: Colors.black54, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
