import 'package:flutter/material.dart';

Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String etiquetaConfirmar = 'Confirmar',
  String etiquetaCancelar = 'Cancelar',
  bool destructivo = true,
}) async {
  final theme = Theme.of(context);
  final resultado = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(etiquetaCancelar),
          ),
          FilledButton(
            style: destructivo
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(etiquetaConfirmar),
          ),
        ],
      );
    },
  );
  return resultado ?? false;
}
