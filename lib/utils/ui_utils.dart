import 'package:flutter/material.dart';

class UIUtils {
  // Muestra el spinner de carga
  static void showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
    );
  }

  // Cierra cualquier diálogo abierto (como el spinner)
  static void dismissLoading(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // Muestra un SnackBar de error (también reutilizable)
  static void showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showSnackBar(BuildContext context, String msg,
      {bool isError = false}) {
    // Limpiamos snacks anteriores por si el usuario presiona muchas veces
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'Poppins', color: Colors.white),
        ),
        backgroundColor:
            isError ? Colors.red : const Color(0xFFF7931E), // Usamos tu naranja
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior
            .floating, // Hace que el snackbar "flote" sobre la UI
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
