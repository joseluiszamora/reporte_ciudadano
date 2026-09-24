import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../sharing/domain/demo_report_link.dart';

import '../../community/presentation/community_pages.dart';
import '../../community/presentation/community_scope.dart';
import '../../submissions/domain/session_repository.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/explore_filter.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';
import 'report_widgets.dart';
import 'schematic_point_map.dart';

class ReportDetailPage extends StatefulWidget {
  const ReportDetailPage({
    required this.repository,
    required this.reportId,
    this.publicReading = false,
    super.key,
  });
  final ReportRepository repository;
  final String reportId;
  final bool publicReading;
  @override
  State<ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  late Future<Report?> _report;
  bool _visitScheduled = false;
  bool _copying = false;
  String? _copyMessage;
  int _readVersion = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visitScheduled || widget.publicReading) return;
    _visitScheduled = true;
    final scope = CommunityScope.maybeOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          scope == null ||
          scope.services.session.current?.role != DemoRole.citizen) {
        return;
      }
      try {
        await scope.services.community.visitFollowed(widget.reportId);
      } catch (_) {
        /* Una visita fallida conserva la marca de novedad. */
      }
    });
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
    if (mounted) {
      setState(() {
        _copyMessage = null;
        _load();
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReportDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.reportId != widget.reportId) {
      if (oldWidget.repository is Listenable) {
        (oldWidget.repository as Listenable).removeListener(_refresh);
      }
      if (widget.repository is Listenable) {
        (widget.repository as Listenable).addListener(_refresh);
      }
      _copyMessage = null;
      _load();
    }
  }

  @override
  void dispose() {
    if (widget.repository is Listenable) {
      (widget.repository as Listenable).removeListener(_refresh);
    }
    super.dispose();
  }

  void _load() {
    _readVersion++;
    _report = widget.repository.getPublicReport(widget.reportId);
  }

  Future<void> _copyLink() async {
    final version = _readVersion;
    setState(() {
      _copying = true;
      _copyMessage = null;
    });
    try {
      final current = await widget.repository.getPublicReport(widget.reportId);
      if (!mounted) return;
      if (version != _readVersion || current == null || !current.isPublic) {
        setState(_load);
        return;
      }
      await Clipboard.setData(
        ClipboardData(text: DemoReportLink.encode(widget.reportId)),
      );
      if (mounted && version == _readVersion) {
        setState(
          () => _copyMessage = 'Enlace de demostración copiado. Ábrelo en este prototipo; no es una página web.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _copyMessage = 'No se pudo copiar el enlace. Reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
      title: Text(
        widget.publicReading ? 'Lectura pública · demo' : 'Reporte · El Alto',
        maxLines: 2,
      ),
    ),
    body: SafeArea(
      child: FutureBuilder<Report?>(
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
          final report = snapshot.data?.isPublic == true ? snapshot.data : null;
          if (report == null) {
            final notice = widget.repository is ReportNoticeRepository
                ? (widget.repository as ReportNoticeRepository).publicNotice(
                    widget.reportId,
                  )
                : null;
            return SingleChildScrollView(
              child: ContentMessage(
                title: notice?.disposition == PublicDisposition.hidden
                    ? 'Reporte oculto'
                    : notice?.disposition == PublicDisposition.duplicate
                    ? 'Reporte duplicado'
                    : 'Reporte no disponible',
                message:
                    'No existe una versión pública visible de este reporte.',
                action: notice?.duplicateOf == null
                    ? null
                    : FilledButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ReportDetailPage(
                              repository: widget.repository,
                              reportId: notice!.duplicateOf!,
                              publicReading: widget.publicReading,
                            ),
                          ),
                        ),
                        child: const Text('Ver reporte principal'),
                      ),
              ),
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
                      if (report.solutionReviewRequired)
                        const Text(
                          'Hay evidencia aprobada que requiere revisar el seguimiento. Se conserva el estado actual hasta una decisión motivada.',
                        ),
                      const SizedBox(height: AppSpace.large),
                      Text(report.publicRevision!.description),
                      if (widget.publicReading) ...[
                        const SizedBox(height: AppSpace.medium),
                        const Text(
                          'Representación de lectura pública sin cuenta. Solo contenido aprobado y visible. No hay una página publicada ni indexación; este enlace funciona únicamente dentro del prototipo y con datos de este dispositivo.',
                        ),
                        const SizedBox(height: AppSpace.medium),
                        SelectableText(DemoReportLink.encode(report.id)),
                        const SizedBox(height: AppSpace.small),
                        FilledButton(
                          onPressed: _copying ? null : _copyLink,
                          child: Text(
                            _copying
                                ? 'Comprobando disponibilidad…'
                                : 'Copiar enlace de demostración',
                          ),
                        ),
                        if (_copyMessage != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(_copyMessage!),
                          ),
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ReportDetailPage(
                                repository: widget.repository,
                                reportId: report.id,
                              ),
                            ),
                          ),
                          child: const Text('Abrir en la aplicación'),
                        ),
                      ] else ...[
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ReportDetailPage(
                                repository: widget.repository,
                                reportId: report.id,
                                publicReading: true,
                              ),
                            ),
                          ),
                          child: const Text('Lectura pública y enlace · demo'),
                        ),
                        ParticipationPanel(report: report),
                      ],
                      const SizedBox(height: AppSpace.large),
                      _section(
                        context,
                        'Ubicación',
                        '${report.zone} · El Alto\n${report.reference}\n'
                            'Referencia ficticia. Sin validación territorial automática.',
                      ),
                      if (report.point?.isValid == true)
                        SchematicPointMap(
                          key: const Key('detail-minimap'),
                          area: ExploreArea(report.point!, span: .002),
                          point: report.point,
                          height: 170,
                        )
                      else
                        const Text('Sin punto para mostrar en el minimapa.'),
                      _section(
                        context,
                        'Evidencia',
                        report.publicRevision!.demoAttachments.isEmpty
                            ? 'Sin foto adjunta'
                            : 'Adjuntos simulados aprobados\n${report.publicRevision!.demoAttachments.join('\n')}',
                      ),
                      _section(
                        context,
                        'Observación y autoría',
                        'Autor: ${report.authorAlias}\n'
                            'Observado: ${boliviaDate(report.observedAt)}\n'
                            'Enviado: ${boliviaDate(report.submittedAt)}\n'
                            'Publicado: ${report.publishedAt == null ? 'Sin fecha' : boliviaDate(report.publishedAt!)}\n'
                            'Hora de Bolivia · America/La_Paz\n'
                            '${report.confirmations} ${report.confirmations == 1 ? 'observador independiente (simulado)' : 'observadores independientes (simulados)'}',
                      ),
                      if (report.lastCommunityObservedAt != null)
                        _section(
                          context,
                          'Última observación comunitaria',
                          '${boliviaDate(report.lastCommunityObservedAt!)} · hora de Bolivia\nSe muestra por separado del momento observado del reporte.',
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
