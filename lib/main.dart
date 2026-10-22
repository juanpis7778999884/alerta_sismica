import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/sismos_provider.dart';
import 'providers/contactos_provider.dart';
import 'providers/emergencia_provider.dart';
import 'screen/inicio_screen.dart';
import 'theme.dart';

void main() => runApp(const AlertaSismicaApp());

class AlertaSismicaApp extends StatelessWidget {
  const AlertaSismicaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SismosProvider()..cargarSismos()),
        ChangeNotifierProvider(create: (_) => ContactosProvider()),
        ChangeNotifierProvider(create: (_) => EmergenciaProvider()),
      ],
      child: MaterialApp(
        title: 'Alerta Sísmica',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const InicioScreen(),
      ),
    );
  }
}
