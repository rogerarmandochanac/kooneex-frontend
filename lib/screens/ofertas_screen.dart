import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/viaje_socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfertasScreen extends StatefulWidget {
  const OfertasScreen({super.key});

  @override
  State<OfertasScreen> createState() => _OfertasScreenState();
}

class _OfertasScreenState extends State<OfertasScreen> {
  final _socketService = ViajeSocketService();
  final _authService = AuthService();
  List<dynamic> _ofertas = [];
  bool _estaCargando = true;

  @override
  void initState() {
    super.initState();
    _escucharOfertas();
  }

  Future<void> _escucharOfertas() async {
    final prefs = await SharedPreferences.getInstance();
    final viajeId = prefs.getInt('current_viaje_id');
    if (viajeId != null) {
      await _cargarOfertasIniciales();

      _socketService.conectar(viajeId).listen((mensaje) {
        final data = jsonDecode(mensaje);
        if (data['type'] == 'nueva_oferta' || data['type'] == 'oferta_cancelada') {
          _cargarOfertasIniciales();
        }
      });
    }
  }

  Future<void> _cargarOfertasIniciales() async {
    // Solo mostramos el loading completo la primera vez para no interrumpir la vista
    if (_ofertas.isEmpty) setState(() => _estaCargando = true);
    
    final resultado = await _authService.obtenerOfertas(); 
    if (mounted) {
      setState(() {
        _ofertas = resultado;
        _estaCargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco Pro
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          "Ofertas Disponibles",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: _estaCargando 
          ? _buildWaitingState()
          : _ofertas.isEmpty 
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: _ofertas.length,
                  itemBuilder: (context, index) => _buildOfertaItem(_ofertas[index]),
                ),
      // Botón de cancelar viaje más elegante
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _ofertas.isNotEmpty ? Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextButton.icon(
          onPressed: _confirmarCancelacion,
          icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
          label: const Text("CANCELAR SOLICITUD", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          style: TextButton.styleFrom(
            backgroundColor: Colors.red[50],
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ) : null,
    );
  }

  Widget _buildWaitingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Color(0xFFF7931E),
              strokeWidth: 5,
            ),
          ),
          const SizedBox(height: 30),
          const Text("Buscando conductores...", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          Text("Enviando tu solicitud a los mototaxistas cercanos", 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hail_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 20),
          const Text("Casi listo...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Text("Esperando que alguien acepte tu viaje", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _confirmarCancelacion,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], elevation: 0),
            child: const Text("Cancelar búsqueda", style: TextStyle(color: Colors.black54)),
          )
        ],
      ),
    );
  }

  Widget _buildOfertaItem(dynamic oferta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Foto del Conductor con borde
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF7931E), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: NetworkImage(oferta['mototaxista_foto'] ?? 'https://via.placeholder.com/150'),
                  ),
                ),
                const SizedBox(width: 15),
                // Información
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        oferta['nombre'] ?? "Conductor",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "${oferta['calificacion'] ?? '4.8'} • ${oferta['viajes_totales'] ?? '100+'} viajes",
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Precio resaltado
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Precio", style: TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(
                      "\$${oferta['monto']}",
                      style: const TextStyle(
                        color: Color(0xFFF7931E),
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 25, thickness: 0.5),
            // Botón de Acción
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _aceptarOferta(oferta['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7931E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("ACEPTAR ESTA OFERTA", 
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _confirmarCancelacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Cancelar búsqueda?"),
        content: const Text("Tu solicitud de viaje será eliminada."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("MANTENER")),
          TextButton(onPressed: () {
            Navigator.pop(context);
            _cancelarViaje();
          }, child: const Text("CANCELAR VIAJE", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _aceptarOferta(int ofertaId) async {
    setState(() => _estaCargando = true);
    final exito = await _authService.aceptarOferta(ofertaId);
    if (exito) {
      if (mounted) Navigator.pushReplacementNamed(context, '/espera_viaje');
    } else {
      if (mounted) {
        setState(() => _estaCargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo aceptar la oferta.")),
        );
      }
    }
  }

  void _cancelarViaje() async {
    // Aquí implementas tu lógica de borrado y vuelves a la pantalla anterior
    Navigator.pushReplacementNamed(context, '/viaje');
  }
}