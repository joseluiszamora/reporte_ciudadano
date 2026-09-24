import 'package:flutter/material.dart';

import '../../../core/geo_point.dart';
import '../../reports/domain/explore_filter.dart';
import '../../reports/domain/report.dart';
import '../../reports/domain/report_repository.dart';
import '../../reports/presentation/report_detail_page.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../reports/presentation/schematic_point_map.dart';
import '../domain/device_adapters.dart';
import '../domain/find_matches.dart';
import '../domain/session_repository.dart';
import '../domain/submission.dart';
import '../domain/submission_repository.dart';
import 'flow_widgets.dart';
import 'submission_status_page.dart';

class ReportFormPage extends StatefulWidget {
  const ReportFormPage({
    required this.draft,
    required this.repository,
    required this.publicReports,
    required this.session,
    required this.location,
    required this.photos,
    super.key,
  });
  final ReportDraft draft;
  final SubmissionRepository repository;
  final ReportRepository publicReports;
  final SessionRepository session;
  final LocationAdapter location;
  final PhotoAdapter photos;
  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  late ReportDraft _draft;
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final TextEditingController _title,
      _description,
      _latitude,
      _longitude,
      _zone,
      _reference;
  bool _dirty = false,
      _busy = false,
      _canPop = false,
      _denied = false,
      _gpsDenied = false;
  bool _matchesChecked = false;
  List<Report> _matches = [];
  String? _error, _saveError;
  int _saveVersion = 0;
  SendScenario _scenario = SendScenario.normal;
  ReportSubmission? _receipt;
  late ExploreArea _mapArea;
  bool get _committed => widget.repository.ownSubmission(_draft.id) != null;
  ReportRules get _rules => widget.repository.rules;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _mapArea = ExploreArea(
      _draft.point?.isValid == true
          ? _draft.point!
          : const GeoPoint(-16.5000, -68.1600),
    );
    _title = TextEditingController(text: _draft.title);
    _description = TextEditingController(text: _draft.description);
    _latitude = TextEditingController(text: _draft.latitude);
    _longitude = TextEditingController(text: _draft.longitude);
    _zone = TextEditingController(text: _draft.zone);
    _reference = TextEditingController(text: _draft.reference);
    if (widget.publicReports is Listenable) {
      (widget.publicReports as Listenable).addListener(_invalidateMatches);
    }
  }

  void _invalidateMatches() {
    if (mounted) {
      setState(() {
        _matches = [];
        _matchesChecked = false;
      });
    }
  }

  @override
  void dispose() {
    if (widget.publicReports is Listenable) {
      (widget.publicReports as Listenable).removeListener(_invalidateMatches);
    }
    for (final controller in [
      _title,
      _description,
      _latitude,
      _longitude,
      _zone,
      _reference,
    ]) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _save() async {
    final version = ++_saveVersion;
    try {
      await widget.repository.saveDraft(_draft);
      if (mounted && version == _saveVersion) setState(() => _saveError = null);
      return true;
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError =
              'No pudimos guardar en este dispositivo. '
              'Mantén abierto el formulario y vuelve a intentar guardar.',
        );
      }
      return false;
    }
  }

  void _change(ReportDraft value, {bool locationChanged = false}) {
    setState(() {
      _draft = value;
      _dirty = true;
      _error = null;
      if (locationChanged) {
        _matchesChecked = false;
        _matches = [];
        if (value.point?.isValid == true && !_mapArea.contains(value.point)) {
          _mapArea = ExploreArea(value.point!);
        }
      }
    });
    _save();
  }

  void _step(int step) {
    _change(_draft.copyWith(step: step));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _exit() async {
    if (_busy) return;
    if (!_dirty || _receipt != null || _committed) {
      _pop();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Qué hacemos con tu borrador?'),
        content: const Text(
          'Puedes guardarlo para continuar después o descartarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('Seguir editando'),
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
    if (choice == 'save') {
      if (await _save()) _pop();
    } else {
      try {
        await widget.repository.discardDraft(_draft.id);
        _pop();
      } catch (_) {
        if (mounted) {
          setState(
            () =>
                _error = 'No pudimos descartar el borrador. Intenta otra vez.',
          );
        }
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  void _pop() {
    if (!mounted) return;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (_draft.step == 0) {
      _step(1);
      return;
    }
    if (!_draft.cityConfirmed) {
      setState(() => _error = 'Confirma que el punto corresponde a El Alto.');
      return;
    }
    if (!_matchesChecked) {
      setState(() {
        _busy = true;
        _error = null;
      });
      try {
        final matches = await findPublicMatches(
          widget.publicReports,
          _draft,
          _rules,
        );
        if (!mounted) return;
        setState(() {
          _matches = matches;
          _matchesChecked = true;
        });
        if (matches.isEmpty) _step(2);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'No pudimos consultar coincidencias públicas. Vuelve a intentar.',
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      _step(2);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 4));
    final observed = _draft.observedAt.toUtc().subtract(
      const Duration(hours: 4),
    );
    final day = await showDatePicker(
      context: context,
      initialDate: observed.isAfter(now) ? now : observed,
      firstDate: DateTime(1970),
      lastDate: now,
      helpText: 'Fecha observada · hora de Bolivia',
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: observed.hour, minute: observed.minute),
      helpText: 'Hora de Bolivia',
    );
    if (time == null || !mounted) return;
    final utc = DateTime.utc(
      day.year,
      day.month,
      day.day,
      time.hour + 4,
      time.minute,
    );
    if (utc.isAfter(DateTime.now().toUtc())) {
      setState(() => _error = 'La observación no puede ser futura.');
      return;
    }
    _change(_draft.copyWith(observedAt: utc));
  }

  Future<void> _photo(bool camera) async {
    setState(() => _busy = true);
    try {
      final photo = await widget.photos.select(camera);
      if (mounted) _change(_draft.copyWith(photos: [..._draft.photos, photo]));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos agregar el adjunto simulado.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _locate() async {
    setState(() => _busy = true);
    try {
      final point = await widget.location.request(simulateDenial: _denied);
      if (!mounted) return;
      if (point == null) {
        setState(() => _gpsDenied = true);
        return;
      }
      _latitude.text = point.latitude.toStringAsFixed(6);
      _longitude.text = point.longitude.toStringAsFixed(6);
      _mapArea = ExploreArea(point);
      _change(
        _draft.copyWith(latitude: _latitude.text, longitude: _longitude.text),
        locationChanged: true,
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos obtener ubicación. Introduce el punto manualmente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final error = _rules.validate(_draft, DateTime.now().toUtc());
    if (error != null && !_committed) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _save()) return;
      final receipt = await widget.repository.submit(
        _draft,
        scenario: _scenario,
      );
      if (mounted) {
        setState(() {
          _receipt = receipt;
          _dirty = false;
        });
        _scroll.jumpTo(0);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _committed
              ? 'No recibimos la respuesta. Reintenta para recuperar el mismo envío, sin duplicarlo.'
              : 'No pudimos enviar. ${_saveError == null ? 'Tu borrador está guardado.' : 'Vuelve a guardar el borrador antes de salir.'}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _canPop,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _exit();
    },
    child: Scaffold(
      appBar: flowAppBar(
        context,
        _receipt != null ? 'Reporte enviado' : 'Reportar ${_draft.step + 1}/3',
        leading: BackButton(onPressed: _busy ? null : _exit),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DemoNotice(),
                      const SizedBox(height: 24),
                      if (_receipt != null)
                        ..._success(context)
                      else ...[
                        Text(
                          [
                            'Documentar un problema',
                            'Ubica el problema',
                            'Revisa tu reporte',
                          ][_draft.step],
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        ...(_draft.step == 0
                            ? _data()
                            : _draft.step == 1
                            ? _location()
                            : _summary()),
                        if (_saveError != null) ...[
                          FlowError(_saveError!),
                          TextButton(
                            onPressed: _busy ? null : _save,
                            child: const Text('Reintentar guardado'),
                          ),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: FlowError(_error!),
                          ),
                        const SizedBox(height: 16),
                        if (_busy)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Guardando o consultando',
                          ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('form-next'),
                          onPressed: _busy
                              ? null
                              : _draft.step < 2
                              ? _next
                              : _send,
                          child: Text(
                            _draft.step == 2
                                ? (_committed
                                      ? 'Recuperar envío'
                                      : 'Enviar a revisión')
                                : _matchesChecked &&
                                      _matches.isNotEmpty &&
                                      _draft.step == 1
                                ? 'Continuar como problema distinto'
                                : 'Continuar',
                          ),
                        ),
                        if (_draft.step > 0 && !_committed)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _step(_draft.step - 1),
                            child: const Text('Anterior'),
                          ),
                        if (!_committed)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    if (await _save()) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Borrador guardado en este dispositivo.',
                                                ),
                                              ),
                                            );
                                      }
                                    }
                                  },
                            child: const Text('Guardar borrador'),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  List<Widget> _data() => [
    const Text(
      'Describe hechos urbanos, sin acusaciones ni datos personales. Usa información ficticia.',
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<String>(
      key: const Key('category'),
      isExpanded: true,
      isDense: false,
      itemHeight: null,
      initialValue: _draft.category.isEmpty ? null : _draft.category,
      decoration: const InputDecoration(labelText: 'Categoría'),
      items: reportCategories
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      validator: (value) => value == null ? 'Selecciona una categoría.' : null,
      onChanged: _busy
          ? null
          : (value) => _change(
              _draft.copyWith(category: value!),
              locationChanged: true,
            ),
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const Key('report-title'),
      controller: _title,
      enabled: !_busy,
      maxLength: _rules.titleMax,
      decoration: const InputDecoration(labelText: 'Título'),
      validator: (value) => _rules.titleError(value ?? ''),
      onChanged: (v) => _change(_draft.copyWith(title: v)),
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const Key('report-description'),
      controller: _description,
      enabled: !_busy,
      minLines: 3,
      maxLines: 8,
      maxLength: _rules.descriptionMax,
      decoration: const InputDecoration(labelText: 'Descripción'),
      validator: (value) => _rules.descriptionError(value ?? ''),
      onChanged: (v) => _change(_draft.copyWith(description: v)),
    ),
    Text('Observado: ${boliviaDate(_draft.observedAt)} · hora de Bolivia'),
    Wrap(
      spacing: 8,
      children: [
        TextButton(
          onPressed: _busy ? null : _pickDate,
          child: const Text('Cambiar fecha y hora'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _change(
                  _draft.copyWith(observedAt: DateTime.now().toUtc()),
                ),
          child: const Text('Ahora'),
        ),
      ],
    ),
    const Text(
      'Fotos opcionales · 0–5\nCámara y galería simuladas: se agregan fichas de ejemplo, no fotografías reales.',
    ),
    if (_draft.photos.isEmpty) const Text('Sin foto adjunta'),
    for (var i = 0; i < _draft.photos.length; i++)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.image_outlined),
        title: Text(
          'Adjunto ${i + 1} · ${_draft.photos[i].split(' · ').first}',
        ),
        trailing: IconButton(
          tooltip: 'Quitar adjunto ${i + 1}',
          icon: const Icon(Icons.close),
          onPressed: _busy
              ? null
              : () => _change(
                  _draft.copyWith(photos: [..._draft.photos]..removeAt(i)),
                ),
        ),
      ),
    if (_draft.photos.length < _rules.maxPhotos)
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: _busy ? null : () => _photo(true),
            child: const Text('Simular cámara'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _photo(false),
            child: const Text('Simular galería'),
          ),
        ],
      ),
  ];

  List<Widget> _location() => [
    const Text(
      'El Alto\nAjusta el punto en el esquema o con coordenadas. No hay calles ni límites oficiales validados. '
      'Ejemplo ficticio: latitud -16.5000, longitud -68.1600.',
    ),
    const SizedBox(height: 16),
    SchematicPointMap(
      key: const Key('report-point-map'),
      area: _mapArea,
      point: _draft.point?.isValid == true ? _draft.point : null,
      enabled: !_busy,
      onPointChanged: (point) {
        _latitude.text = point.latitude.toStringAsFixed(6);
        _longitude.text = point.longitude.toStringAsFixed(6);
        _change(
          _draft.copyWith(latitude: _latitude.text, longitude: _longitude.text),
          locationChanged: true,
        );
      },
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: _denied,
      title: const Text('Simular GPS rechazado'),
      onChanged: _busy || _gpsDenied
          ? null
          : (v) => setState(() => _denied = v!),
    ),
    if (!_gpsDenied)
      OutlinedButton(
        onPressed: _busy ? null : _locate,
        child: const Text('Usar mi ubicación · simulada'),
      ),
    if (_gpsDenied)
      const Text(
        'GPS rechazado en la simulación. Introduce el punto manualmente; no volveremos a pedir permiso.',
      ),
    const SizedBox(height: 16),
    TextFormField(
      key: const Key('latitude'),
      controller: _latitude,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: const InputDecoration(labelText: 'Latitud'),
      validator: (v) => _coordinate(v, 90),
      onChanged: (v) =>
          _change(_draft.copyWith(latitude: v), locationChanged: true),
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const Key('longitude'),
      controller: _longitude,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: const InputDecoration(labelText: 'Longitud'),
      validator: (v) => _coordinate(v, 180),
      onChanged: (v) =>
          _change(_draft.copyWith(longitude: v), locationChanged: true),
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const Key('zone'),
      controller: _zone,
      enabled: !_busy,
      decoration: const InputDecoration(labelText: 'Zona ficticia (opcional)'),
      onChanged: (v) => _change(_draft.copyWith(zone: v)),
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const Key('reference'),
      controller: _reference,
      enabled: !_busy,
      maxLength: _rules.referenceMax,
      decoration: const InputDecoration(
        labelText: 'Referencia ficticia (opcional)',
      ),
      onChanged: (v) => _change(_draft.copyWith(reference: v)),
    ),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: _draft.cityConfirmed,
      title: const Text('Declaro que el punto corresponde a El Alto'),
      subtitle: const Text(
        'La pertenencia se revisará manualmente; no está validada por GPS.',
      ),
      onChanged: _busy
          ? null
          : (v) => _change(_draft.copyWith(cityConfirmed: v!)),
    ),
    if (_matchesChecked && _matches.isNotEmpty) ...[
      Text(
        'Posibles coincidencias públicas',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const Text(
        'Misma categoría y cercanía en los datos ficticios. Revisa antes de continuar.',
      ),
      for (final report in _matches)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ReportCard(
            report: report,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ReportDetailPage(
                  repository: widget.publicReports,
                  reportId: report.id,
                ),
              ),
            ),
          ),
        ),
    ],
  ];
  String? _coordinate(String? value, int limit) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    return number == null ||
            !number.isFinite ||
            number < -limit ||
            number > limit
        ? 'Introduce un valor entre -$limit y $limit.'
        : null;
  }

  List<Widget> _summary() => [
    Text(_draft.title, style: Theme.of(context).textTheme.titleLarge),
    Text(
      'Categoría: ${_draft.category}\nAlias: ${widget.session.current?.alias ?? ''}',
    ),
    Text(_draft.description),
    Text('Observado: ${boliviaDate(_draft.observedAt)} · hora de Bolivia'),
    Text(
      'El Alto (declarado)\nPunto: ${_draft.latitude}, ${_draft.longitude}\n${_draft.zone}\n${_draft.reference}',
    ),
    Text(
      _draft.photos.isEmpty
          ? 'Sin foto adjunta'
          : '${_draft.photos.length} adjuntos simulados',
    ),
    if (!_committed)
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: _busy ? null : () => _step(0),
            child: const Text('Editar datos'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _step(1),
            child: const Text('Editar ubicación'),
          ),
        ],
      ),
    const Text(
      'Tu alias, ubicación y contenido serán públicos solo tras aprobarse. '
      'Este envío es una simulación local y no llega a ninguna autoridad.',
    ),
    const Text('Revisamos contenido de 08:00 a 20:00, hora de Bolivia'),
    const SizedBox(height: 16),
    if (!_committed)
      DropdownButtonFormField<SendScenario>(
        isExpanded: true,
        isDense: false,
        itemHeight: null,
        initialValue: _scenario,
        decoration: const InputDecoration(
          labelText: 'Escenario de demostración',
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
            value: SendScenario.failBeforeSend,
            child: Text('Fallo de envío'),
          ),
          DropdownMenuItem(
            value: SendScenario.lostResponse,
            child: Text('Respuesta perdida'),
          ),
        ],
        onChanged: _busy ? null : (v) => setState(() => _scenario = v!),
      ),
    if (_scenario == SendScenario.offline && !_committed)
      const Text(
        'Sin conexión simulada: conservarás tu borrador. Cambia a Envío normal para reintentar. No hay envío en segundo plano.',
      ),
  ];
  List<Widget> _success(BuildContext context) => [
    Text(
      'Reporte enviado · Pendiente de aprobación',
      style: Theme.of(context).textTheme.headlineSmall,
    ),
    const SizedBox(height: 16),
    const Text(
      'El envío está guardado en la demostración. No aparece en Explorar.',
    ),
    const Text('Revisamos contenido de 08:00 a 20:00, hora de Bolivia'),
    Text(moderationMessage(_receipt!.sentAt)),
    const SizedBox(height: 16),
    FilledButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SubmissionStatusPage(
            id: _receipt!.id,
            repository: widget.repository,
            session: widget.session,
          ),
        ),
      ),
      child: const Text('Ver estado de mi envío'),
    ),
    TextButton(onPressed: _pop, child: const Text('Volver a explorar')),
  ];
}
