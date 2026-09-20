import 'package:flutter/material.dart';

import '../../community/presentation/community_scope.dart';
import '../../reports/presentation/report_detail_page.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../submissions/domain/session_repository.dart';
import '../../submissions/domain/submission_repository.dart';
import '../../submissions/presentation/flow_widgets.dart';
import '../domain/safety_repository.dart';

class AuthorshipPanel extends StatefulWidget {
  const AuthorshipPanel({
    required this.repository,
    required this.session,
    required this.reportId,
    super.key,
  });
  final SafetyRepository repository;
  final SessionRepository session;
  final String reportId;
  @override
  State<AuthorshipPanel> createState() => _AuthorshipPanelState();
}

class _AuthorshipPanelState extends State<AuthorshipPanel> {
  bool _busy = false;
  String? _error;
  Future<void> _withdraw() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirar autoría'),
        scrollable: true,
        content: const Text(
          'El reporte y tus aportes en él se conservarán con Autor anónimo. No se oculta el problema ni se elimina la cuenta o todo dato personal. Textos y fotos pueden requerir revisión adicional. El vínculo interno se conserva en esta demostración; la política del piloto está pendiente. Esta interfaz no permite deshacer el retiro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar retiro'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.withdrawAuthorship(widget.reportId);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'No se retiró la autoría. Revisa tu sesión y reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.repository, widget.session]),
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.repository.ownAuthorshipWithdrawn(widget.reportId))
          const Text(
            'Autoría retirada · el reporte permanece como Autor anónimo.',
          ),
        if (widget.repository.canWithdrawAuthorship(widget.reportId))
          OutlinedButton(
            onPressed: _busy ? null : _withdraw,
            child: const Text('Retirar autoría'),
          ),
        if (_error != null) FlowError(_error!),
      ],
    ),
  );
}

class ComplaintFormPage extends StatefulWidget {
  const ComplaintFormPage({
    required this.draft,
    required this.repository,
    required this.session,
    super.key,
  });
  final ContentComplaint draft;
  final SafetyRepository repository;
  final SessionRepository session;
  @override
  State<ComplaintFormPage> createState() => _ComplaintFormPageState();
}

class _ComplaintFormPageState extends State<ComplaintFormPage> {
  late ContentComplaint _draft = widget.draft;
  late final _details = TextEditingController(text: widget.draft.details);
  bool _busy = false, _sent = false, _dirty = false, _canPop = false;
  String? _error;
  SendScenario _scenario = SendScenario.normal;
  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _pop() {
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _exit() async {
    if (_busy) return;
    if (!_dirty || _sent) {
      _pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir de la denuncia'),
        scrollable: true,
        content: const Text(
          'El texto sin enviar no se guarda. Si un envío tuvo respuesta perdida, la denuncia recibida permanece en Mis denuncias de contenido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _pop();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.submitComplaint(_draft, scenario: _scenario);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : e is ArgumentError
              ? e.message.toString()
              : 'No se recibió la denuncia. Reintenta.',
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
          'Denunciar contenido',
          leading: IconButton(
            onPressed: _exit,
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: FlowBody(
          children: [
            const DemoNotice(),
            if (widget.session.current?.id != _draft.ownerId ||
                widget.session.current?.role != DemoRole.citizen)
              const Text('Formulario no disponible para esta sesión.')
            else if (_sent) ...[
              const Text('Denuncia recibida · pendiente de revisión'),
              const Text(
                'Recepción local de demostración. Solo tú y el equipo pueden consultarla. No cambia automáticamente la visibilidad ni envía un reclamo a autoridades. No se promete un plazo.',
              ),
              FilledButton(
                onPressed: _exit,
                child: const Text('Volver al reporte'),
              ),
            ] else ...[
              const Text(
                'Señala contenido que necesita revisión: privacidad, acoso, información falsa o spam. Esto no es una denuncia contra personas ni un reclamo urbano ante autoridades. Usa solo ejemplos ficticios.',
              ),
              DropdownButtonFormField<ComplaintReason>(
                initialValue: _draft.reason,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: [
                  for (final reason in ComplaintReason.values)
                    DropdownMenuItem(value: reason, child: Text(reason.label)),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _draft = _draft.copyWith(reason: value);
                        _dirty = true;
                      }),
              ),
              TextField(
                key: const Key('complaint-details'),
                controller: _details,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                maxLength: widget.repository.complaintTextMax,
                decoration: const InputDecoration(
                  labelText: 'Detalles privados (opcional salvo Otro)',
                  helperText: 'Indica la sección o el contenido; evita datos personales.',
                  helperMaxLines: 3,
                ),
                onChanged: (value) => setState(() {
                  _draft = _draft.copyWith(details: value);
                  _dirty = true;
                }),
              ),
              DropdownButtonFormField<SendScenario>(
                initialValue: _scenario,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Escenario simulado',
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
                'Recepción privada para revisión de 08:00 a 20:00, hora de Bolivia. Fuera de horario queda en cola. Consulta el estado en Perfil → Mis denuncias de contenido.',
              ),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: Text(_busy ? 'Enviando…' : 'Enviar denuncia a revisión'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ComplaintsPage extends StatelessWidget {
  const ComplaintsPage({
    required this.repository,
    required this.session,
    this.moderation = false,
    super.key,
  });
  final SafetyRepository repository;
  final SessionRepository session;
  final bool moderation;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([repository, session]),
    builder: (context, _) {
      final allowed =
          session.current?.role ==
          (moderation ? DemoRole.moderator : DemoRole.citizen);
      final items = allowed
          ? (moderation
                ? repository.complaintsForReview
                : repository.ownComplaints)
          : <ContentComplaint>[];
      final sorted = [...items]
        ..sort((a, b) {
          final status = (a.decision == null ? 0 : 1).compareTo(
            b.decision == null ? 0 : 1,
          );
          return status != 0 ? status : a.createdAt.compareTo(b.createdAt);
        });
      return Scaffold(
        appBar: flowAppBar(
          context,
          moderation ? 'Revisar denuncias' : 'Mis denuncias de contenido',
        ),
        body: FlowBody(
          children: [
            const DemoNotice(),
            if (!allowed)
              const Text('Disponible solo para la sesión autorizada.')
            else ...[
              const Text(
                'Contenido privado. La recepción no implica ocultamiento ni un plazo garantizado.',
              ),
              if (items.isEmpty) const Text('No hay denuncias de contenido.'),
              for (final item in sorted)
                Card(
                  child: ListTile(
                    title: Text(
                      '${item.reason.label} · ${item.decision == null ? 'Pendiente de revisión' : 'Revisión finalizada'}',
                    ),
                    subtitle: Text(
                      '${boliviaDate(item.createdAt)}\n${item.details}',
                    ),
                    onTap: moderation
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => ComplaintReviewPage(
                                id: item.id,
                                repository: repository,
                                session: session,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class ComplaintReviewPage extends StatefulWidget {
  const ComplaintReviewPage({
    required this.id,
    required this.repository,
    required this.session,
    super.key,
  });
  final String id;
  final SafetyRepository repository;
  final SessionRepository session;
  @override
  State<ComplaintReviewPage> createState() => _ComplaintReviewPageState();
}

class _ComplaintReviewPageState extends State<ComplaintReviewPage> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _resolve(bool hide) async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Escribe el motivo interno.');
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          hide ? 'Ocultar y cerrar denuncia' : 'Cerrar sin cambiar visibilidad',
        ),
        scrollable: true,
        content: Text(
          hide
              ? 'Se ocultará todo el reporte local, incluidos sus aportes y medios públicos. La decisión y el ocultamiento se guardan juntos; no significa que el problema urbano esté solucionado.'
              : 'Se registrará la revisión sin cambiar la visibilidad. El motivo queda en el historial interno.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar revisión'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.resolveComplaint(
        widget.id,
        _reason.text,
        hideReport: hide,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se guardó la decisión. Revisa la sesión y el estado actual; puedes reintentar.',
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
      final item = widget.session.current?.role == DemoRole.moderator
          ? widget.repository.complaintsForReview
                .where((c) => c.id == widget.id)
                .firstOrNull
          : null;
      return Scaffold(
        appBar: flowAppBar(context, 'Revisión de contenido'),
        body: FlowBody(
          children: [
            const DemoNotice(),
            if (item == null)
              const Text('Denuncia no disponible para esta sesión.')
            else ...[
              Text('${item.reason.label} · ${boliviaDate(item.createdAt)}'),
              Text('Referencia interna del reporte: ${item.reportId}'),
              Text(item.details),
              if (CommunityScope.maybeOf(context) case final scope?)
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ReportDetailPage(
                        repository: scope.reports,
                        reportId: item.reportId,
                        publicReading: true,
                      ),
                    ),
                  ),
                  child: const Text('Ver contenido público vigente'),
                ),
              if (item.decision != null)
                Text(
                  '${item.decision!.action}\n${boliviaDate(item.decision!.at)} · ${item.decision!.actor}\nMotivo interno: ${item.decision!.reason}',
                )
              else ...[
                if (!widget.repository.canHideForComplaint(item.reportId))
                  const Text(
                    'El catálogo inicial es de lectura. Aquí se registra la revisión; el ocultamiento se demuestra con reportes locales aprobados.',
                  ),
                TextField(
                  controller: _reason,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Motivo interno de revisión',
                  ),
                ),
                if (_error != null) FlowError(_error!),
                if (widget.repository.canHideForComplaint(item.reportId))
                  FilledButton(
                    onPressed: _busy ? null : () => _resolve(true),
                    child: const Text('Ocultar reporte y cerrar denuncia'),
                  ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _resolve(false),
                  child: const Text('Cerrar sin cambiar visibilidad'),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}
