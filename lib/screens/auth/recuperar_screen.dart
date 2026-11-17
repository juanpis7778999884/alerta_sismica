import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/codigo_recuperacion_dialog.dart';

class RecuperarScreen extends StatefulWidget {
  const RecuperarScreen({super.key});

  @override
  State<RecuperarScreen> createState() => _RecuperarScreenState();
}

class _RecuperarScreenState extends State<RecuperarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _verPassword = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _restablecer() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      final nuevoCodigo = await context.read<AuthProvider>().recuperarPassword(
        email: _emailController.text,
        codigoRecuperacion: _codigoController.text,
        nuevoPassword: _passwordController.text,
      );
      final contextoDialogo = navigatorKey.currentContext;
      if (contextoDialogo != null && contextoDialogo.mounted) {
        await mostrarCodigoRecuperacion(
          contextoDialogo,
          nuevoCodigo,
          titulo: 'Nuevo código de recuperación',
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error =
            'No se pudo restablecer la contraseña. Inténtalo de nuevo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.espacioL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Usa tu código de recuperación',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppTheme.espacioS),
                    Text(
                      'El código se entregó al crear la cuenta y tiene 12 '
                      'caracteres. Al restablecer la contraseña se generará uno nuevo.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.espacioL),
                    if (_error != null) ...[
                      AvisoBanner(
                        mensaje: _error!,
                        nivel: NivelAviso.error,
                        onCerrar: () => setState(() => _error = null),
                      ),
                      const SizedBox(height: AppTheme.espacioM),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !auth.operando,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico de la cuenta',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: AppTheme.espacioM),
                    TextFormField(
                      controller: _codigoController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      enabled: !auth.operando,
                      decoration: const InputDecoration(
                        labelText: 'Código de recuperación',
                        prefixIcon: Icon(Icons.key_rounded),
                        hintText: 'XXXX-XXXX-XXXX',
                      ),
                      validator: Validators.codigoRecuperacion,
                    ),
                    const SizedBox(height: AppTheme.espacioM),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_verPassword,
                      textInputAction: TextInputAction.next,
                      enabled: !auth.operando,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        helperText:
                            'Mínimo 8 caracteres, con letras y números.',
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _verPassword = !_verPassword),
                          icon: Icon(
                            _verPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
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
                      onFieldSubmitted: (_) => _restablecer(),
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nueva contraseña',
                        prefixIcon: Icon(Icons.lock_reset_rounded),
                      ),
                      validator: (valor) => Validators.confirmarPassword(
                        valor,
                        _passwordController.text,
                      ),
                    ),
                    const SizedBox(height: AppTheme.espacioL),
                    FilledButton.icon(
                      onPressed: auth.operando ? null : _restablecer,
                      icon: auth.operando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.password_rounded),
                      label: Text(
                        auth.operando
                            ? 'Restableciendo…'
                            : 'Restablecer contraseña',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
