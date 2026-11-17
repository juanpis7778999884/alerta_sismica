import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

Future<void> mostrarCodigoRecuperacion(
  BuildContext context,
  String codigo, {
  String titulo = 'Guarda tu código de recuperación',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CodigoRecuperacionDialog(titulo: titulo, codigo: codigo),
  );
}

class _CodigoRecuperacionDialog extends StatefulWidget {
  const _CodigoRecuperacionDialog({required this.titulo, required this.codigo});

  final String titulo;
  final String codigo;

  @override
  State<_CodigoRecuperacionDialog> createState() =>
      _CodigoRecuperacionDialogState();
}

class _CodigoRecuperacionDialogState extends State<_CodigoRecuperacionDialog> {
  bool _copiado = false;

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: widget.codigo));
    if (!mounted) return;
    setState(() => _copiado = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.key_rounded, color: AppTheme.ambarOscuro),
        title: Text(widget.titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Este código solo se muestra una vez. Escríbelo en un lugar seguro: '
              'sin él no podrás restablecer tu contraseña local.',
            ),
            const SizedBox(height: AppTheme.espacioM),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radio),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: SelectableText(
                widget.codigo,
                textAlign: TextAlign.center,
                style: AppTheme.monospace.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.espacioM),
            OutlinedButton.icon(
              onPressed: _copiar,
              icon: Icon(
                _copiado ? Icons.check_rounded : Icons.copy_rounded,
                size: 18,
              ),
              label: Text(_copiado ? 'Copiado' : 'Copiar código'),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Ya lo guardé'),
          ),
        ],
      ),
    );
  }
}
