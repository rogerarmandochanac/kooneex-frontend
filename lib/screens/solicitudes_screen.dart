import 'package:flutter/material.dart';

class SolicitudesScreen extends StatelessWidget {
  const SolicitudesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Viajes Pendientes")),
      body: const Center(child: Text("Lista de solicitudes para el Mototaxista")),
    );
  }
}