import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/codigo_recuperacion_dialog.dart';
import '../../widgets/logo_alerta.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key, this.esPrimerUso = false});

  final bool esPrimerUso;

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _recordar = true;
  bool _verPassword = false;
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      final resultado = await context.read<AuthProvider>().registrar(
        nombre: _nombreController.text,
        email: _emailController.text,
        password: _passwordController.text,
        recordarSesion: _recordar,
      );
      final contextoDialogo = navigatorKey.currentContext;
      if (contextoDialogo != null && contextoDialogo.mounted) {
        await mostrarCodigoRecuperacion(
          contextoDialogo,
          resultado.codigoRecuperacion,
        );
      }
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'No se pudo crear la cuenta. Inténtalo de nuevo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.esPrimerUso
          ? null
          : AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.espacioL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.esPrimerUso) ...[
                        const LogoAlerta(mostrarTexto: false, tamano: 64),
                        const SizedBox(height: AppTheme.espacioL),
                        Text(
                          'Crea tu cuenta local',
                          style: theme.textTheme.displaySmall,
                        ),
                        const SizedBox(height: AppTheme.espacioS),
                        Text(
                          'Tus datos de acceso se guardan solo en este dispositivo. '
                          'Al terminar recibirás un código para recuperar la contraseña.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppTheme.espacioL),
                      ],
                      if (_error != null) ...[
                        AvisoBanner(
                          mensaje: _error!,
                          nivel: NivelAviso.error,
                          onCerrar: () => setState(() => _error = null),
                        ),
                        const SizedBox(height: AppTheme.espacioM),
                      ],
                      TextFormField(
                        controller: _nombreController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        enabled: !auth.operando,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                          hintText: 'Nombre y apellido',
                        ),
                        validator: Validators.nombreUsuario,
                      ),
                      const SizedBox(height: AppTheme.espacioM),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        enabled: !auth.operando,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                          hintText: 'tu@correo.com',
                        ),
                        validator: Validators.email,
                      ),
                      const SizedBox(height: AppTheme.espacioM),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_verPassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        enabled: !auth.operando,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          helperText: 'Mínimo 8 caracteres, con al menos una letra y un número.',
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _verPassword = !_verPassword),
                            icon: Icon(
                              _verPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            tooltip: _verPassword
                                ? 'Ocultar contraseña'
                                : 'Mostrar contraseña',
                          ),
                        ),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: AppTheme.espacioM),
                      TextFormField(
                        controller: _confirmarController,
                        obscureText: !_verPassword,
                        textInputAction: TextInputAction.done,
                        enabled: !auth.operando,
                        onFieldSubmitted: (_) => _registrar(),
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: Icon(Icons.lock_reset_rounded),
                        ),
                        validator: (valor) => Validators.confirmarPassword(
                          valor,
                          _passwordController.text,
                        ),
                      ),
                      const SizedBox(height: AppTheme.espacioS),
                      SwitchListTile(
                        value: _recordar,
                        onChanged: auth.operando
                            ? null
                            : (valor) => setState(() => _recordar = valor),
                        title: const Text('Mantener sesión iniciada'),
                        subtitle: const Text('La sesión vence a los 30 días.'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: AppTheme.espacioS),
                      FilledButton.icon(
                        onPressed: auth.operando ? null : _registrar,
                        icon: auth.operando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(
                          auth.operando
                              ? 'Creando cuenta…'
                              : 'Crear cuenta local',
                        ),
                      ),
                      const SizedBox(height: AppTheme.espacioM),
                      Text(
                        'No se envía información a un servidor. La contraseña se '
                        'protege con derivación PBKDF2 y el código de recuperación '
                        'se muestra una sola vez.',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
