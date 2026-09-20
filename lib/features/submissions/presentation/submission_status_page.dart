import 'package:flutter/material.dart';

import '../../safety/domain/safety_repository.dart';
import '../../safety/presentation/safety_pages.dart';

import '../../reports/domain/report.dart';
import '../../reports/presentation/report_widgets.dart';
import '../domain/session_repository.dart';
import '../domain/submission.dart';
import '../domain/submission_repository.dart';
import '../domain/review_record.dart';
import 'flow_widgets.dart';

class SubmissionStatusPage extends StatefulWidget {
  const SubmissionStatusPage({
    required this.id,
    required this.repository,
    required this.session,
    this.onRevise,
    this.safety,
    super.key,
  });
  final String id;
  final SubmissionRepository repository;
  final SessionRepository session;
  final SafetyRepository? safety;
  final Future<void> Function(ReportDraft draft)? onRevise;
  @override
  State<SubmissionStatusPage> createState() => _SubmissionStatusPageState();
}

class _SubmissionStatusPageState extends State<SubmissionStatusPage> {
  bool _busy = false;
  String? _error;
  Future<void> _revise() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.repository.startRevision(widget.id);
      if (mounted) await widget.onRevise!(draft);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No pudimos preparar la edición. Consulta el envío vigente desde Perfil y reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.repository, widget.session]),
    builder: (context, _) {
      final item = widget.repository.ownSubmission(widget.id);
      return Scaffold(
        appBar: flowAppBar(context, 'Estado de mi envío'),
        body: item == null
            ? const FlowBody(
                children: [Text('Envío no disponible para esta sesión.')],
              )
            : FlowBody(
                children: [
                  const DemoNotice(),
                  if (widget.safety != null ||
                      widget.repository is SafetyRepository)
                    AuthorshipPanel(
                      repository:
                          widget.safety ??
                          widget.repository as SafetyRepository,
                      session: widget.session,
                      reportId: item.reportId,
                    ),
                  Text(
                    item.draft.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    reviewLabel(item.status),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (widget.repository.publicNotice(item.reportId)
                      case final notice?)
                    Text(
                      'Disposición pública: ${dispositionLabel(notice.disposition)}',
                    ),
                  const Text(
                    'El autor y la moderación pueden consultar esta revisión. '
                    'Solo una versión aprobada y visible aparece en Explorar. Una edición pendiente conserva la versión pública anterior, incluidos sus adjuntos.',
                  ),
                  Text(
                    'Enviado: ${boliviaDate(item.sentAt)} · hora de Bolivia',
                  ),
                  const Text(
                    'Revisamos contenido de 08:00 a 20:00, hora de Bolivia',
                  ),
                  if (item.status == ReviewStatus.pending)
                    Text(moderationMessage(item.sentAt)),
                  Text(
                    'Alias al enviar: ${item.alias}\nCategoría: ${item.draft.category}',
                  ),
                  Text(item.draft.description),
                  Text('Observado: ${boliviaDate(item.draft.observedAt)}'),
                  Text(
                    'El Alto (declarado)\nPunto: ${item.draft.latitude}, ${item.draft.longitude}\n'
                    '${item.draft.zone}\n${item.draft.reference}',
                  ),
                  Text(
                    item.draft.photos.isEmpty
                        ? 'Sin foto adjunta'
                        : 'Adjuntos simulados de esta revisión\n${item.draft.photos.join('\n')}',
                  ),
                  const Text('Historial de revisión'),
                  for (final revision in widget.repository.ownVersions(
                    item.reportId,
                  )) ...[
                    Text(
                      '${boliviaDate(revision.sentAt)} · ${revision.draft.reportId == null ? 'Reporte' : 'Edición'} recibido en la simulación.',
                    ),
                    if (revision.decision == null)
                      const Text('Aún no hay una decisión de moderación.')
                    else
                      Text(
                        '${reviewLabel(revision.status)} · ${boliviaDate(revision.decision!.at)}\nMotivo: ${revision.decision!.reason}',
                      ),
                  ],
                  if (item.status == ReviewStatus.rejected)
                    const Text(
                      'Puedes preparar una versión para solicitar revisión en esta simulación. No se garantiza la aprobación; el canal del piloto sigue pendiente.',
                    ),
                  if (_error != null) FlowError(_error!),
                  if (widget.onRevise != null &&
                      item.status != ReviewStatus.pending &&
                      widget.repository.ownSubmissions.any(
                        (s) => s.id == item.id,
                      ))
                    FilledButton(
                      onPressed: _busy ? null : _revise,
                      child: Text(
                        item.status == ReviewStatus.approved
                            ? 'Editar reporte'
                            : item.status == ReviewStatus.rejected
                            ? 'Preparar nueva revisión'
                            : 'Corregir y reenviar',
                      ),
                    ),
                ],
              ),
      );
    },
  );
}
