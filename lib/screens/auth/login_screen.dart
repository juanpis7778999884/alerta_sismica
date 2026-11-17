import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/logo_alerta.dart';
import 'recuperar_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _recordar = true;
  bool _verPassword = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    try {
      await context.read<AuthProvider>().iniciarSesion(
        email: _emailController.text,
        password: _passwordController.text,
        recordarSesion: _recordar,
      );
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo iniciar sesión. Inténtalo de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.espacioL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LogoAlerta(mostrarTexto: false, tamano: 64),
                      const SizedBox(height: AppTheme.espacioL),
                      Text(
                        'Bienvenido de nuevo',
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: AppTheme.espacioS),
                      Text(
                        'Accede para monitorear los sismos recientes y tener tus '
                        'contactos de emergencia siempre a mano.',
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
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        enabled: !auth.operando,
                        onFieldSubmitted: (_) => _entrar(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
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
                        validator: (valor) {
                          if ((valor ?? '').isEmpty) {
                            return 'Escribe tu contraseña.';
                          }
                          return null;
                        },
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
                        onPressed: auth.operando ? null : _entrar,
                        icon: auth.operando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(
                          auth.operando ? 'Ingresando…' : 'Iniciar sesión',
                        ),
                      ),
                      const SizedBox(height: AppTheme.espacioS),
                      TextButton(
                        onPressed: auth.operando
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RecuperarScreen(),
                                ),
                              ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                      const SizedBox(height: AppTheme.espacioL),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Cuenta local protegida con contraseña cifrada.',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
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
