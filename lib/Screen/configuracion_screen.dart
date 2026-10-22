import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contactos_provider.dart';
import '../theme.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  Future<void> _agregarContacto() async {
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Añadir contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              autofocus: true,
            ),
            const SizedBox(height: AppTheme.espacioS),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty && telCtrl.text.trim().isNotEmpty) {
                context.read<ContactosProvider>().agregar(
                  nombreCtrl.text.trim(),
                  telCtrl.text.trim(),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactos = context.watch<ContactosProvider>().contactos;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: AppTheme.paddingM,
        children: [
          Text('Contactos de emergencia', style: AppTheme.headlineSmall),
          const SizedBox(height: AppTheme.espacioS),
          if (contactos.isEmpty)
            Padding(
              padding: AppTheme.paddingVerticalM,
              child: Text('Sin contactos configurados', style: AppTheme.bodyMedium),
            )
          else
            ...contactos.map((c) => Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.espacioS),
                  child: ListTile(
                    leading: Icon(Icons.person, color: AppTheme.textoTerciario),
                    title: Text(c.nombre, style: AppTheme.bodyLarge),
                    subtitle: Text(c.telefono, style: AppTheme.monospace),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: AppTheme.textoTerciario),
                      onPressed: () => context.read<ContactosProvider>().eliminar(c),
                    ),
                  ),
                )),
          const SizedBox(height: AppTheme.espacioM),
          OutlinedButton.icon(
            onPressed: _agregarContacto,
            icon: const Icon(Icons.add),
            label: const Text('Añadir contacto'),
          ),
          const SizedBox(height: AppTheme.espacioXL),
          Text('Estado de conectividad', style: AppTheme.headlineSmall),
          const SizedBox(height: AppTheme.espacioS),
          Card(
            child: ListTile(
              leading: Icon(Icons.satellite_alt, color: AppTheme.textoTerciario),
              title: const Text('Efemérides satelitales'),
              subtitle: const Text('Al día'),
            ),
          ),
          const SizedBox(height: AppTheme.espacioS),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Sincronizar datos vía Wi-Fi'),
          ),
          const SizedBox(height: AppTheme.espacioS),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(backgroundColor: AppTheme.rojoCritico),
            child: const Text('Preparar conexión y sensores'),
          ),
        ],
      ),
    );
  }
}
