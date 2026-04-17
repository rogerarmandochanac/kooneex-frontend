import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/ui_utils.dart';

class HistorialScreen extends StatefulWidget {
  final bool esMototaxista;
  const HistorialScreen({super.key, required this.esMototaxista});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _authService = AuthService();
  List<dynamic> _viajes = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _obtenerDatos();
  }

  Future<void> _obtenerDatos() async {
    try {
      final lista = await _authService.getHistorialViajes();
      if (mounted) {
        setState(() {
          _viajes = lista;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        UIUtils.showError(context, "No se pudo cargar el historial");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco puro solicitado
      appBar: AppBar(
        title: const Text("Mis Viajes Recientes",
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF7931E)))
          : _viajes.isEmpty
              ? _buildSinViajes()
              : RefreshIndicator(
                  onRefresh: _obtenerDatos,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    itemCount: _viajes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) =>
                        _buildCardViaje(_viajes[index]),
                  ),
                ),
    );
  }

  Widget _buildCardViaje(dynamic viaje) {
    Color statusColor =
        viaje['estado'] == 'completado' ? Colors.green : Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7931E).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.near_me_rounded,
                      color: Color(0xFFF7931E), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viaje['destino']['nombre'] ?? "Destino",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        viaje['fecha_formateada'] ?? "Reciente",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "\$${viaje['costo_final'] ?? viaje['costo_estimado']}",
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    // AQUÍ ESTABA EL ERROR, CORREGIDO A EdgeInsets.only
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        viaje['estado'].toString().toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50], // Fondo gris muy tenue para la info extra
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text("${viaje['cantidad_pasajeros']} Pasajeros",
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const Spacer(),
                if (viaje['mototaxista_nombre'] != null) ...[
                  Icon(Icons.verified_user_outlined,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                      widget.esMototaxista
                          ? viaje['pasajero_nombre']
                          : viaje['mototaxista_nombre'],
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinViajes() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined, size: 70, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text("No hay actividad reciente",
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
