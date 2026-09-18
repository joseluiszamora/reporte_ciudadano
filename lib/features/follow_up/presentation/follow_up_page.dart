import 'package:flutter/material.dart';

import '../../reports/domain/report.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../submissions/domain/device_adapters.dart';
import '../../submissions/domain/session_repository.dart';
import '../../submissions/domain/review_record.dart';
import '../../submissions/presentation/flow_widgets.dart';
import '../domain/follow_up.dart';
import '../domain/follow_up_repository.dart';
import 'management_page.dart';

/// Captura el motivo antes de ejecutar una decisión; no envía al cerrar.
Future<String?> askWorkflowReason(
  BuildContext context,
  String title, {
  bool public = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _WorkflowReasonDialog(title: title, public: public),
);

class _WorkflowReasonDialog extends StatefulWidget {
  const _WorkflowReasonDialog({required this.title, required this.public});
  final String title;
  final bool public;
  @override
  State<_WorkflowReasonDialog> createState() => _WorkflowReasonDialogState();
}

class _WorkflowReasonDialogState extends State<_WorkflowReasonDialog> {
  final controller = TextEditingController();
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.public
              ? 'El motivo revisado será público junto al cambio. No incluyas datos personales. Verificar no equivale a certificación municipal.'
              : 'El motivo es interno. Solo se publican el resumen y los adjuntos expresamente revisados.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: widget.public
                ? 'Motivo público revisado'
                : 'Motivo interno',
          ),
        ),
        if (error != null) FlowError(error!),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (controller.text.trim().isEmpty) {
            setState(() => error = 'Escribe un motivo.');
            return;
          }
          Navigator.pop(context, controller.text.trim());
        },
        child: const Text('Confirmar decisión'),
      ),
    ],
  );
}

class FollowUpDashboard extends StatefulWidget {
  const FollowUpDashboard({
    required this.repository,
    required this.session,
    required this.photos,
    super.key,
  });
  final FollowUpRepository repository;
  final SessionRepository session;
  final PhotoAdapter photos;
  @override
  State<FollowUpDashboard> createState() => _FollowUpDashboardState();
}

class _FollowUpDashboardState extends State<FollowUpDashboard> {
  late Future<List<Report>> _reports;
  @override
  void initState() {
    super.initState();
    _load();
    widget.repository.addListener(_refresh);
    widget.session.addListener(_refresh);
  }

  void _load() {
    _reports = widget.session.current?.role == DemoRole.moderator
        ? widget.repository.reportsForFollowUp()
        : Future.value([]);
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_refresh);
    widget.session.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: flowAppBar(context, 'Gestiones y solución'),
    body: FutureBuilder<List<Report>>(
      future: _reports,
      builder: (context, snapshot) => FlowBody(
        children: [
          const DemoNotice(),
          if (widget.session.current?.role != DemoRole.moderator)
            const Text('Disponible solo para moderación de demostración.')
          else ...[
            const Text(
              'Registra gestiones y revisa soluciones en reportes aprobados. Todo se conserva en este dispositivo. Las entidades y los documentos deben ser ficticios.',
            ),
            if (snapshot.hasError) ...[
              const FlowError('No se pudo cargar el seguimiento.'),
              OutlinedButton(
                onPressed: _refresh,
                child: const Text('Reintentar'),
              ),
            ] else if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else if (snapshot.data!.isEmpty)
              const Text('No hay reportes aprobados.')
            else
              for (final report in snapshot.data!)
                Card(
                  child: ListTile(
                    title: Text(report.publicRevision!.title),
                    subtitle: Text(
                      '${report.tracking.label} · ${dispositionLabel(report.disposition)}${report.solutionReviewRequired ? '\nRevisión de seguimiento pendiente' : ''}',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => FollowUpPage(
                          reportId: report.id,
                          repository: widget.repository,
                          session: widget.session,
                          photos: widget.photos,
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

class FollowUpPage extends StatefulWidget {
  const FollowUpPage({
    required this.reportId,
    required this.repository,
    required this.session,
    required this.photos,
    super.key,
  });
  final String reportId;
  final FollowUpRepository repository;
  final SessionRepository session;
  final PhotoAdapter photos;
  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  late Future<Report?> _report;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    widget.repository.addListener(_refresh);
    widget.session.addListener(_refresh);
  }

  void _load() {
    _report = widget.session.current?.role == DemoRole.moderator
        ? widget.repository.reportForFollowUp(widget.reportId)
        : Future.value(null);
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_refresh);
    widget.session.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _decide(
    String label,
    Future<void> Function(String) action,
  ) async {
    final reason = await askWorkflowReason(context, label, public: true);
    if (reason == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(reason);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'No se guardó la decisión. Reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit({ManagementDraft? draft, String? previousId}) async {
    try {
      final value =
          draft ??
          await widget.repository.createManagement(
            widget.reportId,
            previousId: previousId,
          );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => ManagementFormPage(
            draft: value,
            repository: widget.repository,
            session: widget.session,
            photos: widget.photos,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo abrir la gestión. Revisa la sesión y la versión vigente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: flowAppBar(context, 'Seguimiento del reporte'),
    body: FutureBuilder<Report?>(
      future: _report,
      builder: (context, snapshot) {
        if (widget.session.current?.role != DemoRole.moderator) {
          return const FlowBody(
            children: [
              Text('Disponible solo para moderación de demostración.'),
            ],
          );
        }
        if (snapshot.hasError) {
          return FlowBody(
            children: [
              const FlowError('No se pudo cargar el reporte.'),
              OutlinedButton(
                onPressed: _refresh,
                child: const Text('Reintentar'),
              ),
            ],
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final report = snapshot.data;
        if (report == null) {
          return const FlowBody(children: [Text('Reporte no disponible.')]);
        }
        final record = widget.repository.resolutionForReview(widget.reportId);
        final evidence = widget.repository.solutionEvidenceForReview(
          widget.reportId,
        );
        final entries = widget.repository.managementEntries(widget.reportId);
        final latest = <String, ManagementEntry>{
          for (final entry in entries) entry.draft.group: entry,
        };
        return FlowBody(
          maxWidth: 1120,
          children: [
            const DemoNotice(),
            Text(
              report.publicRevision!.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '${report.tracking.label} · ${dispositionLabel(report.disposition)}',
            ),
            const Text(
              'Una gestión, respuesta o trabajo anunciado no resuelve el problema. Aprobar evidencia y verificar la solución son decisiones separadas.',
            ),
            if (_error != null) FlowError(_error!),
            Text(
              'Evidencia de solución',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (evidence.isEmpty)
              const Text(
                'Sin aportes de solución aprobados. La ciudadanía puede proponer una solución o aportar evidencia contradictoria desde el detalle público.',
              ),
            for (final item in evidence)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${item.draft.kind.label} · ${boliviaDate(item.draft.observedAt)}${item.id == record.candidateId ? '\nPropuesta de referencia' : ''}${record.reviewIds.contains(item.id) ? '\nRevisión pendiente' : ''}\n${item.draft.body}\n${item.draft.photos.isEmpty ? 'Sin adjuntos' : item.draft.photos.join('\n')}',
                  ),
                ),
              ),
            if (record.reviewIds.isNotEmpty) ...[
              const Text(
                'Revisa toda la evidencia antes de conservar el estado o reabrir. Los aportes contradictorios aprobados permanecen públicos.',
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _decide(
                        'Conservar estado tras revisión',
                        (reason) => widget.repository.keepResolution(
                          widget.reportId,
                          expectedVersion: record.version,
                          reason: reason,
                        ),
                      ),
                child: const Text('Conservar estado tras revisión'),
              ),
            ],
            if (report.tracking == TrackingStatus.solutionReported &&
                record.candidateId != null &&
                record.reviewIds.isEmpty)
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _decide(
                        'Verificar solución',
                        (reason) => widget.repository.verifySolution(
                          widget.reportId,
                          expectedVersion: record.version,
                          reason: reason,
                        ),
                      ),
                child: const Text('Verificar solución'),
              ),
            if (report.tracking == TrackingStatus.solutionReported ||
                report.tracking == TrackingStatus.verified)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _decide(
                        'Reabrir problema',
                        (reason) => widget.repository.reopenReport(
                          widget.reportId,
                          expectedVersion: record.version,
                          reason: reason,
                        ),
                      ),
                child: const Text('Reabrir problema'),
              ),
            Text('Gestiones', style: Theme.of(context).textTheme.titleLarge),
            FilledButton(
              onPressed: _busy ? null : () => _edit(),
              child: const Text('Registrar gestión'),
            ),
            for (final draft in widget.repository.managementDrafts(
              widget.reportId,
            ))
              OutlinedButton(
                onPressed: () => _edit(draft: draft),
                child: Text(
                  'Continuar borrador: ${draft.publicSummary.summary.isEmpty ? 'Gestión sin terminar' : draft.publicSummary.summary}',
                ),
              ),
            if (entries.isEmpty)
              const Text('Sin gestiones registradas en este dispositivo.'),
            for (final entry in latest.values)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        entry.draft.publicSummary.summary,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(reviewLabel(entry.status)),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => ManagementReviewPage(
                              entryId: entry.id,
                              reportId: widget.reportId,
                              repository: widget.repository,
                              session: widget.session,
                            ),
                          ),
                        ),
                        child: const Text('Revisar gestión e historial'),
                      ),
                      if (entry.status != ReviewStatus.pending)
                        OutlinedButton(
                          onPressed: () => _edit(previousId: entry.id),
                          child: Text(
                            entry.status == ReviewStatus.approved
                                ? 'Editar gestión'
                                : 'Corregir gestión',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Text(
              'Historial de seguimiento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (record.history.isEmpty)
              const Text('Sin decisiones locales de seguimiento.'),
            for (final event in record.history.reversed)
              Text(
                '${event.action} · ${boliviaDate(event.at)}\nMotivo público: ${event.reason}\nRevisor (interno): ${event.actor}',
              ),
          ],
        );
      },
    ),
  );
}
