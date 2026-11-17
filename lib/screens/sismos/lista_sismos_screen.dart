import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatters.dart';
import '../../models/sismo.dart';
import '../../providers/configuracion_provider.dart';
import '../../providers/sismos_provider.dart';
import '../../providers/ubicacion_provider.dart';
import '../../widgets/aviso_banner.dart';
import '../../widgets/estado_vacio.dart';
import '../../widgets/sismo_tile.dart';
import '../configuracion/configuracion_screen.dart';
import 'detalle_sismo_screen.dart';

enum _OrdenSismos { recientes, magnitud, cercanos }

class ListaSismosScreen extends StatefulWidget {
  const ListaSismosScreen({super.key});

  @override
  State<ListaSismosScreen> createState() => _ListaSismosScreenState();
}

class _ListaSismosScreenState extends State<ListaSismosScreen> {
  final _busquedaController = TextEditingController();
  _OrdenSismos _orden = _OrdenSismos.recientes;
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _refrescar() async {
    await context.read<SismosProvider>().cargar(silencioso: true);
  }

  Future<void> _elegirCercanos() async {
    final ubicacion = context.read<UbicacionProvider>();
    if (ubicacion.ubicacion == null) {
      final resultado = await ubicacion.actualizar();
      if (!mounted) return;
      if (resultado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ubicacion.error ??
                  'No se pudo obtener tu ubicación. Revisa los permisos.',
            ),
          ),
        );
        return;
      }
    }
    setState(() => _orden = _OrdenSismos.cercanos);
  }

  List<SismoConDistancia> _ordenar(
    List<Sismo> visibles,
    double? latitud,
    double? longitud,
  ) {
    var elementos = visibles.map((sismo) {
      final distancia = latitud == null || longitud == null
          ? null
          : sismo.distanciaKmDesde(latitud, longitud);
      return SismoConDistancia(sismo: sismo, distanciaKm: distancia ?? 0);
    }).toList();

    if (_busqueda.trim().isNotEmpty) {
      final termino = _busqueda.trim().toLowerCase();
      elementos = elementos
          .where(
            (elemento) => elemento.sismo.lugar.toLowerCase().contains(termino),
          )
          .toList();
    }

    switch (_orden) {
      case _OrdenSismos.recientes:
        elementos.sort((a, b) => b.sismo.tiempo.compareTo(a.sismo.tiempo));
        break;
      case _OrdenSismos.magnitud:
        elementos.sort((a, b) => b.sismo.magnitud.compareTo(a.sismo.magnitud));
        break;
      case _OrdenSismos.cercanos:
        if (latitud == null || longitud == null) return const [];
        elementos =
            elementos.where((elemento) => elemento.distanciaKm <= 1500).toList()
              ..sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
        break;
    }
    return elementos;
  }

  @override
  Widget build(BuildContext context) {
    final sismos = context.watch<SismosProvider>();
    final ubicacion = context.watch<UbicacionProvider>();
    final configuracion = context.watch<ConfiguracionProvider>();
    final theme = Theme.of(context);
    final latitud = ubicacion.ubicacion?.latitud;
    final longitud = ubicacion.ubicacion?.longitud;
    final elementos = _ordenar(sismos.visibles, latitud, longitud);
    final sinUbicacion =
        _orden == _OrdenSismos.cercanos && ubicacion.ubicacion == null;

    return RefreshIndicator(
      onRefresh: _refrescar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Últimas 24 horas', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(
            sismos.actualizadoEn == null
                ? 'Consultando el servicio sísmico…'
                : 'Actualizado ${DateFormatters.hace(sismos.actualizadoEn!)} · '
                      '${sismos.todos.length} eventos publicados',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (sismos.cargando && sismos.hayDatos)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (sismos.usaCache)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AvisoBanner(
                titulo: 'Datos guardados',
                mensaje:
                    sismos.error ??
                    'Se muestran los últimos sismos descargados.',
                nivel: NivelAviso.advertencia,
                etiquetaAccion: 'Reintentar',
                onAccion: _refrescar,
              ),
            )
          else if (sismos.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AvisoBanner(
                mensaje: sismos.error!,
                nivel: NivelAviso.error,
                etiquetaAccion: 'Reintentar',
                onAccion: _refrescar,
              ),
            ),
          TextField(
            controller: _busquedaController,
            textInputAction: TextInputAction.search,
            onChanged: (valor) => setState(() => _busqueda = valor),
            decoration: InputDecoration(
              labelText: 'Buscar por lugar',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _busqueda.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _busquedaController.clear();
                        setState(() => _busqueda = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Limpiar búsqueda',
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Recientes'),
                selected: _orden == _OrdenSismos.recientes,
                onSelected: (_) =>
                    setState(() => _orden = _OrdenSismos.recientes),
              ),
              ChoiceChip(
                label: const Text('Mayor magnitud'),
                selected: _orden == _OrdenSismos.magnitud,
                onSelected: (_) =>
                    setState(() => _orden = _OrdenSismos.magnitud),
              ),
              ChoiceChip(
                label: const Text('Cercanos'),
                selected: _orden == _OrdenSismos.cercanos,
                onSelected: (_) => _elegirCercanos(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Mostrando M≥${configuracion.magnitudMinima.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ConfiguracionScreen(),
                  ),
                ),
                child: const Text('Cambiar filtro'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sinUbicacion)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AvisoBanner(
                mensaje: ubicacion.error ?? 'Activa la ubicación para ordenar los sismos por distancia.',
                nivel: NivelAviso.info,
                etiquetaAccion: 'Solicitar ubicación',
                onAccion: _elegirCercanos,
              ),
            ),
          if (elementos.isEmpty)
            SizedBox(
              height: 380,
              child: sismos.cargando
                  ? const Center(child: CircularProgressIndicator())
                  : EstadoVacio(
                      icono: sinUbicacion
                          ? Icons.location_off_rounded
                          : Icons.travel_explore_rounded,
                      titulo: sinUbicacion
                          ? 'Falta tu ubicación'
                          : 'Sin resultados',
                      mensaje: sinUbicacion
                          ? 'Concede el permiso de ubicación para ver los sismos '
                                'más cercanos.'
                          : _busqueda.isNotEmpty
                          ? 'No hay eventos que coincidan con “$_busqueda”.'
                          : 'No hay sismos que superen la magnitud mínima '
                                'configurada (M${configuracion.magnitudMinima.toStringAsFixed(1)}).',
                      etiquetaAccion: sinUbicacion
                          ? 'Solicitar ubicación'
                          : 'Actualizar',
                      onAccion: sinUbicacion ? _elegirCercanos : _refrescar,
                    ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${elementos.length} evento(s)',
                style: theme.textTheme.labelSmall,
              ),
            ),
            for (final elemento in elementos)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SismoTile(
                  sismo: elemento.sismo,
                  distanciaKm: latitud == null ? null : elemento.distanciaKm,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DetalleSismoScreen(sismo: elemento.sismo),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
