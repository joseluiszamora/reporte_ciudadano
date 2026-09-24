import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/geo_point.dart';
import '../../submissions/domain/device_adapters.dart';
import '../domain/explore_filter.dart';
import 'demo_report_map.dart';
import 'explore_filters_page.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';
import 'report_detail_page.dart';
import 'report_widgets.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    required this.repository,
    this.location = const DemoLocationAdapter(),
    super.key,
  });
  final ReportRepository repository;
  final LocationAdapter location;
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late Future<List<Report>> _reports;
  final _search = TextEditingController();
  ExploreFilter _filter = const ExploreFilter();
  bool get _includeVerified =>
      _filter.statuses.contains(TrackingStatus.verified);
  bool _map = false;
  ExploreArea _viewport = const ExploreArea(GeoPoint(-16.5005, -68.1600));
  ExploreArea? _area;
  GeoPoint? _near;
  String? _locationMessage;
  List<String> _selected = [];

  Future<void> _filters() async {
    final result = await Navigator.push<ExploreFilter>(
      context,
      MaterialPageRoute(builder: (_) => ExploreFiltersPage(initial: _filter)),
    );
    if (result != null && mounted) {
      setState(() {
        _filter = result;
        _selected = [];
      });
    }
  }

  Future<void> _locate(bool deny) async {
    try {
      final point = await widget.location.request(simulateDenial: deny);
      if (!mounted) return;
      setState(() {
        _near = point;
        if (point != null) {
          _viewport = ExploreArea(point);
        }
        _locationMessage = point == null
            ? 'Ubicación rechazada. Puedes mover el mapa y buscar manualmente.'
            : 'Ubicación de demostración. Lista ordenada por cercanía.';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationMessage =
              'No se pudo obtener la ubicación. Puedes buscar manualmente.',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.repository is Listenable) {
      (widget.repository as Listenable).addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  void _load() {
    _reports = widget.repository.listPublicReports();
  }

  @override
  void dispose() {
    if (widget.repository is Listenable) {
      (widget.repository as Listenable).removeListener(_refresh);
    }
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Report>>(
    future: _reports,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: 'Cargando reportes'),
        );
      }
      if (snapshot.hasError) {
        return SingleChildScrollView(
          child: ContentMessage(
            title: 'No pudimos cargar los reportes',
            message: 'Puedes volver a intentarlo.',
            action: FilledButton(
              onPressed: () => setState(_load),
              child: const Text('Reintentar'),
            ),
          ),
        );
      }
      final reports = _filter.apply(
        snapshot.data ?? [],
        query: _search.text,
        area: _area,
        near: _near,
      );
      final cards = _map
          ? reports.where((r) => _selected.contains(r.id)).toList()
          : reports;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            key: PageStorageKey(_map ? 'explore-map' : 'explore-list'),
            padding: const EdgeInsets.all(AppSpace.medium),
            children: [
              const DemoNotice(),
              const SizedBox(height: AppSpace.large),
              Text(
                'Tu ciudad, con seguimiento',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpace.small),
              const Text(
                'Problemas persistentes de El Alto. Consulta sus avances y gestiones.',
              ),
              const SizedBox(height: AppSpace.large),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar zona o referencia',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: AppSpace.small),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Incluir soluciones verificadas'),
                value: _includeVerified,
                onChanged: (value) => setState(() {
                  final statuses = {..._filter.statuses};
                  value!
                      ? statuses.add(TrackingStatus.verified)
                      : statuses.remove(TrackingStatus.verified);
                  _filter = ExploreFilter(
                    categories: _filter.categories,
                    statuses: statuses,
                    from: _filter.from,
                    until: _filter.until,
                  );
                }),
              ),
              Text(
                '${reports.length} reportes · ${_filter.allStatuses
                    ? 'Todos'
                    : _filter.defaultOpen
                    ? 'Abiertos'
                    : 'Estados personalizados'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                _map
                    ? 'Mapa · Selecciona un marcador para ver sus reportes'
                    : _near == null
                    ? 'Lista · Observaciones más recientes primero'
                    : 'Lista · Más cercanos a la ubicación de demostración',
                style: TextStyle(fontSize: 14, color: AppColors.secondary),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _map = !_map),
                    icon: Icon(_map ? Icons.list : Icons.map_outlined),
                    label: Text(_map ? 'Ver lista' : 'Ver mapa'),
                  ),
                  TextButton.icon(
                    onPressed: _filters,
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filtros'),
                  ),
                ],
              ),
              if (_filter.categories.isNotEmpty ||
                  _filter.from != null ||
                  _filter.until != null ||
                  (!_filter.defaultOpen && !_filter.allStatuses))
                Text(
                  'Filtros activos: ${_filter.categories.isEmpty ? 'Todas las categorías' : _filter.categories.join(', ')} · '
                  '${_filter.statuses.map((s) => s.label).join(', ')}'
                  '${_filter.from == null ? '' : ' · Desde ${_filter.from!.day}/${_filter.from!.month}/${_filter.from!.year}'}'
                  '${_filter.until == null ? '' : ' · Hasta ${_filter.until!.day}/${_filter.until!.month}/${_filter.until!.year}'}',
                ),
              if (_area != null)
                TextButton(
                  onPressed: () => setState(() => _area = null),
                  child: const Text('Quitar filtro de esta zona'),
                ),
              if (_map) ...[
                DemoReportMap(
                  reports: reports,
                  area: _viewport,
                  onSelect: (ids) => setState(() => _selected = ids),
                  onAreaChanged: (area) => setState(() {
                    _viewport = area;
                    _selected = [];
                  }),
                ),
                FilledButton(
                  onPressed: () => setState(() {
                    _area = _viewport;
                    _selected = [];
                  }),
                  child: const Text('Buscar en esta zona'),
                ),
                const Text(
                  'Mover el mapa no cambia los filtros hasta buscar en esta zona.',
                ),
                if (reports.any((r) => r.point == null))
                  const Text(
                    'Hay reportes sin coordenadas; consúltalos en la lista.',
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _locate(false),
                      child: const Text('Usar ubicación simulada'),
                    ),
                    TextButton(
                      onPressed: () => _locate(true),
                      child: const Text('Ensayar GPS rechazado'),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _near = null;
                        _locationMessage = null;
                        _viewport = const ExploreArea(
                          GeoPoint(-16.5005, -68.1600),
                        );
                      }),
                      child: const Text('Volver al área inicial'),
                    ),
                  ],
                ),
                if (_locationMessage != null)
                  Semantics(liveRegion: true, child: Text(_locationMessage!)),
                Text(
                  cards.isEmpty
                      ? 'Selecciona un marcador para consultar sus reportes.'
                      : '${cards.length} reportes seleccionados',
                ),
              ],
              const SizedBox(height: AppSpace.medium),
              if (reports.isEmpty)
                ContentMessage(
                  title: 'Sin reportes para mostrar',
                  message: 'Prueba otra referencia o cambia los filtros.',
                  action: FilledButton(
                    onPressed: () => setState(() {
                      _search.clear();
                      _filter = const ExploreFilter();
                      _area = null;
                      _selected = [];
                    }),
                    child: const Text('Limpiar búsqueda'),
                  ),
                ),
              for (final report in cards)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.medium),
                  child: ReportCard(
                    report: report,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReportDetailPage(
                          repository: widget.repository,
                          reportId: report.id,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
