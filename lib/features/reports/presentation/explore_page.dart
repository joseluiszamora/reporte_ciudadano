import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';
import 'report_detail_page.dart';
import 'report_widgets.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({required this.repository, super.key});
  final ReportRepository repository;
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  late Future<List<Report>> _reports;
  final _search = TextEditingController();
  bool _includeVerified = false;
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
      final query = _search.text.trim().toLowerCase();
      final reports = (snapshot.data ?? [])
          .where(
            (report) =>
                (_includeVerified ||
                    report.tracking != TrackingStatus.verified) &&
                '${report.zone} ${report.reference}'.toLowerCase().contains(
                  query,
                ),
          )
          .toList();
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            key: const PageStorageKey('explore-list'),
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
                onChanged: (value) => setState(() => _includeVerified = value!),
              ),
              Text(
                '${reports.length} reportes · ${_includeVerified ? 'Todos' : 'Abiertos'}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Lista · Observaciones más recientes primero',
                style: TextStyle(fontSize: 14, color: AppColors.secondary),
              ),
              const SizedBox(height: AppSpace.medium),
              if (reports.isEmpty)
                ContentMessage(
                  title: 'Sin reportes para mostrar',
                  message: 'Prueba otra referencia o cambia los filtros.',
                  action: FilledButton(
                    onPressed: () => setState(() {
                      _search.clear();
                      _includeVerified = false;
                    }),
                    child: const Text('Limpiar búsqueda'),
                  ),
                ),
              for (final report in reports)
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
