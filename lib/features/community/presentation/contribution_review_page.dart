import 'package:flutter/material.dart';

import '../../reports/domain/report.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../submissions/domain/session_repository.dart';
import '../../submissions/domain/review_record.dart';
import '../../submissions/presentation/flow_widgets.dart';
import '../domain/community.dart';
import '../domain/community_repository.dart';

class ContributionQueue extends StatelessWidget {
  const ContributionQueue({
    required this.repository,
    required this.session,
    super.key,
  });
  final CommunityRepository repository;
  final SessionRepository session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) {
      if (session.current?.role != DemoRole.moderator) {
        return const SizedBox.shrink();
      }
      Widget tile(Contribution c) => Card(
        child: ListTile(
          title: Text('${c.draft.kind.label} · ${reviewLabel(c.status)}'),
          subtitle: Text(
            '${c.draft.body}\n${boliviaDate(c.sentAt)}\nDatos de demostración',
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ContributionReviewPage(
                id: c.id,
                repository: repository,
                session: session,
              ),
            ),
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Aportes pendientes (${repository.contributionQueue.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Más antiguos primero. Los comentarios no cuentan como confirmaciones. La evidencia contradictoria no reabre automáticamente una solución.',
          ),
          for (final item in repository.contributionQueue) tile(item),
          if (repository.contributionQueue.isEmpty)
            const Text('No hay aportes pendientes.'),
          if (repository.reviewedContributions.isNotEmpty)
            ExpansionTile(
              title: const Text('Historial de aportes revisados'),
              children: [
                for (final item in repository.reviewedContributions.reversed)
                  tile(item),
              ],
            ),
        ],
      );
    },
  );
}

class ContributionReviewPage extends StatefulWidget {
  const ContributionReviewPage({
    required this.id,
    required this.repository,
    required this.session,
    super.key,
  });
  final String id;
  final CommunityRepository repository;
  final SessionRepository session;
  @override
  State<ContributionReviewPage> createState() => _ContributionReviewPageState();
}

class _ContributionReviewPageState extends State<ContributionReviewPage> {
  final _reason = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _review(ReviewStatus status) async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el motivo de la decisión.');
      return;
    }
    final reason = _reason.text.trim();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${reviewLabel(status)} · confirmar'),
        scrollable: true,
        content: Text(
          'Motivo: $reason\nLa decisión se guardará con fecha y revisor. Aprobar no hace visible un reporte oculto ni verifica una solución.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar decisión'),
          ),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.reviewContribution(widget.id, status, reason);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se guardó la decisión. El aporte pudo cambiar; reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _content(Contribution item, String label) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          Text('${item.draft.kind.label} · ${item.alias}\n${item.draft.body}'),
          Text(
            'Observado: ${boliviaDate(item.draft.observedAt)}\nEnviado: ${boliviaDate(item.sentAt)}',
          ),
          Text(
            item.draft.photos.isEmpty
                ? 'Sin foto adjunta'
                : item.draft.photos.join('\n'),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.repository, widget.session]),
    builder: (context, _) {
      final item = widget.session.current?.role == DemoRole.moderator
          ? widget.repository.contributionForReview(widget.id)
          : null;
      final prior = item?.draft.previousId == null
          ? null
          : widget.repository.contributionForReview(item!.draft.previousId!);
      return Scaffold(
        appBar: flowAppBar(context, 'Revisar aporte'),
        body: item == null
            ? const FlowBody(
                children: [Text('Aporte no disponible para esta sesión.')],
              )
            : FlowBody(
                children: [
                  const DemoNotice(),
                  if (prior != null)
                    _content(
                      prior,
                      'Revisión anterior · ${reviewLabel(prior.status)}',
                    ),
                  _content(
                    item,
                    'Versión enviada · ${reviewLabel(item.status)}',
                  ),
                  const Text(
                    'El contenido aprobado solo aparece si el reporte es público. Se conservan los aportes contradictorios aprobados; verificar o reabrir una solución requiere una decisión en Gestiones y solución.',
                  ),
                  if (item.decision != null)
                    Text(
                      '${item.decision!.actor} · ${boliviaDate(item.decision!.at)}\nMotivo: ${item.decision!.reason}',
                    ),
                  if (_error != null) FlowError(_error!),
                  if (item.status == ReviewStatus.pending) ...[
                    TextField(
                      controller: _reason,
                      enabled: !_busy,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Motivo de revisión del aporte',
                      ),
                    ),
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _review(ReviewStatus.approved),
                      child: const Text('Aprobar aporte'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _review(ReviewStatus.correctionRequested),
                      child: const Text('Solicitar corrección del aporte'),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _review(ReviewStatus.rejected),
                      child: const Text('Rechazar aporte'),
                    ),
                  ],
                ],
              ),
      );
    },
  );
}
