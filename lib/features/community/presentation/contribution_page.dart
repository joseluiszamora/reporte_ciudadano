import 'package:flutter/material.dart';

import '../../reports/domain/report.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../submissions/domain/submission_repository.dart';
import '../../submissions/domain/review_record.dart';
import '../../submissions/presentation/flow_widgets.dart';
import '../domain/community.dart';
import 'community_scope.dart';

class ContributionPage extends StatefulWidget {
  const ContributionPage({required this.draft, super.key});
  final ContributionDraft draft;
  @override
  State<ContributionPage> createState() => _ContributionPageState();
}

class _ContributionPageState extends State<ContributionPage> {
  late ContributionDraft _draft = widget.draft;
  late final TextEditingController _body = TextEditingController(
    text: _draft.body,
  );
  bool _busy = false, _dirty = false, _canPop = false;
  String? _error;
  SendScenario _scenario = SendScenario.normal;
  Future<void> _photo() async {
    setState(() => _busy = true);
    try {
      final photo = await CommunityScope.of(context).services.photos
          .select(false);
      if (mounted) _change(_draft.copyWith(photos: [..._draft.photos, photo]));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo agregar el adjunto simulado. Reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await CommunityScope.of(context).services.community
          .saveContributionDraft(_draft);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar el aporte. Mantén abierto el formulario y reintenta.',
        );
      }
    }
  }

  void _change(ContributionDraft draft) {
    setState(() {
      _draft = draft;
      _dirty = true;
    });
    _save();
  }

  void _pop() {
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _exit() async {
    if (_busy) return;
    if (!_dirty) {
      _pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conservar el aporte'),
        scrollable: true,
        content: const Text(
          'Puedes guardar el borrador, descartarlo o seguir editando.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Guardar borrador'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'continue') return;
    setState(() => _busy = true);
    try {
      final repo = CommunityScope.of(context).services.community;
      if (choice == 'discard') {
        await repo.discardContributionDraft(_draft.id);
      } else {
        await repo.saveContributionDraft(_draft);
      }
      if (mounted) _pop();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se guardó el cambio. Reintenta antes de salir.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CommunityScope.of(context).services.community
          .sendContribution(_draft, scenario: _scenario);
      if (!mounted) return;
      _dirty = false;
      _pop();
      // El estado persistido y el motivo se consultan en Perfil → Mis aportes.
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Escribe un texto válido antes de enviar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = CommunityScope.of(context).services;
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: flowAppBar(
          context,
          'Aportar · revisión previa',
          leading: IconButton(
            onPressed: _exit,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
          ),
        ),
        body: FlowBody(
          children: [
            const DemoNotice(),
            const Text(
              'Documenta hechos urbanos sin datos personales. El texto, alias y adjuntos solo serán públicos después de la aprobación. Un comentario no confirma una observación.',
            ),
            DropdownButtonFormField<ContributionKind>(
              initialValue: _draft.kind,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tipo de aporte'),
              items: [
                for (final kind in ContributionKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged:
                  _busy ||
                      (_draft.previousId != null &&
                          (_draft.kind == ContributionKind.solution ||
                              _draft.kind == ContributionKind.contradiction))
                  ? null
                  : (kind) => _change(_draft.copyWith(kind: kind)),
            ),
            TextField(
              key: const Key('contribution-body'),
              controller: _body,
              enabled: !_busy,
              minLines: 3,
              maxLines: 8,
              maxLength: services.community.communityRules.textMax,
              decoration: const InputDecoration(
                labelText: 'Describe tu aporte',
              ),
              onChanged: (value) => _change(_draft.copyWith(body: value)),
            ),
            Text(
              'Observado: ${boliviaDate(_draft.observedAt)} · hora de Bolivia',
            ),
            for (final photo in _draft.photos)
              ListTile(
                title: Text(photo),
                trailing: IconButton(
                  tooltip: 'Quitar adjunto simulado',
                  onPressed: _busy
                      ? null
                      : () => _change(
                          _draft.copyWith(
                            photos: [..._draft.photos]..remove(photo),
                          ),
                        ),
                  icon: const Icon(Icons.close),
                ),
              ),
            if (_draft.photos.length <
                services.community.communityRules.maxPhotos)
              OutlinedButton(
                onPressed: _busy ? null : _photo,
                child: const Text('Agregar adjunto simulado'),
              ),
            const Text(
              'Los adjuntos son simulados. Una propuesta aprobada pasa a Solución reportada; verificarla exige otra decisión. La evidencia contradictoria aprobada abre una revisión y no reabre automáticamente el problema.',
            ),
            DropdownButtonFormField<SendScenario>(
              initialValue: _scenario,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Escenario de envío simulado',
              ),
              items: const [
                DropdownMenuItem(
                  value: SendScenario.normal,
                  child: Text('Envío normal'),
                ),
                DropdownMenuItem(
                  value: SendScenario.offline,
                  child: Text('Sin conexión'),
                ),
                DropdownMenuItem(
                  value: SendScenario.lostResponse,
                  child: Text('Respuesta perdida'),
                ),
              ],
              onChanged: _busy ? null : (v) => setState(() => _scenario = v!),
            ),
            if (_error != null) FlowError(_error!),
            const Text(
              'Revisamos contenido de 08:00 a 20:00, hora de Bolivia. Los envíos fuera de horario quedan en cola; no se garantiza un plazo.',
            ),
            FilledButton(
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Guardando…' : 'Enviar aporte a revisión'),
            ),
            const Text(
              'Consulta el resultado en Perfil → Mis aportes. Reintentar un envío conserva su identidad.',
            ),
          ],
        ),
      ),
    );
  }
}

class MyContributionsPage extends StatefulWidget {
  const MyContributionsPage({super.key});
  @override
  State<MyContributionsPage> createState() => _MyContributionsPageState();
}

class _MyContributionsPageState extends State<MyContributionsPage> {
  String? _error;
  Future<void> _edit(Contribution item) async {
    try {
      final draft = await CommunityScope.of(context).services.community
          .createContribution(item.draft.reportId, previousId: item.id);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ContributionPage(draft: draft),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se puede editar ahora: el reporte debe estar visible y el aporte no debe tener una revisión pendiente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = CommunityScope.of(context).services;
    return ListenableBuilder(
      listenable: Listenable.merge([services.community, services.session]),
      builder: (context, _) => Scaffold(
        appBar: flowAppBar(context, 'Mis aportes'),
        body: FlowBody(
          children: [
            const DemoNotice(),
            if (_error != null) FlowError(_error!),
            const Text('Borradores de aportes'),
            if (services.community.ownContributionDrafts.isEmpty)
              const Text('No hay borradores de aportes.'),
            for (final draft in services.community.ownContributionDrafts)
              Card(
                child: ListTile(
                  title: Text(
                    draft.body.isEmpty ? 'Aporte sin terminar' : draft.body,
                  ),
                  subtitle: const Text(
                    'Borrador privado · Datos de demostración',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ContributionPage(draft: draft),
                    ),
                  ),
                ),
              ),
            const Text('Envíos de aportes'),
            if (services.community.ownContributions.isEmpty)
              const Text('Aún no has enviado aportes.'),
            for (final item in services.community.ownContributions)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${item.draft.kind.label} · ${reviewLabel(item.status)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(item.draft.body),
                      if (item.draft.photos.isNotEmpty)
                        Text(item.draft.photos.join('\n')),
                      for (final revision
                          in services.community.ownContributionVersions(
                            item.draft.group,
                          ))
                        Text(
                          '${boliviaDate(revision.sentAt)} · ${reviewLabel(revision.status)}${revision.decision == null ? '' : '\nMotivo: ${revision.decision!.reason}'}',
                        ),
                      if (item.status != ReviewStatus.pending)
                        OutlinedButton(
                          onPressed: () => _edit(item),
                          child: Text(
                            item.status == ReviewStatus.approved
                                ? 'Editar aporte'
                                : 'Corregir aporte y reenviar',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
