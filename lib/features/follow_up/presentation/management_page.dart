import 'package:flutter/material.dart';

import '../../reports/domain/report.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../submissions/domain/device_adapters.dart';
import '../../submissions/domain/review_record.dart';
import '../../submissions/domain/session_repository.dart';
import '../../submissions/domain/submission_repository.dart';
import '../../submissions/presentation/flow_widgets.dart';
import '../domain/follow_up.dart';
import '../domain/follow_up_repository.dart';
import 'follow_up_page.dart';

class ManagementFormPage extends StatefulWidget {
  const ManagementFormPage({
    required this.draft,
    required this.repository,
    required this.session,
    required this.photos,
    super.key,
  });
  final ManagementDraft draft;
  final FollowUpRepository repository;
  final SessionRepository session;
  final PhotoAdapter photos;
  @override
  State<ManagementFormPage> createState() => _ManagementFormPageState();
}

class _ManagementFormPageState extends State<ManagementFormPage> {
  late ManagementDraft _draft = widget.draft;
  late final Map<String, TextEditingController> _fields = {
    'Destinatario ficticio': TextEditingController(
      text: _draft.publicSummary.recipient,
    ),
    'Acción realizada': TextEditingController(
      text: _draft.publicSummary.action,
    ),
    'Referencia (opcional)': TextEditingController(
      text: _draft.publicSummary.reference,
    ),
    'Resumen público': TextEditingController(
      text: _draft.publicSummary.summary,
    ),
    'Respuesta revisada (opcional)': TextEditingController(
      text: _draft.publicSummary.response,
    ),
    'Siguiente paso (opcional)': TextEditingController(
      text: _draft.publicSummary.nextStep,
    ),
    'Responsable interno': TextEditingController(text: _draft.responsible),
    'Notas internas': TextEditingController(text: _draft.notes),
  };
  bool _busy = false, _dirty = false, _canPop = false;
  String? _error;
  SendScenario _scenario = SendScenario.normal;
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _change([ManagementDraft? draft]) {
    setState(() {
      _draft =
          draft ??
          _draft.copyWith(
            publicSummary: _draft.publicSummary.copyWith(
              recipient: _fields['Destinatario ficticio']!.text,
              action: _fields['Acción realizada']!.text,
              reference: _fields['Referencia (opcional)']!.text,
              summary: _fields['Resumen público']!.text,
              response: _fields['Respuesta revisada (opcional)']!.text,
              nextStep: _fields['Siguiente paso (opcional)']!.text,
            ),
            responsible: _fields['Responsable interno']!.text,
            notes: _fields['Notas internas']!.text,
          );
      _dirty = true;
    });
    _save();
  }

  Future<void> _save() async {
    try {
      await widget.repository.saveManagementDraft(_draft);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se guardó el borrador. Conserva el formulario abierto y reintenta.',
        );
      }
    }
  }

  void _pop() {
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _exit() async {
    if (_busy) return;
    if (!_dirty || widget.session.current?.role != DemoRole.moderator) {
      _pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conservar la gestión'),
        scrollable: true,
        content: const Text(
          'Guarda el borrador, descártalo o continúa editando.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (choice == 'discard') {
        await widget.repository.discardManagementDraft(_draft.id);
      } else {
        await widget.repository.saveManagementDraft(_draft);
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

  Future<void> _date() async {
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 4));
    final local = _draft.publicSummary.occurredAt.toUtc().subtract(
      const Duration(hours: 4),
    );
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(local.year, local.month, local.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (selected != null && mounted) {
      _change(
        _draft.copyWith(
          publicSummary: _draft.publicSummary.copyWith(
            occurredAt: DateTime.utc(
              selected.year,
              selected.month,
              selected.day,
              4,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _photo() async {
    setState(() => _busy = true);
    try {
      final photo = await widget.photos.select(false);
      if (mounted) {
        _change(
          _draft.copyWith(
            publicSummary: _draft.publicSummary.copyWith(
              evidence: [..._draft.publicSummary.evidence, photo],
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se agregó el adjunto simulado. Reintenta.');
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
      await widget.repository.submitManagement(_draft, scenario: _scenario);
      if (mounted) _pop();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : e is ArgumentError
              ? e.message.toString()
              : 'No se envió la gestión. Reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    builder: (context, _) => PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: flowAppBar(
          context,
          'Registrar gestión',
          leading: IconButton(
            onPressed: _exit,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
          ),
        ),
        body: FlowBody(
          children: widget.session.current?.role != DemoRole.moderator
              ? [const Text('Disponible solo para moderación de demostración.')]
              : [
                  const DemoNotice(),
                  const Text(
                    'Usa entidades ficticias. Los adjuntos son etiquetas simuladas; no se contacta a ninguna institución ni se acredita recepción oficial.',
                  ),
                  Text(
                    'Contenido para revisión pública',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Fecha de gestión: ${boliviaDate(_draft.publicSummary.occurredAt)} · hora de Bolivia',
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _date,
                    child: const Text('Cambiar fecha de gestión'),
                  ),
                  for (final name in _fields.keys.take(6))
                    TextField(
                      key: ValueKey(name),
                      controller: _fields[name],
                      enabled: !_busy,
                      minLines: name == 'Resumen público' ? 3 : 1,
                      maxLines: 5,
                      decoration: InputDecoration(labelText: name),
                      onChanged: (_) => _change(),
                    ),
                  for (final photo in _draft.publicSummary.evidence)
                    ListTile(
                      title: Text(photo),
                      trailing: IconButton(
                        tooltip: 'Quitar evidencia pública',
                        onPressed: _busy
                            ? null
                            : () => _change(
                                _draft.copyWith(
                                  publicSummary: _draft.publicSummary.copyWith(
                                    evidence: [..._draft.publicSummary.evidence]
                                      ..remove(photo),
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  if (_draft.publicSummary.evidence.length <
                      widget.repository.maxManagementPhotos)
                    OutlinedButton(
                      onPressed: _busy ? null : _photo,
                      child: const Text('Agregar evidencia pública simulada'),
                    ),
                  Text(
                    'Información interna · nunca pública',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final name in _fields.keys.skip(6))
                    TextField(
                      key: ValueKey(name),
                      controller: _fields[name],
                      enabled: !_busy,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(labelText: name),
                      onChanged: (_) => _change(),
                    ),
                  for (final document in _draft.privateDocuments)
                    ListTile(
                      title: Text(document),
                      trailing: IconButton(
                        tooltip: 'Quitar documento interno',
                        onPressed: _busy
                            ? null
                            : () => _change(
                                _draft.copyWith(
                                  privateDocuments: [..._draft.privateDocuments]
                                    ..remove(document),
                                ),
                              ),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _change(
                            _draft.copyWith(
                              privateDocuments: [
                                ..._draft.privateDocuments,
                                'Documento interno ficticio ${_draft.privateDocuments.length + 1}',
                              ],
                            ),
                          ),
                    child: const Text('Agregar documento interno simulado'),
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
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _scenario = value!),
                  ),
                  if (_error != null) FlowError(_error!),
                  const Text(
                    'El envío queda pendiente. El resumen y la evidencia pública requieren aprobación. Una respuesta o trabajo anunciado no cambia el estado del problema.',
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _send,
                    child: Text(
                      _busy ? 'Guardando…' : 'Enviar gestión a revisión',
                    ),
                  ),
                ],
        ),
      ),
    ),
  );
}

class ManagementReviewPage extends StatefulWidget {
  const ManagementReviewPage({
    required this.entryId,
    required this.reportId,
    required this.repository,
    required this.session,
    super.key,
  });
  final String entryId, reportId;
  final FollowUpRepository repository;
  final SessionRepository session;
  @override
  State<ManagementReviewPage> createState() => _ManagementReviewPageState();
}

class _ManagementReviewPageState extends State<ManagementReviewPage> {
  bool _busy = false;
  String? _error;
  Future<void> _review(ReviewStatus status) async {
    final reason = await askWorkflowReason(context, reviewLabel(status));
    if (reason == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.reviewManagement(widget.entryId, status, reason);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se guardó la decisión. Revisa la sesión y el estado de la gestión antes de reintentar.',
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
      final entries = widget.session.current?.role == DemoRole.moderator
          ? widget.repository.managementEntries(widget.reportId)
          : <ManagementEntry>[];
      final selected = entries.where((e) => e.id == widget.entryId).firstOrNull;
      if (selected == null) {
        return Scaffold(
          appBar: flowAppBar(context, 'Revisar gestión'),
          body: const FlowBody(
            children: [Text('Gestión no disponible para esta sesión.')],
          ),
        );
      }
      final versions = entries
          .where((e) => e.draft.group == selected.draft.group)
          .toList();
      final approved = versions
          .where((e) => e.status == ReviewStatus.approved)
          .lastOrNull;
      return Scaffold(
        appBar: flowAppBar(context, 'Revisar gestión'),
        body: FlowBody(
          maxWidth: 1120,
          children: [
            const DemoNotice(),
            Text(
              reviewLabel(selected.status),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Enviada: ${boliviaDate(selected.sentAt)} · hora de Bolivia'),
            Text(
              'Versión pública conservada',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              approved?.draft.publicSummary.publicText ??
                  'Sin gestión pública aprobada.',
            ),
            Text(
              'Propuesta para publicación',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Fecha de gestión: ${boliviaDate(selected.draft.publicSummary.occurredAt)}',
            ),
            Text(selected.draft.publicSummary.publicText),
            Text(
              'Solo equipo · no se publica',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Responsable: ${selected.draft.responsible}\nNotas: ${selected.draft.notes}\nDocumentos internos: ${selected.draft.privateDocuments.join('\n')}',
            ),
            if (_error != null) FlowError(_error!),
            if (selected.status == ReviewStatus.pending &&
                versions.last.id == selected.id) ...[
              const Text(
                'Aprobar solo publica los campos de la propuesta si el reporte es visible. No verifica la solución ni levanta ocultamientos.',
              ),
              FilledButton(
                onPressed: _busy ? null : () => _review(ReviewStatus.approved),
                child: const Text('Aprobar gestión'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _review(ReviewStatus.correctionRequested),
                child: const Text('Solicitar corrección de gestión'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _review(ReviewStatus.rejected),
                child: const Text('Rechazar gestión'),
              ),
            ],
            Text(
              'Historial interno de versiones',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final version in versions)
              Text(
                '${boliviaDate(version.sentAt)} · ${reviewLabel(version.status)}\n${version.draft.publicSummary.summary}${version.decision == null ? '' : '\n${version.decision!.actor} · ${boliviaDate(version.decision!.at)}\nMotivo interno: ${version.decision!.reason}'}',
              ),
          ],
        ),
      );
    },
  );
}
