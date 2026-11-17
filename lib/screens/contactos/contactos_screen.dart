import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../providers/contactos_provider.dart';
import '../../theme.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/confirmar_dialog.dart';
import '../../widgets/estado_vacio.dart';
import 'contacto_form_screen.dart';

class ContactosScreen extends StatelessWidget {
  const ContactosScreen({super.key});

  Future<void> _agregar(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<bool>(builder: (_) => const ContactoFormScreen()));
  }

  Future<void> _editar(BuildContext context, String id) async {
    final contacto = context.read<ContactosProvider>().porId(id);
    if (contacto == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => ContactoFormScreen(contacto: contacto),
      ),
    );
  }

  Future<void> _eliminar(BuildContext context, String id, String nombre) async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Eliminar contacto',
      mensaje: '¿Eliminar a $nombre de tus contactos de emergencia?',
      etiquetaConfirmar: 'Eliminar',
    );
    if (!confirmado || !context.mounted) return;
    try {
      await context.read<ContactosProvider>().eliminar(id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Contacto eliminado.')));
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactos = context.watch<ContactosProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contactos de emergencia'),
        actions: [
          IconButton(
            onPressed: () => _agregar(context),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Agregar contacto',
          ),
        ],
      ),
      floatingActionButton: contactos.hayContactos
          ? FloatingActionButton(
              onPressed: () => _agregar(context),
              tooltip: 'Agregar contacto',
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => context.read<ContactosProvider>().recargar(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            AvisoBanner(
              titulo: 'Cómo se envían los avisos',
              mensaje:
                  'Los contactos marcados con estrella reciben el SOS. Si no '
                  'marcas ninguno, se usan todos. La app abre el SMS o WhatsApp: '
                  'la entrega no se confirma automáticamente.',
              nivel: NivelAviso.info,
            ),
            if (contactos.error != null) ...[
              const SizedBox(height: 8),
              AvisoBanner(
                mensaje: contactos.error!,
                nivel: NivelAviso.error,
                onCerrar: () =>
                    context.read<ContactosProvider>().limpiarError(),
              ),
            ],
            const SizedBox(height: 12),
            if (contactos.cargando && !contactos.hayContactos)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!contactos.hayContactos)
              SizedBox(
                height: 420,
                child: EstadoVacio(
                  icono: Icons.contacts_rounded,
                  titulo: 'Sin contactos todavía',
                  mensaje:
                      'Agrega al menos un familiar o amigo de confianza para '
                      'preparar el aviso SOS. Se guardará solo en este dispositivo.',
                  etiquetaAccion: 'Agregar contacto',
                  onAccion: () => _agregar(context),
                ),
              )
            else ...[
              Row(
                children: [
                  Text(
                    '${contactos.total} contacto(s)',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (contactos.prioritarios.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.star_rounded, size: 15),
                      label: Text(
                        '${contactos.prioritarios.length} prioritario(s)',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final contacto in contactos.contactos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _editar(context, contacto.id),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: contacto.prioritario
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                              foregroundColor: contacto.prioritario
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurface,
                              child: Text(
                                contacto.iniciales,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contacto.nombre,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    contacto.telefonoFormateado,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (contacto.prioritario)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(
                                        'Recibe el SOS prioritario',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () async {
                                try {
                                  await context
                                      .read<ContactosProvider>()
                                      .cambiarPrioridad(
                                        contacto.id,
                                        !contacto.prioritario,
                                      );
                                } on AppException catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error.message)),
                                  );
                                }
                              },
                              icon: Icon(
                                contacto.prioritario
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: contacto.prioritario
                                    ? AppTheme.ambarOscuro
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              tooltip: contacto.prioritario
                                  ? 'Quitar prioridad'
                                  : 'Marcar como prioritario',
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Opciones del contacto',
                              onSelected: (valor) {
                                if (valor == 'editar') {
                                  _editar(context, contacto.id);
                                } else if (valor == 'eliminar') {
                                  _eliminar(
                                    context,
                                    contacto.id,
                                    contacto.nombre,
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'editar',
                                  child: ListTile(
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Editar'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'eliminar',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline_rounded),
                                    title: Text('Eliminar'),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
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
            ],
          ],
        ),
      ),
    );
  }
}
