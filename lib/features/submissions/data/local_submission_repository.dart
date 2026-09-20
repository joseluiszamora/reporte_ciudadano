import 'dart:convert';
import 'dart:math';

import '../../safety/domain/safety_repository.dart';
import '../../safety/data/safety_state.dart';

import '../../follow_up/domain/follow_up.dart';
import '../../follow_up/domain/follow_up_repository.dart';
import '../../follow_up/data/workflow_state.dart';

import '../../community/domain/community.dart';
import '../../community/domain/community_repository.dart';
import '../../community/data/community_state.dart';
import '../../reports/data/demo_report_repository.dart';

import '../../reports/domain/report.dart';
import '../../reports/domain/report_repository.dart';
import '../domain/review_record.dart';

import '../domain/session_repository.dart';
import '../domain/submission.dart';
import '../domain/submission_repository.dart';

class LocalSubmissionRepository extends SubmissionRepository
    implements CommunityRepository, FollowUpRepository, SafetyRepository {
  LocalSubmissionRepository({
    required this.session,
    required this.storage,
    this.rules = const ReportRules(),
    this.communityRules = const CommunityRules(),
    ReportRepository? catalog,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       catalog = catalog ?? DemoReportRepository();
  final ReportRepository catalog;
  @override
  final CommunityRules communityRules;
  CommunityState _community = CommunityState();
  WorkflowState _workflow = WorkflowState();
  SafetyState _safety = SafetyState();

  @override
  int get complaintTextMax => communityRules.textMax;
  @override
  bool ownAuthorshipWithdrawn(String reportId) =>
      session.current?.role == DemoRole.citizen &&
      session.current?.id == _reportOwner(reportId) &&
      _safety.withdrawals.containsKey(reportId);
  @override
  bool canWithdrawAuthorship(String reportId) =>
      session.current?.role == DemoRole.citizen &&
      session.current?.id == _reportOwner(reportId) &&
      _records[reportId]?.approvedRevisionId != null &&
      !_safety.withdrawals.containsKey(reportId);
  @override
  Future<void> withdrawAuthorship(String reportId) => _serial(() async {
    final actor = _citizen();
    if (_reportOwner(reportId) != actor.id ||
        _records[reportId]?.approvedRevisionId == null) {
      throw StateError(
        'Solo el autor puede retirar la autoría de un reporte aprobado.',
      );
    }
    if (_safety.withdrawals.containsKey(reportId)) return;
    final event = ModerationEvent(
      action: 'Autoría retirada',
      reason: 'Solicitud explícita del autor en la demostración.',
      actor: actor.id,
      at: _clock().toUtc(),
    );
    await _commit(
      {..._drafts},
      {..._submissions},
      {..._records},
      _community,
      _workflow,
      _safety.copyWith(
        withdrawals: {..._safety.withdrawals, reportId: event},
        publicChanged: true,
      ),
    );
  });
  @override
  ContentComplaint createComplaint(String reportId) => ContentComplaint(
    id: _newId(),
    reportId: reportId,
    ownerId: _citizen().id,
    createdAt: _clock().toUtc(),
  );
  @override
  Future<void> submitComplaint(
    ContentComplaint complaint, {
    SendScenario scenario = SendScenario.normal,
  }) => _serial(() async {
    final actor = _citizen();
    if (complaint.ownerId != actor.id) {
      throw StateError('La denuncia no pertenece a esta sesión.');
    }
    final existing = _safety.complaints[complaint.id];
    if (existing != null) {
      if (existing.ownerId != actor.id ||
          existing.reportId != complaint.reportId) {
        throw StateError('Identificador no disponible.');
      }
      return;
    }
    await _visibleForCitizen(complaint.reportId, actor.id);
    if (complaint.decision != null ||
        complaint.details.length > complaintTextMax ||
        (complaint.reason == ComplaintReason.other &&
            complaint.details.trim().isEmpty)) {
      throw ArgumentError('Revisa la explicación; Otro requiere detalles.');
    }
    if (scenario == SendScenario.offline ||
        scenario == SendScenario.failBeforeSend) {
      throw StateError(
        'No se envió. Conserva el formulario abierto y reintenta.',
      );
    }
    final received = ContentComplaint(
      id: complaint.id,
      reportId: complaint.reportId,
      ownerId: actor.id,
      createdAt: _clock().toUtc(),
      reason: complaint.reason,
      details: complaint.details.trim(),
    );
    await _commit(
      {..._drafts},
      {..._submissions},
      {..._records},
      _community,
      _workflow,
      _safety.copyWith(
        complaints: {..._safety.complaints, complaint.id: received},
      ),
    );
    if (scenario == SendScenario.lostResponse) {
      throw StateError(
        'Respuesta perdida. Reintenta: se recuperará la misma denuncia.',
      );
    }
  });
  @override
  List<ContentComplaint> get ownComplaints => List.unmodifiable(
    _safety.complaints.values
        .where(
          (c) =>
              session.current?.role == DemoRole.citizen &&
              c.ownerId == session.current?.id,
        )
        .map(
          (c) => c.decision == null
              ? c
              : c.copyWith(
                  decision: ModerationEvent(
                    action: 'Revisión finalizada',
                    reason: '',
                    actor: '',
                    at: c.decision!.at,
                  ),
                ),
        ),
  );
  @override
  List<ContentComplaint> get complaintsForReview {
    _moderator();
    return List.unmodifiable(_safety.complaints.values);
  }

  @override
  bool canHideForComplaint(String reportId) {
    _moderator();
    return _records[reportId]?.approvedRevisionId != null;
  }

  @override
  Future<void> resolveComplaint(
    String id,
    String reason, {
    bool hideReport = false,
  }) => _serial(() async {
    final actor = _moderator();
    final item = _safety.complaints[id];
    if (item == null || item.decision != null) {
      throw StateError('La denuncia ya fue revisada o no está disponible.');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('Escribe el motivo interno de la decisión.');
    }
    final event = ModerationEvent(
      action: hideReport
          ? 'Denuncia revisada · reporte oculto'
          : 'Denuncia revisada · sin cambiar visibilidad',
      reason: reason.trim(),
      actor: actor.alias,
      at: _clock().toUtc(),
    );
    final records = {..._records};
    if (hideReport) {
      if (!canHideForComplaint(item.reportId)) {
        throw StateError(
          'El catálogo es de lectura. Prueba el ocultamiento con un reporte local aprobado.',
        );
      }
      final record = records[item.reportId]!;
      records[item.reportId] = record.copyWith(
        disposition: PublicDisposition.hidden,
        history: [...record.history, event],
      );
    }
    await _commit(
      {..._drafts},
      {..._submissions},
      records,
      _community,
      _workflow,
      _safety.copyWith(
        complaints: {
          ..._safety.complaints,
          id: item.copyWith(decision: event),
        },
      ),
    );
  });
  @override
  int get maxManagementPhotos => rules.maxPhotos;
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
  int get publicVersion =>
      _publicVersion +
      _community.publicVersion +
      _workflow.publicVersion +
      _safety.publicVersion;
  Future<void> _tail = Future.value();

  Future<void> load() async {
    final value = await storage.read();
    if (value == null) return;
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (![1, 2, 3, 4, 5].contains(json['version'])) {
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
    _community = (json['version'] as int) >= 3
        ? CommunityState.fromJson(json['community'] as Map<String, dynamic>)
        : CommunityState();
    _workflow = (json['version'] as int) >= 4
        ? WorkflowState.fromJson(json['workflow'] as Map<String, dynamic>)
        : WorkflowState();
    _safety = json['version'] == 5
        ? SafetyState.fromJson(json['safety'] as Map<String, dynamic>)
        : SafetyState();
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
    CommunityState? community,
    WorkflowState? workflow,
    SafetyState? safety,
  ]) async {
    final nextRecords = records ?? _records;
    await storage.write(
      jsonEncode({
        'version': 5,
        'safety': (safety ?? _safety).toJson(),
        'workflow': (workflow ?? _workflow).toJson(),
        'community': (community ?? _community).toJson(),
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
    _community = community ?? _community;
    _workflow = workflow ?? _workflow;
    _safety = safety ?? _safety;
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
      authorAlias: _safety.withdrawals.containsKey(reportId)
          ? 'Autor anónimo'
          : item.alias,
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
        var community = _community.withNotice(
          CommunityNotice(
            id: 'review:$id',
            ownerId: item.draft.ownerId,
            reportId: item.reportId,
            targetId: id,
            kind: NoticeKind.reportReview,
            at: event.at,
          ),
        );
        if (decision == ReviewStatus.approved &&
            next.disposition == PublicDisposition.visible) {
          community = _notifyFollowers(
            community,
            item.reportId,
            'version:$id',
            event.at,
          );
        }
        await _commit(
          {..._drafts},
          {..._submissions, id: item.reviewed(decision, event)},
          {..._records, item.reportId: next},
          community,
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

  Future<Report?> _basePublic(String reportId) async {
    if (_records.containsKey(reportId)) {
      final report = _approved(reportId);
      return report?.isPublic == true ? report : null;
    }
    return catalog.getPublicReport(reportId);
  }

  Future<Report> _visibleForCitizen(String reportId, String ownerId) async {
    final report = await _basePublic(reportId);
    if (_citizen().id != ownerId || report == null || !report.isPublic) {
      throw StateError('El reporte ya no está disponible para participar.');
    }
    return report;
  }

  Future<void> _commitCommunity(
    CommunityState state, {
    WorkflowState? workflow,
  }) =>
      _commit({..._drafts}, {..._submissions}, {..._records}, state, workflow);
  String? _reportOwner(String reportId) =>
      _submissions[_records[reportId]?.latestRevisionId]?.draft.ownerId;

  CommunityState _notifyFollowers(
    CommunityState state,
    String reportId,
    String eventId,
    DateTime at, {
    bool comment = false,
    NoticeKind kind = NoticeKind.update,
  }) {
    var result = state;
    for (final follow in state.follows.values.where(
      (f) => f.reportId == reportId,
    )) {
      if (comment && !(state.preferences[follow.ownerId]?.comments ?? false)) {
        continue;
      }
      final id = comment
          ? 'comments:${follow.key}'
          : '$eventId:${follow.ownerId}';
      result = result.withNotice(
        CommunityNotice(
          id: id,
          ownerId: follow.ownerId,
          reportId: reportId,
          kind: comment ? NoticeKind.comment : kind,
          at: at,
        ),
      );
    }
    return result;
  }

  List<Contribution> _latestContributions({bool approvedOnly = false}) {
    final groups = <String, Contribution>{};
    for (final item in _community.contributions.values) {
      if (!approvedOnly || item.status == ReviewStatus.approved) {
        groups[item.draft.group] = item;
      }
    }
    return groups.values.toList();
  }

  @override
  Report decoratePublicReport(Report report) {
    if (!report.isPublic) {
      throw StateError('La proyección comunitaria exige una versión pública.');
    }
    final observations = _community.observations.values
        .where((o) => o.reportId == report.id)
        .toList();
    final independent = observations
        .where((o) => o.ownerId != _reportOwner(report.id))
        .length;
    final count = report.confirmations + independent;
    final tracking =
        report.tracking == TrackingStatus.reported &&
            count >= communityRules.confirmationThreshold
        ? TrackingStatus.confirmed
        : report.tracking;
    final approved = _latestContributions(approvedOnly: true)
        .where((c) => c.draft.reportId == report.id);
    PublicEvent event(Contribution c) => PublicEvent(
      c.decision!.at,
      '${_safety.withdrawals.containsKey(report.id) && c.draft.ownerId == _reportOwner(report.id) ? 'Autor anónimo' : c.alias} · ${c.draft.kind.label}\n${c.draft.body}\nObservado: ${boliviaDate(c.draft.observedAt)}${c.draft.photos.isEmpty ? '' : '\nAdjuntos simulados aprobados:\n${c.draft.photos.join('\n')}'}',
    );
    final dates = observations.map((o) => o.at).toList()..sort();
    return report.withCommunity(
      confirmations: count,
      tracking: tracking,
      comments: [
        ...report.comments,
        ...approved
            .where((c) => c.draft.kind == ContributionKind.comment)
            .map(event),
      ],
      updates: [
        ...report.updates,
        ...approved
            .where((c) => c.draft.kind != ContributionKind.comment)
            .map(event),
      ],
      lastObservation: dates.isEmpty
          ? report.lastCommunityObservedAt
          : dates.last,
    );
  }

  @override
  Observation? ownObservation(String reportId) =>
      _community.observations['${session.current?.id}:$reportId'];
  @override
  Future<void> confirmObservation(
    String reportId,
    DateTime observedAt,
  ) => _serial(() async {
    final owner = _citizen().id;
    final report = await _visibleForCitizen(reportId, owner);
    if (observedAt.isAfter(_clock())) {
      throw ArgumentError('La observación no puede ser futura.');
    }
    final before = decoratePublicWorkflow(decoratePublicReport(report));
    final observation = Observation(owner, reportId, observedAt.toUtc());
    var next = _community.copyWith(
      observations: {..._community.observations, observation.key: observation},
      publicChanged: true,
    );
    final count =
        report.confirmations +
        next.observations.values
            .where(
              (o) =>
                  o.reportId == reportId && o.ownerId != _reportOwner(reportId),
            )
            .length;
    if (before.tracking == TrackingStatus.reported &&
        count >= communityRules.confirmationThreshold) {
      next = _notifyFollowers(
        next,
        reportId,
        'confirmed:$reportId',
        _clock().toUtc(),
      );
    }
    await _commitCommunity(next);
  });

  @override
  bool isFollowing(String reportId) =>
      _community.follows.containsKey('${session.current?.id}:$reportId');
  @override
  Future<void> follow(String reportId, bool value) => _serial(() async {
    final owner = _citizen().id;
    final key = '$owner:$reportId';
    if (value) {
      await _visibleForCitizen(reportId, owner);
      if (_community.follows.containsKey(key)) return;
    }
    final follows = {..._community.follows};
    if (value) {
      follows[key] = FollowRecord(owner, reportId, _clock().toUtc());
    } else {
      follows.remove(key);
    }
    final notices = {..._community.notices}
      ..removeWhere(
        (_, n) =>
            !value &&
            n.ownerId == owner &&
            n.reportId == reportId &&
            !n.isPrivate,
      );
    await _commitCommunity(
      _community.copyWith(follows: follows, notices: notices),
    );
  });
  @override
  Future<List<FollowedReport>> following() async {
    final owner = session.current?.id;
    if (owner == null) return [];
    final result = <FollowedReport>[];
    for (final follow in _community.follows.values.where(
      (f) => f.ownerId == owner,
    )) {
      final report = await _basePublic(follow.reportId);
      if (report != null) {
        final news = _community.notices.values.any(
          (n) =>
              n.ownerId == owner &&
              n.reportId == report.id &&
              !n.isPrivate &&
              !n.read &&
              (n.kind != NoticeKind.comment || preferences.comments),
        );
        result.add(
          FollowedReport(
            decoratePublicWorkflow(decoratePublicReport(report)),
            news,
          ),
        );
      }
    }
    return session.current?.id == owner ? result : [];
  }

  @override
  Future<void> visitFollowed(String reportId) => _serial(() async {
    final owner = _citizen().id;
    await _visibleForCitizen(reportId, owner);
    final key = '$owner:$reportId';
    if (!_community.follows.containsKey(key)) return;
    await _commitCommunity(
      _community.copyWith(
        follows: {
          ..._community.follows,
          key: FollowRecord(owner, reportId, _clock().toUtc()),
        },
        notices: _community.notices.map(
          (k, n) => MapEntry(
            k,
            n.ownerId == owner && n.reportId == reportId && !n.isPrivate
                ? n.markRead()
                : n,
          ),
        ),
      ),
    );
  });
  @override
  NoticePreferences get preferences =>
      _community.preferences[session.current?.id] ?? const NoticePreferences();
  @override
  Future<void> savePreferences(NoticePreferences value) => _serial(() async {
    final owner = _citizen().id;
    await _commitCommunity(
      _community.copyWith(
        preferences: {..._community.preferences, owner: value},
      ),
    );
  });
  @override
  Future<List<CommunityNotice>> inbox() async {
    final owner = session.current?.id;
    if (owner == null) return [];
    final result = <CommunityNotice>[];
    for (final note in _community.notices.values.where(
      (n) => n.ownerId == owner,
    )) {
      if (note.isPrivate ||
          ((note.kind != NoticeKind.comment || preferences.comments) &&
              await _basePublic(note.reportId) != null)) {
        result.add(note);
      }
    }
    result.sort((a, b) => b.at.compareTo(a.at));
    return session.current?.id == owner ? result : [];
  }

  @override
  Future<void> readNotice(String id) => _serial(() async {
    final owner = _citizen().id;
    final note = _community.notices[id];
    if (note == null || note.ownerId != owner) {
      throw StateError('Aviso no disponible.');
    }
    await _commitCommunity(_community.withNotice(note.markRead()));
  });

  @override
  Future<ContributionDraft> createContribution(
    String reportId, {
    String? previousId,
  }) => _serial(() async {
    final owner = _citizen().id;
    await _visibleForCitizen(reportId, owner);
    if (previousId == null) {
      return ContributionDraft(
        id: _newId(),
        ownerId: owner,
        reportId: reportId,
        observedAt: _clock().toUtc(),
      );
    }
    final item = _community.contributions[previousId];
    if (item == null ||
        item.draft.ownerId != owner ||
        item.draft.reportId != reportId ||
        item.status == ReviewStatus.pending ||
        !_latestContributions().any((c) => c.id == previousId)) {
      throw StateError('La revisión del aporte cambió. Consulta Mis aportes.');
    }
    for (final draft in ownContributionDrafts) {
      if (draft.group == item.draft.group) return draft;
    }
    final draft = item.draft.copyWith(
      id: _newId(),
      previousId: item.id,
      groupId: item.draft.group,
    );
    await _commitCommunity(
      _community.copyWith(drafts: {..._community.drafts, draft.id: draft}),
    );
    return draft;
  });
  void _contributionOwner(ContributionDraft draft) {
    if (_citizen().id != draft.ownerId) {
      throw StateError('El aporte no pertenece a esta cuenta.');
    }
  }

  @override
  List<ContributionDraft> get ownContributionDrafts => List.unmodifiable(
    _community.drafts.values.where((d) => d.ownerId == session.current?.id),
  );
  @override
  List<Contribution> get ownContributions => List.unmodifiable(
    _latestContributions().where((c) => c.draft.ownerId == session.current?.id),
  );
  @override
  List<Contribution> ownContributionVersions(String groupId) =>
      List.unmodifiable(
        _community.contributions.values.where(
          (c) =>
              c.draft.group == groupId &&
              c.draft.ownerId == session.current?.id,
        ),
      );
  @override
  Future<void> saveContributionDraft(ContributionDraft draft) =>
      _serial(() async {
        _contributionOwner(draft);
        if (_community.contributions.containsKey(draft.id)) return;
        await _commitCommunity(
          _community.copyWith(drafts: {..._community.drafts, draft.id: draft}),
        );
      });
  @override
  Future<void> discardContributionDraft(String id) => _serial(() async {
    final draft = _community.drafts[id];
    if (draft == null) return;
    _contributionOwner(draft);
    await _commitCommunity(
      _community.copyWith(drafts: {..._community.drafts}..remove(id)),
    );
  });
  @override
  Future<Contribution> sendContribution(
    ContributionDraft draft, {
    SendScenario scenario = SendScenario.normal,
  }) => _serial(() async {
    _contributionOwner(draft);
    final identity = _citizen();
    final existing = _community.contributions[draft.id];
    if (existing != null) return existing;
    await _visibleForCitizen(draft.reportId, identity.id);
    if (draft.body.trim().isEmpty ||
        draft.body.length > communityRules.textMax ||
        draft.photos.length > communityRules.maxPhotos ||
        draft.observedAt.isAfter(_clock())) {
      throw ArgumentError(
        'Completa un texto válido, sin fecha futura y con hasta ${communityRules.maxPhotos} adjuntos.',
      );
    }
    if (draft.previousId != null) {
      final prior = _community.contributions[draft.previousId];
      if (prior == null ||
          prior.draft.ownerId != identity.id ||
          prior.draft.reportId != draft.reportId ||
          prior.draft.group != draft.group ||
          prior.status == ReviewStatus.pending ||
          !_latestContributions().any((c) => c.id == prior.id)) {
        throw StateError('La revisión del aporte cambió.');
      }
      if (prior.draft.kind != draft.kind &&
          (prior.draft.kind == ContributionKind.solution ||
              prior.draft.kind == ContributionKind.contradiction)) {
        throw ArgumentError(
          'Conserva el tipo de aporte de seguimiento al corregirlo.',
        );
      }
    } else if (draft.groupId != null) {
      throw StateError('El aporte necesita una revisión de partida.');
    }
    await _commitCommunity(
      _community.copyWith(drafts: {..._community.drafts, draft.id: draft}),
    );
    if (scenario == SendScenario.offline ||
        scenario == SendScenario.failBeforeSend) {
      throw StateError('No pudimos enviar. Tu aporte está guardado.');
    }
    final item = Contribution(
      draft: draft,
      alias: identity.alias,
      sentAt: _clock().toUtc(),
    );
    await _commitCommunity(
      _community.copyWith(
        drafts: {..._community.drafts}..remove(draft.id),
        contributions: {..._community.contributions, item.id: item},
      ),
    );
    if (scenario == SendScenario.lostResponse) {
      throw StateError(
        'Respuesta perdida. Reintenta para recuperar el mismo aporte.',
      );
    }
    return item;
  });
  @override
  List<Contribution> get contributionQueue {
    _moderator();
    return List.unmodifiable(
      _latestContributions()
          .where((c) => c.status == ReviewStatus.pending)
          .toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt)),
    );
  }

  @override
  List<Contribution> get reviewedContributions {
    _moderator();
    return List.unmodifiable(
      _community.contributions.values.where(
        (c) => c.status != ReviewStatus.pending,
      ),
    );
  }

  @override
  Contribution? contributionForReview(String id) {
    _moderator();
    return _community.contributions[id];
  }

  @override
  Future<void> reviewContribution(
    String id,
    ReviewStatus status,
    String reason,
  ) => _serial(() async {
    final actor = _moderator();
    final item = _community.contributions[id];
    if (item == null ||
        item.status != ReviewStatus.pending ||
        item.draft.ownerId == actor.id) {
      throw StateError('El aporte ya fue revisado o no está disponible.');
    }
    if (status == ReviewStatus.pending || reason.trim().isEmpty) {
      throw ArgumentError('La decisión requiere motivo.');
    }
    final report = await _basePublic(item.draft.reportId);
    if (_moderator().id != actor.id) throw StateError('La sesión cambió.');
    final event = ModerationEvent(
      action: reviewLabel(status),
      reason: reason.trim(),
      actor: actor.alias,
      at: _clock().toUtc(),
      revisionId: id,
    );
    var next = _community.copyWith(
      contributions: {
        ..._community.contributions,
        id: item.reviewed(status, event),
      },
      publicChanged: status == ReviewStatus.approved,
    );
    next = next.withNotice(
      CommunityNotice(
        id: 'contribution-review:$id',
        ownerId: item.draft.ownerId,
        reportId: item.draft.reportId,
        targetId: id,
        kind: NoticeKind.contributionReview,
        at: event.at,
      ),
    );
    if (status == ReviewStatus.approved && report != null) {
      next = _notifyFollowers(
        next,
        report.id,
        'contribution:$id',
        event.at,
        comment: item.draft.kind == ContributionKind.comment,
      );
    }
    var workflow = _workflow;
    if (status == ReviewStatus.approved &&
        (item.draft.kind == ContributionKind.solution ||
            item.draft.kind == ContributionKind.contradiction)) {
      final base = _approved(item.draft.reportId) ?? report;
      workflow = _acceptSolutionEvidence(item, base, event);
    }
    await _commitCommunity(next, workflow: workflow);
  });

  WorkflowState _acceptSolutionEvidence(
    Contribution item,
    Report? base,
    ModerationEvent decision,
  ) {
    final reportId = item.draft.reportId;
    final record = _workflow.resolutions[reportId] ?? ResolutionRecord();
    final current = record.status ?? base?.tracking ?? TrackingStatus.reported;
    final solution = item.draft.kind == ContributionKind.solution;
    final review = !solution || current == TrackingStatus.verified;
    final event = ModerationEvent(
      action: review
          ? 'Evidencia aprobada para revisión de seguimiento'
          : 'Solución reportada · pendiente de verificar',
      reason: 'Contenido aprobado. La decisión de seguimiento se realiza por separado.',
      actor: decision.actor,
      at: decision.at,
      revisionId: item.id,
    );
    final updated = record.changed(
      status: solution && current != TrackingStatus.verified
          ? TrackingStatus.solutionReported
          : current,
      candidateId: solution && current != TrackingStatus.verified
          ? item.id
          : null,
      reviewIds: review ? [...record.reviewIds, item.id] : record.reviewIds,
      event: event,
    );
    return _workflow.copyWith(
      resolutions: {..._workflow.resolutions, reportId: updated},
      publicChanged: true,
    );
  }

  @override
  Report decoratePublicWorkflow(Report report) {
    final record = _workflow.resolutions[report.id];
    var tracking = record?.status ?? report.tracking;
    if (tracking == TrackingStatus.reported &&
        report.confirmations >= communityRules.confirmationThreshold) {
      tracking = TrackingStatus.confirmed;
    }
    final approved = <String, ManagementEntry>{};
    for (final entry in _workflow.entries.values.where(
      (e) => e.draft.reportId == report.id && e.status == ReviewStatus.approved,
    )) {
      approved[entry.draft.group] = entry;
    }
    final management = [
      ...report.management,
      ...approved.values.map(
        (e) => PublicEvent(
          e.draft.publicSummary.occurredAt,
          e.draft.publicSummary.publicText,
        ),
      ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return report.withCommunity(
      confirmations: report.confirmations,
      tracking: tracking,
      comments: report.comments,
      updates: report.updates,
      lastObservation: report.lastCommunityObservedAt,
      management: management,
      history: [
        ...report.history,
        ...?record?.history.map(
          (e) => PublicEvent(e.at, '${e.action}\n${e.reason}'),
        ),
      ],
      solutionReviewRequired: record?.reviewIds.isNotEmpty ?? false,
    );
  }

  Future<Report?> _baseForWorkflow(String reportId) async =>
      _records.containsKey(reportId)
      ? _approved(reportId)
      : await catalog.getPublicReport(reportId);
  @override
  Future<Report?> reportForFollowUp(String reportId) async {
    final actor = _moderator().id;
    final base = await _baseForWorkflow(reportId);
    if (_moderator().id != actor) throw StateError('La sesión cambió.');
    return base == null
        ? null
        : decoratePublicWorkflow(
            base.isPublic ? decoratePublicReport(base) : base,
          );
  }

  @override
  Future<List<Report>> reportsForFollowUp() async {
    final actor = _moderator().id;
    final catalogReports = await catalog.listPublicReports();
    if (_moderator().id != actor) throw StateError('La sesión cambió.');
    final local = _records.keys.map(_approved).whereType<Report>();
    return [...catalogReports, ...local]
        .map(
          (r) =>
              decoratePublicWorkflow(r.isPublic ? decoratePublicReport(r) : r),
        )
        .toList();
  }

  @override
  ResolutionRecord resolutionForReview(String reportId) {
    _moderator();
    return _workflow.resolutions[reportId] ?? ResolutionRecord();
  }

  @override
  List<Contribution> solutionEvidenceForReview(String reportId) {
    _moderator();
    return List.unmodifiable(
      _community.contributions.values.where(
        (c) =>
            c.draft.reportId == reportId &&
            c.status == ReviewStatus.approved &&
            (c.draft.kind == ContributionKind.solution ||
                c.draft.kind == ContributionKind.contradiction),
      ),
    );
  }

  Future<void> _resolutionDecision(
    String reportId,
    int expectedVersion,
    String reason,
    String action,
  ) => _serial(() async {
    final actor = _moderator();
    final base = await _baseForWorkflow(reportId);
    if (_moderator().id != actor.id || base == null) {
      throw StateError('Reporte no disponible.');
    }
    final record = _workflow.resolutions[reportId] ?? ResolutionRecord();
    if (record.version != expectedVersion) {
      throw StateError(
        'El seguimiento cambió. Revisa la información actual antes de decidir.',
      );
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('Escribe el motivo público revisado.');
    }
    final current = record.status ?? base.tracking;
    var status = current;
    String? candidateId;
    if (action == 'Solución verificada') {
      final candidate = _community.contributions[record.candidateId];
      if (current != TrackingStatus.solutionReported ||
          candidate?.status != ReviewStatus.approved ||
          candidate?.draft.kind != ContributionKind.solution ||
          record.reviewIds.isNotEmpty) {
        throw StateError(
          'Se necesita evidencia de solución aprobada y revisar las contradicciones pendientes.',
        );
      }
      status = TrackingStatus.verified;
    } else if (action == 'Reporte reabierto') {
      if (current != TrackingStatus.verified &&
          current != TrackingStatus.solutionReported) {
        throw StateError('El reporte ya está abierto.');
      }
      status = TrackingStatus.reported;
    } else {
      if (record.reviewIds.isEmpty) {
        throw StateError('No hay evidencia pendiente de revisar.');
      }
      final solutions = record.reviewIds
          .map((id) => _community.contributions[id])
          .whereType<Contribution>()
          .where((c) => c.draft.kind == ContributionKind.solution)
          .toList();
      if (solutions.isNotEmpty && current == TrackingStatus.verified) {
        candidateId = solutions.last.id;
      }
    }
    final event = ModerationEvent(
      action: action,
      reason: reason.trim(),
      actor: actor.alias,
      at: _clock().toUtc(),
      revisionId: candidateId ?? record.candidateId,
    );
    final updated = record.changed(
      status: status,
      candidateId: candidateId,
      reviewIds: const [],
      event: event,
    );
    final workflow = _workflow.copyWith(
      resolutions: {..._workflow.resolutions, reportId: updated},
      publicChanged: true,
    );
    final community = base.isPublic
        ? _notifyFollowers(
            _community,
            reportId,
            'resolution:$reportId:${updated.version}',
            event.at,
            kind: NoticeKind.resolution,
          )
        : _community;
    await _commitCommunity(community, workflow: workflow);
  });
  @override
  Future<void> verifySolution(
    String reportId, {
    required int expectedVersion,
    required String reason,
  }) => _resolutionDecision(
    reportId,
    expectedVersion,
    reason,
    'Solución verificada',
  );
  @override
  Future<void> reopenReport(
    String reportId, {
    required int expectedVersion,
    required String reason,
  }) => _resolutionDecision(
    reportId,
    expectedVersion,
    reason,
    'Reporte reabierto',
  );
  @override
  Future<void> keepResolution(
    String reportId, {
    required int expectedVersion,
    required String reason,
  }) => _resolutionDecision(
    reportId,
    expectedVersion,
    reason,
    'Evidencia revisada · estado conservado',
  );

  List<ManagementEntry> _latestManagement(String reportId) {
    final groups = <String, ManagementEntry>{};
    for (final e in _workflow.entries.values.where(
      (e) => e.draft.reportId == reportId,
    )) {
      groups[e.draft.group] = e;
    }
    return groups.values.toList();
  }

  @override
  List<ManagementDraft> managementDrafts(String reportId) {
    _moderator();
    return List.unmodifiable(
      _workflow.drafts.values.where((d) => d.reportId == reportId),
    );
  }

  @override
  List<ManagementEntry> managementEntries(String reportId) {
    _moderator();
    return List.unmodifiable(
      _workflow.entries.values.where((e) => e.draft.reportId == reportId),
    );
  }

  @override
  Future<ManagementDraft> createManagement(
    String reportId, {
    String? previousId,
  }) => _serial(() async {
    _moderator();
    if (await _baseForWorkflow(reportId) == null) {
      throw StateError('El reporte debe tener una versión aprobada.');
    }
    _moderator();
    if (previousId == null) {
      return ManagementDraft(
        id: _newId(),
        reportId: reportId,
        publicSummary: ManagementSummary(occurredAt: _clock().toUtc()),
      );
    }
    final previous = _workflow.entries[previousId];
    if (previous == null ||
        previous.draft.reportId != reportId ||
        previous.status == ReviewStatus.pending ||
        !_latestManagement(reportId).any((e) => e.id == previousId)) {
      throw StateError('Consulta la última revisión de la gestión.');
    }
    for (final draft in managementDrafts(reportId)) {
      if (draft.group == previous.draft.group) return draft;
    }
    final draft = previous.draft.copyWith(
      id: _newId(),
      previousId: previousId,
      groupId: previous.draft.group,
    );
    await _commitCommunity(
      _community,
      workflow: _workflow.copyWith(
        drafts: {..._workflow.drafts, draft.id: draft},
      ),
    );
    return draft;
  });
  @override
  Future<void> saveManagementDraft(ManagementDraft draft) => _serial(() async {
    _moderator();
    if (_workflow.entries.containsKey(draft.id)) return;
    await _commitCommunity(
      _community,
      workflow: _workflow.copyWith(
        drafts: {..._workflow.drafts, draft.id: draft},
      ),
    );
  });
  @override
  Future<void> discardManagementDraft(String id) => _serial(() async {
    _moderator();
    await _commitCommunity(
      _community,
      workflow: _workflow.copyWith(drafts: {..._workflow.drafts}..remove(id)),
    );
  });
  @override
  Future<ManagementEntry> submitManagement(
    ManagementDraft draft, {
    SendScenario scenario = SendScenario.normal,
  }) => _serial(() async {
    final actor = _moderator();
    final previous = _workflow.entries[draft.id];
    if (previous != null) return previous;
    if (await _baseForWorkflow(draft.reportId) == null ||
        _moderator().id != actor.id) {
      throw StateError('Reporte no disponible.');
    }
    final summary = draft.publicSummary;
    if (summary.occurredAt.isAfter(_clock()) ||
        summary.recipient.trim().isEmpty ||
        summary.action.trim().isEmpty ||
        summary.summary.trim().isEmpty ||
        summary.evidence.length > rules.maxPhotos) {
      throw ArgumentError(
        'Completa fecha no futura, destinatario, acción y resumen público; revisa los adjuntos.',
      );
    }
    if (draft.previousId != null) {
      final prior = _workflow.entries[draft.previousId];
      if (prior == null ||
          prior.draft.reportId != draft.reportId ||
          prior.draft.group != draft.group ||
          prior.status == ReviewStatus.pending ||
          !_latestManagement(draft.reportId).any((e) => e.id == prior.id)) {
        throw StateError('La gestión cambió. Recupera su revisión vigente.');
      }
    } else if (draft.groupId != null) {
      throw StateError('Falta la revisión anterior.');
    }
    await _commitCommunity(
      _community,
      workflow: _workflow.copyWith(
        drafts: {..._workflow.drafts, draft.id: draft},
      ),
    );
    if (scenario == SendScenario.offline ||
        scenario == SendScenario.failBeforeSend) {
      throw StateError('No pudimos enviar. La gestión quedó guardada.');
    }
    final entry = ManagementEntry(
      draft: draft,
      sentAt: _clock().toUtc(),
      author: actor.alias,
    );
    await _commitCommunity(
      _community,
      workflow: _workflow.copyWith(
        drafts: {..._workflow.drafts}..remove(draft.id),
        entries: {..._workflow.entries, entry.id: entry},
      ),
    );
    if (scenario == SendScenario.lostResponse) {
      throw StateError(
        'Respuesta perdida. Reintenta para recuperar la misma gestión.',
      );
    }
    return entry;
  });
  @override
  Future<void> reviewManagement(
    String id,
    ReviewStatus status,
    String reason,
  ) => _serial(() async {
    final actor = _moderator();
    final entry = _workflow.entries[id];
    if (entry == null || entry.status != ReviewStatus.pending) {
      throw StateError('La gestión ya fue revisada o no existe.');
    }
    if (status == ReviewStatus.pending || reason.trim().isEmpty) {
      throw ArgumentError('La decisión requiere motivo.');
    }
    final base = await _baseForWorkflow(entry.draft.reportId);
    if (_moderator().id != actor.id || base == null) {
      throw StateError('Reporte no disponible.');
    }
    final event = ModerationEvent(
      action: reviewLabel(status),
      reason: reason.trim(),
      actor: actor.alias,
      at: _clock().toUtc(),
      revisionId: id,
    );
    final workflow = _workflow.copyWith(
      entries: {..._workflow.entries, id: entry.reviewed(status, event)},
      publicChanged: status == ReviewStatus.approved,
    );
    final community = status == ReviewStatus.approved && base.isPublic
        ? _notifyFollowers(
            _community,
            entry.draft.reportId,
            'management:$id',
            event.at,
            kind: NoticeKind.management,
          )
        : _community;
    await _commitCommunity(community, workflow: workflow);
  });
}
