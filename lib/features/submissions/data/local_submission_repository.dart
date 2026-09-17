import 'dart:convert';
import 'dart:math';

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
    implements CommunityRepository {
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
  int get publicVersion => _publicVersion + _community.publicVersion;
  Future<void> _tail = Future.value();

  Future<void> load() async {
    final value = await storage.read();
    if (value == null) return;
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (![1, 2, 3].contains(json['version'])) {
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
    _community = json['version'] == 3
        ? CommunityState.fromJson(json['community'] as Map<String, dynamic>)
        : CommunityState();
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
  ]) async {
    final nextRecords = records ?? _records;
    await storage.write(
      jsonEncode({
        'version': 3,
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

  Future<void> _commitCommunity(CommunityState state) =>
      _commit({..._drafts}, {..._submissions}, {..._records}, state);
  String? _reportOwner(String reportId) =>
      _submissions[_records[reportId]?.latestRevisionId]?.draft.ownerId;

  CommunityState _notifyFollowers(
    CommunityState state,
    String reportId,
    String eventId,
    DateTime at, {
    bool comment = false,
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
          kind: comment ? NoticeKind.comment : NoticeKind.update,
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
      '${c.alias} · ${c.draft.kind.label}\n${c.draft.body}\nObservado: ${boliviaDate(c.draft.observedAt)}${c.draft.photos.isEmpty ? '' : '\nAdjuntos simulados aprobados:\n${c.draft.photos.join('\n')}'}',
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
            .where((c) => c.draft.kind == ContributionKind.evidence)
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
    final before = decoratePublicReport(report);
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
        result.add(FollowedReport(decoratePublicReport(report), news));
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
    await _commitCommunity(next);
  });
}
