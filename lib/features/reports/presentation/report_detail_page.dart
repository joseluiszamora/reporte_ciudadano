import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';
import 'report_widgets.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    required this.repository,
    required this.reportId,
    super.key,
  });
  final ReportRepository repository;
  final String reportId;
  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late Future<Report?> _report;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _report = widget.repository.getPublicReport(widget.reportId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
      title: const Text('Reporte · El Alto', maxLines: 2),
    ),
    body: FutureBuilder<Report?>(
      future: _report,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Cargando reporte',
            ),
          );
        }
        if (snapshot.hasError) {
          return SingleChildScrollView(
            child: ContentMessage(
              title: 'No pudimos cargar el reporte',
              message: 'Intenta nuevamente.',
              action: FilledButton(
                onPressed: () => setState(_load),
                child: const Text('Reintentar'),
              ),
            ),
          );
        }
        final report = snapshot.data;
        if (report == null) {
          return const ContentMessage(
            title: 'Reporte no disponible',
            message: 'No existe una versión pública visible de este reporte.',
          );
        }
        return SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const DemoNotice(),
                    const SizedBox(height: AppSpace.large),
                    Text(
                      report.category,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpace.small),
                    Text(
                      report.publicRevision!.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpace.medium),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(report.tracking),
                    ),
                    if (report.tracking == TrackingStatus.solutionReported)
                      const Text(
                        'Evidencia aprobada para publicación. Pendiente de verificar la solución.',
                      ),
                    if (report.tracking == TrackingStatus.verified)
                      const Text(
                        'Revisada por moderación en este escenario. No equivale a certificación municipal.',
                      ),
                    const SizedBox(height: AppSpace.large),
                    Text(report.publicRevision!.description),
                    const SizedBox(height: AppSpace.large),
                    _section(
                      context,
                      'Ubicación',
                      '${report.zone} · El Alto\n${report.reference}\n'
                          'Referencia ficticia. Sin mapa ni validación territorial en esta entrega.',
                    ),
                    _section(context, 'Evidencia', 'Sin foto adjunta'),
                    _section(
                      context,
                      'Observación y autoría',
                      'Autor: ${report.authorAlias}\n'
                          'Observado: ${boliviaDate(report.observedAt)}\n'
                          'Enviado: ${boliviaDate(report.submittedAt)}\n'
                          'Publicado: ${report.publishedAt == null ? 'Sin fecha' : boliviaDate(report.publishedAt!)}\n'
                          'Hora de Bolivia · America/La_Paz\n'
                          '${report.confirmations} observadores independientes (simulados)',
                    ),
                    _events(
                      context,
                      'Gestiones',
                      report.management,
                      'Sin gestiones registradas.',
                    ),
                    _events(
                      context,
                      'Actualizaciones',
                      report.updates,
                      'Sin actualizaciones aprobadas.',
                    ),
                    _events(
                      context,
                      'Comentarios',
                      report.comments,
                      'Sin comentarios aprobados.',
                    ),
                    _events(
                      context,
                      'Historial',
                      report.history,
                      'Sin eventos públicos.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _section(BuildContext context, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.large),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpace.small),
        Text(text),
      ],
    ),
  );

  Widget _events(
    BuildContext context,
    String title,
    List<PublicEvent> events,
    String empty,
  ) => _section(
    context,
    title,
    events.isEmpty
        ? empty
        : events.map((e) => '${boliviaDate(e.date)}\n${e.text}').join('\n\n'),
  );
}
