import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../models/contacto.dart';
import '../../providers/contactos_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/confirmar_dialog.dart';

class ContactoFormScreen extends StatefulWidget {
  const ContactoFormScreen({super.key, this.contacto});

  final Contacto? contacto;

  @override
  State<ContactoFormScreen> createState() => _ContactoFormScreenState();
}

class _ContactoFormScreenState extends State<ContactoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _telefonoController;
  late bool _prioritario;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.contacto != null;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.contacto?.nombre);
    _telefonoController = TextEditingController(
      text: widget.contacto?.telefono,
    );
    _prioritario = widget.contacto?.prioritario ?? false;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    try {
      final provider = context.read<ContactosProvider>();
      if (_esEdicion) {
        await provider.editar(
          id: widget.contacto!.id,
          nombre: _nombreController.text,
          telefono: _telefonoController.text,
          prioritario: _prioritario,
        );
      } else {
        await provider.agregar(
          nombre: _nombreController.text,
          telefono: _telefonoController.text,
          prioritario: _prioritario,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'No se pudo guardar el contacto. Inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final contacto = widget.contacto;
    if (contacto == null) return;
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Eliminar contacto',
      mensaje: '¿Eliminar a ${contacto.nombre} de tus contactos de emergencia?',
      etiquetaConfirmar: 'Eliminar',
    );
    if (!confirmado || !mounted) return;
    try {
      await context.read<ContactosProvider>().eliminar(contacto.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactos = context.watch<ContactosProvider>();
    final theme = Theme.of(context);
    final primerContacto = !_esEdicion && !contactos.hayContactos;

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar contacto' : 'Nuevo contacto'),
        actions: [
          if (_esEdicion)
            IconButton(
              onPressed: _guardando ? null : _eliminar,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Eliminar contacto',
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (_error != null) ...[
                AvisoBanner(
                  mensaje: _error!,
                  nivel: NivelAviso.error,
                  onCerrar: () => setState(() => _error = null),
                ),
                const SizedBox(height: AppTheme.espacioM),
              ],
              Text('Datos del contacto', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'El número debe incluir el código de país si tu contacto está '
                'en el extranjero.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.espacioM),
              TextFormField(
                controller: _nombreController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                enabled: !_guardando,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                  hintText: 'Ej. María Gómez',
                  counterText: '',
                ),
                validator: Validators.nombre,
              ),
              const SizedBox(height: AppTheme.espacioM),
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                enabled: !_guardando,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s().-]')),
                  LengthLimitingTextInputFormatter(24),
                ],
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '+57 300 000 0000',
                ),
                validator: Validators.telefono,
                onFieldSubmitted: (_) => _guardar(),
              ),
              const SizedBox(height: AppTheme.espacioS),
              SwitchListTile(
                value: primerContacto ? true : _prioritario,
                onChanged: primerContacto
                    ? null
                    : (valor) => setState(() => _prioritario = valor),
                secondary: const Icon(Icons.star_rounded),
                title: const Text('Contacto prioritario'),
                subtitle: Text(
                  primerContacto
                      ? 'El primer contacto se marca como prioritario automáticamente.'
                      : 'Recibe el SOS en el envío inicial.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppTheme.espacioL),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _guardando
                      ? 'Guardando…'
                      : _esEdicion
                      ? 'Guardar cambios'
                      : 'Agregar contacto',
                ),
              ),
              const SizedBox(height: AppTheme.espacioM),
              Text(
                'Este contacto se guarda solo en el dispositivo. No se envía a '
                'ningún servidor.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
