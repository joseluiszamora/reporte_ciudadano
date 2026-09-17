import 'dart:convert';
import 'dart:math';

import '../../reports/domain/report.dart';
import '../../reports/domain/report_repository.dart';
import '../domain/review_record.dart';

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
  Map<String, ReportSubmission> _submissions = {};
  Map<String, PublicationRecord> _records = {};
  int _publicVersion = 0;
  @override
  int get publicVersion => _publicVersion;
  Future<void> _tail = Future.value();

  Future<void> load() async {
    final value = await storage.read();
    if (value == null) return;
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['version'] != 1 && json['version'] != 2) {
      throw const FormatException('Formato local desconocido');
    }
    final drafts = (json['drafts'] as List).map(
      (j) => ReportDraft.fromJson(j as Map<String, dynamic>),
    );
    final submissions = (json['submissions'] as List).map(
      (j) => ReportSubmission.fromJson(j as Map<String, dynamic>),
    );
    _drafts = {for (final draft in drafts) draft.id: draft};
    _submissions = {for (final item in submissions) item.id: item};
    _records = json['version'] == 1
        ? {
            for (final item in _submissions.values)
              item.reportId: PublicationRecord(
                id: item.reportId,
                latestRevisionId: item.id,
              ),
          }
        : {
            for (final value in json['records'] as List)
              (value['id'] as String): PublicationRecord.fromJson(
                value as Map<String, dynamic>,
              ),
          };
  }

  DemoIdentity _identity() =>
      session.current ?? (throw StateError('Ingresa en la demostración.'));
  void _checkOwner(ReportDraft draft) {
    if (_identity().role != DemoRole.citizen ||
        _identity().id != draft.ownerId) {
      throw StateError('Este borrador no pertenece a la sesión.');
    }
  }

  @override
  ReportDraft createDraft() => ReportDraft(
    id: _newId(),
    ownerId: _citizen().id,
    observedAt: _clock().toUtc(),
  );
  @override
  List<ReportDraft> get ownDrafts => List.unmodifiable(
    _drafts.values.where((d) => d.ownerId == session.current?.id),
  );
  @override
  List<ReportSubmission> get ownSubmissions => List.unmodifiable(
    _submissions.values
        .where(
          (s) =>
              s.draft.ownerId == session.current?.id &&
              _records[s.reportId]?.latestRevisionId == s.id,
        )
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt)),
  );
  @override
  ReportSubmission? ownSubmission(String id) {
    final item = _submissions[id];
    return item?.draft.ownerId == session.current?.id ? item : null;
  }

  @override
  List<ReportSubmission> ownVersions(String reportId) => List.unmodifiable(
    _submissions.values
        .where(
          (s) =>
              s.reportId == reportId && s.draft.ownerId == session.current?.id,
        )
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt)),
  );

  /// Serializa escrituras y publica cambios solo después de guardar correctamente.
  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _commit(
    Map<String, ReportDraft> drafts,
    Map<String, ReportSubmission> submissions, [
    Map<String, PublicationRecord>? records,
  ]) async {
    final nextRecords = records ?? _records;
    await storage.write(
      jsonEncode({
        'version': 2,
        'drafts': drafts.values.map((d) => d.toJson()).toList(),
        'submissions': submissions.values.map((s) => s.toJson()).toList(),
        'records': nextRecords.values.map((r) => r.toJson()).toList(),
      }),
    );
    _drafts = drafts;
    _submissions = submissions;
    if (nextRecords.values.any(
      (r) =>
          r.approvedRevisionId != null &&
          (r.approvedRevisionId != _records[r.id]?.approvedRevisionId ||
              r.disposition != _records[r.id]?.disposition ||
              r.duplicateOf != _records[r.id]?.duplicateOf),
    )) {
      _publicVersion++;
    }
    _records = nextRecords;
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
  Future<ReportSubmission> submit(
    ReportDraft draft, {
    SendScenario scenario = SendScenario.normal,
  }) => _serial(() async {
    _checkOwner(draft);
    final identity = _identity();
    final previous = _submissions[draft.id];
    if (previous != null) return previous;
    final record = _records[draft.reportId ?? draft.id];
    if (draft.reportId != null &&
        (record == null ||
            record.latestRevisionId != draft.baseRevisionId ||
            _submissions[record.latestRevisionId]?.status ==
                ReviewStatus.pending ||
            _submissions[record.latestRevisionId]?.draft.ownerId !=
                identity.id)) {
      throw StateError(
        'La versión cambió. Recupera el envío más reciente desde Perfil.',
      );
    }
    final error = rules.validate(draft, _clock());
    if (error != null) throw ArgumentError(error);
    // Garantiza recuperación incluso si falla el transporte simulado.
    await _commit({..._drafts, draft.id: draft}, {..._submissions});
    if (scenario == SendScenario.offline ||
        scenario == SendScenario.failBeforeSend) {
      throw StateError('No pudimos enviar. Tu borrador está guardado.');
    }
    final submission = ReportSubmission(
      draft: draft,
      alias: identity.alias,
      sentAt: _clock().toUtc(),
    );
    await _commit(
      {..._drafts}..remove(draft.id),
      {..._submissions, draft.id: submission},
      {
        ..._records,
        submission.reportId:
            record?.copyWith(latestRevisionId: submission.id) ??
            PublicationRecord(
              id: submission.reportId,
              latestRevisionId: submission.id,
            ),
      },
    );
    if (scenario == SendScenario.lostResponse) {
      throw StateError(
        'No recibimos la respuesta. Reintenta para consultar el mismo envío.',
      );
    }
    return submission;
  });

  String _newId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  DemoIdentity _citizen() {
    final identity = _identity();
    if (identity.role != DemoRole.citizen) {
      throw StateError('Entra en una cuenta ciudadana de demostración.');
    }
    return identity;
  }

  DemoIdentity _moderator() {
    final identity = _identity();
    if (identity.role != DemoRole.moderator) {
      throw StateError('Disponible solo en el escenario de moderación.');
    }
    return identity;
  }

  @override
  Future<ReportDraft> startRevision(String submissionId) => _serial(() async {
    final item = ownSubmission(submissionId);
    if (item == null) throw StateError('Envío no disponible.');
    _checkOwner(item.draft);
    if (item.status == ReviewStatus.pending ||
        _records[item.reportId]?.latestRevisionId != item.id) {
      throw StateError(
        'Consulta la última versión; un envío pendiente no se puede editar.',
      );
    }
    for (final draft in ownDrafts) {
      if (draft.reportId == item.reportId) return draft;
    }
    final draft = item.draft.copyWith(
      id: _newId(),
      reportId: item.reportId,
      baseRevisionId: item.id,
      step: 0,
    );
    await _commit({..._drafts, draft.id: draft}, {..._submissions});
    return draft;
  });

  @override
  List<ReportSubmission> get reviewQueue {
    _moderator();
    return List.unmodifiable(
      moderationReports.where((s) => s.status == ReviewStatus.pending).toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt)),
    );
  }

  @override
  List<ReportSubmission> get moderationReports {
    _moderator();
    return List.unmodifiable(
      _records.values.map((r) => _submissions[r.latestRevisionId]!).toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt)),
    );
  }

  @override
  ReportSubmission? reviewItem(String id) {
    _moderator();
    return _submissions[id];
  }

  @override
  PublicationRecord reviewRecord(String reportId) {
    _moderator();
    return _records[reportId] ?? (throw StateError('Reporte no disponible.'));
  }

  Report? _approved(String reportId) {
    final record = _records[reportId];
    final item = _submissions[record?.approvedRevisionId];
    if (item == null || item.status != ReviewStatus.approved) return null;
    final draft = item.draft;
    return Report(
      id: reportId,
      category: draft.category,
      zone: draft.zone.isEmpty ? 'Zona de demostración' : draft.zone,
      reference: draft.reference,
      authorAlias: item.alias,
      observedAt: draft.observedAt,
      submittedAt: item.sentAt,
      publishedAt: record!.firstPublishedAt,
      tracking: TrackingStatus.reported,
      point: draft.point,
      disposition: record.disposition,
      publicRevision: ReportRevision(
        title: draft.title,
        description: draft.description,
        status: ReviewStatus.approved,
        demoAttachments: draft.photos,
      ),
      history: [
        PublicEvent(item.decision!.at, 'Versión aprobada en la demostración.'),
      ],
    );
  }

  @override
  Report? approvedForReview(String reportId) {
    _moderator();
    return _approved(reportId);
  }

  @override
  List<Report> get publishedReports => List.unmodifiable(
    _records.keys
        .map(_approved)
        .whereType<Report>()
        .where((r) => r.isPublic)
        .map((r) => r.publicView()),
  );
  @override
  PublicReportNotice? publicNotice(String reportId) {
    final record = _records[reportId];
    if (record?.approvedRevisionId == null) return null;
    final principal = _approved(record!.duplicateOf ?? '');
    return PublicReportNotice(
      record.disposition,
      duplicateOf: principal?.isPublic == true ? principal!.id : null,
    );
  }

  @override
  Future<void> review(String id, ReviewStatus decision, String reason) =>
      _serial(() async {
        final actor = _moderator();
        final item = _submissions[id];
        if (item == null ||
            item.status != ReviewStatus.pending ||
            _records[item.reportId]?.latestRevisionId != id) {
          throw StateError('Este envío ya fue revisado o cambió.');
        }
        if (item.draft.ownerId == actor.id) {
          throw StateError('No puedes revisar tu propio envío.');
        }
        if (decision == ReviewStatus.pending || reason.trim().isEmpty) {
          throw ArgumentError('Elige una decisión y escribe el motivo.');
        }
        final event = ModerationEvent(
          action: reviewLabel(decision),
          reason: reason.trim(),
          actor: actor.alias,
          at: _clock().toUtc(),
          revisionId: id,
        );
        final record = _records[item.reportId]!;
        final next = record.copyWith(
          approvedRevisionId: decision == ReviewStatus.approved ? id : null,
          firstPublishedAt:
              decision == ReviewStatus.approved &&
                  record.disposition == PublicDisposition.visible
              ? record.firstPublishedAt ?? event.at
              : null,
          history: [...record.history, event],
        );
        await _commit(
          {..._drafts},
          {..._submissions, id: item.reviewed(decision, event)},
          {..._records, item.reportId: next},
        );
      });

  @override
  Future<void> setDisposition(
    String reportId,
    PublicDisposition disposition,
    String reason, {
    String? duplicateOf,
  }) => _serial(() async {
    final actor = _moderator();
    final record = _records[reportId];
    if (record == null) throw StateError('Reporte no disponible.');
    if (reason.trim().isEmpty) throw ArgumentError('Escribe el motivo.');
    if (disposition == PublicDisposition.duplicate &&
        (duplicateOf == reportId ||
            duplicateOf == null ||
            _approved(duplicateOf)?.isPublic != true)) {
      throw ArgumentError(
        'El principal debe ser otro reporte aprobado y visible.',
      );
    }
    final event = ModerationEvent(
      action: dispositionLabel(disposition),
      reason: reason.trim(),
      actor: actor.alias,
      at: _clock().toUtc(),
    );
    await _commit({..._drafts}, {..._submissions}, {
      ..._records,
      reportId: record.copyWith(
        disposition: disposition,
        duplicateOf: duplicateOf,
        firstPublishedAt:
            disposition == PublicDisposition.visible &&
                record.approvedRevisionId != null
            ? record.firstPublishedAt ?? event.at
            : null,
        history: [...record.history, event],
      ),
    });
  });
}
