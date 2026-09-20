import 'package:flutter/material.dart';

import '../../safety/domain/safety_repository.dart';
import '../../safety/presentation/safety_pages.dart';

import '../../follow_up/domain/follow_up_repository.dart';
import '../../follow_up/presentation/follow_up_page.dart';
import '../domain/device_adapters.dart';

import '../../community/domain/community_repository.dart';
import '../../community/presentation/contribution_review_page.dart';

import '../../reports/domain/report.dart';
import '../../reports/presentation/report_widgets.dart';
import '../domain/session_repository.dart';
import '../domain/submission.dart';
import '../domain/submission_repository.dart';
import '../domain/review_record.dart';
import 'flow_widgets.dart';

class ModerationPage extends StatefulWidget {
  const ModerationPage({
    required this.repository,
    required this.session,
    this.community,
    this.followUp,
    this.photos,
    this.safety,
    super.key,
  });
  final SubmissionRepository repository;
  final SessionRepository session;
  final CommunityRepository? community;
  final FollowUpRepository? followUp;
  final PhotoAdapter? photos;
  final SafetyRepository? safety;
  @override
  State<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends State<ModerationPage> {
  String _filter = 'Todos';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.repository, widget.session]),
    builder: (context, _) {
      final authorized = widget.session.current?.role == DemoRole.moderator;
      if (!authorized) {
        return Scaffold(
          appBar: flowAppBar(context, 'Moderación'),
          body: const FlowBody(
            children: [Text('Disponible solo en el escenario de moderación.')],
          ),
        );
      }
      final queue = widget.repository.reviewQueue
          .where(
            (s) =>
                _filter == 'Todos' ||
                (_filter == 'Nuevos'
                    ? s.draft.reportId == null
                    : s.draft.reportId != null),
          )
          .toList();
      final reports = widget.repository.moderationReports;
      Widget card(ReportSubmission item) => Card(
        child: ListTile(
          title: Text(item.draft.title),
          subtitle: Text(
            '${reviewLabel(item.status)} · ${item.draft.reportId == null ? 'Nuevo' : 'Edición'}\n${boliviaDate(item.sentAt)}\nDatos de demostración',
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ReviewPage(
                id: item.id,
                repository: widget.repository,
                session: widget.session,
              ),
            ),
          ),
        ),
      );
      return Scaffold(
        appBar: flowAppBar(context, 'Moderación · demo'),
        body: FlowBody(
          maxWidth: 1120,
          children: [
            const DemoNotice(),
            if (widget.safety != null || widget.repository is SafetyRepository)
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ComplaintsPage(
                      repository:
                          widget.safety ??
                          widget.repository as SafetyRepository,
                      session: widget.session,
                      moderation: true,
                    ),
                  ),
                ),
                child: const Text('Revisar denuncias de contenido'),
              ),
            if (widget.followUp != null ||
                widget.repository is FollowUpRepository)
              FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FollowUpDashboard(
                      repository:
                          widget.followUp ??
                          widget.repository as FollowUpRepository,
                      session: widget.session,
                      photos: widget.photos ?? DemoPhotoAdapter(),
                    ),
                  ),
                ),
                child: const Text('Gestiones y solución'),
              ),
            const Text(
              'Rol simulado. Este selector no acredita permisos de producción. Solo se revisan los envíos creados en este dispositivo; el catálogo inicial es de lectura.',
            ),
            Text(
              'Cola de revisión (${queue.length})',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Text(
              'Más antiguos primero · hora de Bolivia. Aprobar contenido no verifica una solución.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in ['Todos', 'Nuevos', 'Ediciones'])
                  ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
              ],
            ),
            if (queue.isEmpty)
              const Text('No hay envíos pendientes para este filtro.'),
            for (final item in queue) card(item),
            if (widget.community != null ||
                widget.repository is CommunityRepository)
              ContributionQueue(
                repository:
                    widget.community ??
                    widget.repository as CommunityRepository,
                session: widget.session,
              ),
            Text(
              'Reportes y disposición pública',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Abre un reporte para consultar decisiones, ocultarlo o marcarlo como duplicado. Los motivos son privados.',
            ),
            if (reports.isEmpty)
              const Text(
                'Envía un reporte desde una cuenta ciudadana de demostración para comenzar.',
              ),
            for (final item in reports) card(item),
          ],
        ),
      );
    },
  );
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    required this.id,
    required this.repository,
    required this.session,
    super.key,
  });
  final String id;
  final SubmissionRepository repository;
  final SessionRepository session;
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _busy = false;
  String? _error;

  Future<void> _decide(
    String label,
    Future<void> Function(String reason, String? principal) action, {
    List<Report>? principals,
  }) async {
    final result = await showDialog<({String reason, String? principal})>(
      context: context,
      builder: (_) => _DecisionDialog(label: label, principals: principals),
    );
    if (result == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(result.reason, result.principal);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se guardó la decisión. Comprueba que el envío siga vigente y que el principal esté visible; puedes reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _version(
    String heading,
    String title,
    String description,
    String category,
    String zone,
    String reference,
    String point,
    DateTime observedAt,
    List<String> photos,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(heading, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 16),
          Text(
            'Categoría: $category\nZona: $zone\nReferencia: $reference\nPunto: $point\nObservado: ${boliviaDate(observedAt)}',
          ),
          const SizedBox(height: 16),
          Text(
            photos.isEmpty
                ? 'Sin foto adjunta'
                : 'Adjuntos simulados\n${photos.join('\n')}',
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.repository, widget.session]),
    builder: (context, _) {
      final authorized = widget.session.current?.role == DemoRole.moderator;
      final item = authorized ? widget.repository.reviewItem(widget.id) : null;
      if (item == null) {
        return Scaffold(
          appBar: flowAppBar(context, 'Revisión'),
          body: const FlowBody(
            children: [Text('Envío no disponible para esta sesión.')],
          ),
        );
      }
      final draft = item.draft;
      final record = widget.repository.reviewRecord(item.reportId);
      final approved = widget.repository.approvedForReview(item.reportId);
      final current = record.latestRevisionId == item.id;
      final canReview =
          current && item.status == ReviewStatus.pending && !_busy;
      final proposal = _version(
        'Versión enviada',
        draft.title,
        draft.description,
        draft.category,
        draft.zone,
        draft.reference,
        '${draft.latitude}, ${draft.longitude}',
        draft.observedAt,
        draft.photos,
      );
      final prior = approved == null
          ? const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin versión pública aprobada'),
              ),
            )
          : _version(
              'Versión aprobada conservada',
              approved.publicRevision!.title,
              approved.publicRevision!.description,
              approved.category,
              approved.zone,
              approved.reference,
              '${approved.point?.latitude}, ${approved.point?.longitude}',
              approved.observedAt,
              approved.publicRevision!.demoAttachments,
            );
      return Scaffold(
        appBar: flowAppBar(context, 'Revisar reporte'),
        body: FlowBody(
          maxWidth: 1120,
          children: [
            const DemoNotice(),
            Text(
              '${reviewLabel(item.status)}\nAlias: ${item.alias}\nEnviado: ${boliviaDate(item.sentAt)}',
            ),
            Text(
              'Disposición: ${dispositionLabel(record.disposition)}${record.approvedRevisionId == null ? ' · aún sin publicación' : ''}',
            ),
            if (!current)
              const Text(
                'Esta es una revisión anterior. Abre la versión vigente desde la cola.',
              ),
            LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= 880 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.5
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: prior),
                        const SizedBox(width: 16),
                        Expanded(child: proposal),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [prior, proposal],
                    ),
            ),
            if (_error != null) FlowError(_error!),
            if (_busy) const Text('Guardando decisión…'),
            if (current && item.status == ReviewStatus.pending) ...[
              const Text(
                'La decisión requiere motivo. Aprobar reemplaza toda la versión y sus adjuntos; no levanta un ocultamiento ni verifica una solución.',
              ),
              FilledButton(
                onPressed: canReview
                    ? () => _decide(
                        'Aprobar versión',
                        (reason, _) => widget.repository.review(
                          item.id,
                          ReviewStatus.approved,
                          reason,
                        ),
                      )
                    : null,
                child: const Text('Aprobar versión'),
              ),
              OutlinedButton(
                onPressed: canReview
                    ? () => _decide(
                        'Solicitar corrección',
                        (reason, _) => widget.repository.review(
                          item.id,
                          ReviewStatus.correctionRequested,
                          reason,
                        ),
                      )
                    : null,
                child: const Text('Solicitar corrección'),
              ),
              OutlinedButton(
                onPressed: canReview
                    ? () => _decide(
                        'Rechazar versión',
                        (reason, _) => widget.repository.review(
                          item.id,
                          ReviewStatus.rejected,
                          reason,
                        ),
                      )
                    : null,
                child: const Text('Rechazar versión'),
              ),
            ],
            if (current) ...[
              Text(
                'Visibilidad',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Ocultar retira el contenido de todas las consultas públicas. Rechazar una edición conserva la versión aprobada anterior. Los duplicados no fusionan aportes.',
              ),
              if (record.disposition != PublicDisposition.hidden)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _decide(
                          'Ocultar reporte',
                          (reason, _) => widget.repository.setDisposition(
                            item.reportId,
                            PublicDisposition.hidden,
                            reason,
                          ),
                        ),
                  child: const Text('Ocultar reporte'),
                ),
              if (record.disposition != PublicDisposition.visible)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _decide(
                          'Restaurar disposición visible',
                          (reason, _) => widget.repository.setDisposition(
                            item.reportId,
                            PublicDisposition.visible,
                            reason,
                          ),
                        ),
                  child: const Text('Restaurar disposición visible'),
                ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _decide(
                        'Marcar duplicado',
                        (reason, principal) => widget.repository.setDisposition(
                          item.reportId,
                          PublicDisposition.duplicate,
                          reason,
                          duplicateOf: principal,
                        ),
                        principals: widget.repository.publishedReports
                            .where((r) => r.id != item.reportId)
                            .toList(),
                      ),
                child: const Text('Marcar duplicado'),
              ),
            ],
            Text(
              'Historial privado de moderación',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (record.history.isEmpty) const Text('Aún no hay decisiones.'),
            for (final event in record.history.reversed)
              Text(
                '${event.action} · ${boliviaDate(event.at)}\n${event.actor}\nMotivo: ${event.reason}',
              ),
          ],
        ),
      );
    },
  );
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({required this.label, this.principals});
  final String label;
  final List<Report>? principals;
  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _reason = TextEditingController();
  String? _principal;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.label),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Decisión local de demostración. Confirma la acción y explica el motivo; quedará registrada con fecha y revisor.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _reason,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Motivo de la decisión'),
        ),
        if (widget.principals != null) ...[
          const SizedBox(height: 16),
          const Text(
            'Principal aprobado y visible (envíos de este dispositivo):',
          ),
          if (widget.principals!.isEmpty)
            const Text(
              'No hay otro reporte público elegible. Cancela y aprueba primero otro reporte.',
            ),
          for (final report in widget.principals!)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(report.publicRevision!.title),
              subtitle: Text(
                _principal == report.id
                    ? 'Seleccionado · Datos de demostración'
                    : 'Datos de demostración',
              ),
              leading: Icon(
                _principal == report.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              onTap: () => setState(() => _principal = report.id),
            ),
        ],
        if (_error != null) FlowError(_error!),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_reason.text.trim().isEmpty ||
              (widget.principals != null && _principal == null)) {
            setState(
              () => _error = 'Escribe un motivo y, si corresponde, selecciona el principal.',
            );
            return;
          }
          Navigator.pop(context, (
            reason: _reason.text.trim(),
            principal: _principal,
          ));
        },
        child: const Text('Confirmar decisión'),
      ),
    ],
  );
}
