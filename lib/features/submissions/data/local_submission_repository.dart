import 'dart:convert';
import 'dart:math';

import '../domain/session_repository.dart';
import '../domain/submission.dart';
import '../domain/submission_repository.dart';

class LocalSubmissionRepository extends SubmissionRepository {
  LocalSubmissionRepository({
    required this.session,
    required this.storage,
    this.rules = const ReportRules(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final SessionRepository session;
  final DraftStorage storage;
  @override
  final ReportRules rules;
  final DateTime Function() _clock;
  Map<String, ReportDraft> _drafts = {};
  Map<String, PendingSubmission> _submissions = {};
  Future<void> _tail = Future.value();

  Future<void> load() async {
    final value = await storage.read();
    if (value == null) return;
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('Formato local desconocido');
    }
    final drafts = (json['drafts'] as List).map(
      (j) => ReportDraft.fromJson(j as Map<String, dynamic>),
    );
    final submissions = (json['submissions'] as List).map(
      (j) => PendingSubmission.fromJson(j as Map<String, dynamic>),
    );
    _drafts = {for (final draft in drafts) draft.id: draft};
    _submissions = {for (final item in submissions) item.id: item};
  }

  DemoIdentity _identity() =>
      session.current ?? (throw StateError('Ingresa en la demostración.'));
  void _checkOwner(ReportDraft draft) {
    if (_identity().id != draft.ownerId) {
      throw StateError('Este borrador no pertenece a la sesión.');
    }
  }

  @override
  ReportDraft createDraft() => ReportDraft(
    id: List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join(),
    ownerId: _identity().id,
    observedAt: _clock().toUtc(),
  );
  @override
  List<ReportDraft> get ownDrafts => List.unmodifiable(
    _drafts.values.where((d) => d.ownerId == session.current?.id),
  );
  @override
  List<PendingSubmission> get ownSubmissions => List.unmodifiable(
    _submissions.values
        .where((s) => s.draft.ownerId == session.current?.id)
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt)),
  );
  @override
  PendingSubmission? ownSubmission(String id) {
    final item = _submissions[id];
    return item?.draft.ownerId == session.current?.id ? item : null;
  }

  /// Serializa escrituras y publica cambios solo después de guardar correctamente.
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _commit(
    Map<String, ReportDraft> drafts,
    Map<String, PendingSubmission> submissions,
  ) async {
    await storage.write(
      jsonEncode({
        'version': 1,
        'drafts': drafts.values.map((d) => d.toJson()).toList(),
        'submissions': submissions.values.map((s) => s.toJson()).toList(),
      }),
    );
    _drafts = drafts;
    _submissions = submissions;
    notifyListeners();
  }

  @override
  Future<void> saveDraft(ReportDraft draft) => _serial(() async {
    _checkOwner(draft);
    // Un autoguardado tardío no puede recrear un borrador ya enviado.
    if (_submissions.containsKey(draft.id)) return;
    await _commit({..._drafts, draft.id: draft}, {..._submissions});
  });
  @override
  Future<void> discardDraft(String id) => _serial(() async {
    final draft = _drafts[id];
    if (draft == null) return;
    _checkOwner(draft);
    await _commit({..._drafts}..remove(id), {..._submissions});
  });
  @override
  Future<PendingSubmission> submit(
    ReportDraft draft, {
    SendScenario scenario = SendScenario.normal,
  }) => _serial(() async {
    _checkOwner(draft);
    final identity = _identity();
    final previous = _submissions[draft.id];
    if (previous != null) return previous;
    final error = rules.validate(draft, _clock());
    if (error != null) throw ArgumentError(error);
    // Garantiza recuperación incluso si falla el transporte simulado.
    await _commit({..._drafts, draft.id: draft}, {..._submissions});
    if (scenario == SendScenario.offline ||
        scenario == SendScenario.failBeforeSend) {
      throw StateError('No pudimos enviar. Tu borrador está guardado.');
    }
    final submission = PendingSubmission(
      draft: draft,
      alias: identity.alias,
      sentAt: _clock().toUtc(),
    );
    await _commit({..._drafts}..remove(draft.id), {
      ..._submissions,
      draft.id: submission,
    });
    if (scenario == SendScenario.lostResponse) {
      throw StateError(
        'No recibimos la respuesta. Reintenta para consultar el mismo envío.',
      );
    }
    return submission;
  });
}
