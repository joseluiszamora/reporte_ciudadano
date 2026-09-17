import '../../reports/domain/report.dart';
import '../../submissions/domain/review_record.dart';

enum ContributionKind {
  comment('Comentario'),
  evidence('Evidencia');

  const ContributionKind(this.label);
  final String label;
}

class CommunityRules {
  const CommunityRules({
    this.confirmationThreshold = 2,
    this.textMax = 1500,
    this.maxPhotos = 5,
  }) : assert(confirmationThreshold > 0);
  final int confirmationThreshold, textMax, maxPhotos;
}

class ContributionDraft {
  ContributionDraft({
    required this.id,
    required this.ownerId,
    required this.reportId,
    required this.observedAt,
    this.kind = ContributionKind.comment,
    this.body = '',
    List<String> photos = const [],
    this.previousId,
    this.groupId,
  }) : photos = List.unmodifiable(photos);
  final String id, ownerId, reportId, body;
  final String? previousId, groupId;
  final DateTime observedAt;
  final ContributionKind kind;
  final List<String> photos;
  String get group => groupId ?? id;
  ContributionDraft copyWith({
    String? id,
    String? body,
    ContributionKind? kind,
    List<String>? photos,
    String? previousId,
    String? groupId,
  }) => ContributionDraft(
    id: id ?? this.id,
    ownerId: ownerId,
    reportId: reportId,
    observedAt: observedAt,
    kind: kind ?? this.kind,
    body: body ?? this.body,
    photos: photos ?? this.photos,
    previousId: previousId ?? this.previousId,
    groupId: groupId ?? this.groupId,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'reportId': reportId,
    'body': body,
    'observedAt': observedAt.toUtc().toIso8601String(),
    'kind': kind.name,
    'photos': photos,
    'previousId': previousId,
    'groupId': groupId,
  };
  factory ContributionDraft.fromJson(Map<String, dynamic> j) =>
      ContributionDraft(
        id: j['id'] as String,
        ownerId: j['ownerId'] as String,
        reportId: j['reportId'] as String,
        body: j['body'] as String,
        observedAt: DateTime.parse(j['observedAt'] as String).toUtc(),
        kind: ContributionKind.values.byName(j['kind'] as String),
        photos: (j['photos'] as List).cast<String>(),
        previousId: j['previousId'] as String?,
        groupId: j['groupId'] as String?,
      );
}

class Contribution {
  const Contribution({
    required this.draft,
    required this.alias,
    required this.sentAt,
    this.status = ReviewStatus.pending,
    this.decision,
  });
  final ContributionDraft draft;
  final String alias;
  final DateTime sentAt;
  final ReviewStatus status;
  final ModerationEvent? decision;
  String get id => draft.id;
  Contribution reviewed(ReviewStatus status, ModerationEvent event) =>
      Contribution(
        draft: draft,
        alias: alias,
        sentAt: sentAt,
        status: status,
        decision: event,
      );
  Map<String, Object?> toJson() => {
    'draft': draft.toJson(),
    'alias': alias,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'status': status.name,
    'decision': decision?.toJson(),
  };
  factory Contribution.fromJson(Map<String, dynamic> j) => Contribution(
    draft: ContributionDraft.fromJson(j['draft'] as Map<String, dynamic>),
    alias: j['alias'] as String,
    sentAt: DateTime.parse(j['sentAt'] as String).toUtc(),
    status: ReviewStatus.values.byName(j['status'] as String),
    decision: j['decision'] == null
        ? null
        : ModerationEvent.fromJson(j['decision'] as Map<String, dynamic>),
  );
}

class Observation {
  const Observation(this.ownerId, this.reportId, this.at);
  final String ownerId, reportId;
  final DateTime at;
  String get key => '$ownerId:$reportId';
  Map<String, Object?> toJson() => {
    'ownerId': ownerId,
    'reportId': reportId,
    'at': at.toUtc().toIso8601String(),
  };
  factory Observation.fromJson(Map<String, dynamic> j) => Observation(
    j['ownerId'] as String,
    j['reportId'] as String,
    DateTime.parse(j['at'] as String).toUtc(),
  );
}

class FollowRecord {
  const FollowRecord(this.ownerId, this.reportId, this.visitedAt);
  final String ownerId, reportId;
  final DateTime visitedAt;
  String get key => '$ownerId:$reportId';
  Map<String, Object?> toJson() => {
    'ownerId': ownerId,
    'reportId': reportId,
    'visitedAt': visitedAt.toUtc().toIso8601String(),
  };
  factory FollowRecord.fromJson(Map<String, dynamic> j) => FollowRecord(
    j['ownerId'] as String,
    j['reportId'] as String,
    DateTime.parse(j['visitedAt'] as String).toUtc(),
  );
}

enum NoticeKind { update, comment, reportReview, contributionReview }

class CommunityNotice {
  const CommunityNotice({
    required this.id,
    required this.ownerId,
    required this.reportId,
    required this.kind,
    required this.at,
    this.targetId,
    this.read = false,
  });
  final String id, ownerId, reportId;
  final String? targetId;
  final NoticeKind kind;
  final DateTime at;
  final bool read;
  bool get isPrivate =>
      kind == NoticeKind.reportReview || kind == NoticeKind.contributionReview;
  String get label => switch (kind) {
    NoticeKind.update => 'Novedad pública aprobada',
    NoticeKind.comment => 'Comentarios aprobados · aviso agrupado',
    NoticeKind.reportReview => 'Hay una decisión sobre tu reporte',
    NoticeKind.contributionReview => 'Hay una decisión sobre tu aporte',
  };
  CommunityNotice markRead() => CommunityNotice(
    id: id,
    ownerId: ownerId,
    reportId: reportId,
    kind: kind,
    at: at,
    targetId: targetId,
    read: true,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'reportId': reportId,
    'kind': kind.name,
    'at': at.toUtc().toIso8601String(),
    'targetId': targetId,
    'read': read,
  };
  factory CommunityNotice.fromJson(Map<String, dynamic> j) => CommunityNotice(
    id: j['id'] as String,
    ownerId: j['ownerId'] as String,
    reportId: j['reportId'] as String,
    kind: NoticeKind.values.byName(j['kind'] as String),
    at: DateTime.parse(j['at'] as String).toUtc(),
    targetId: j['targetId'] as String?,
    read: j['read'] as bool,
  );
}

class NoticePreferences {
  const NoticePreferences({this.comments = false, this.pushDenied = true});
  final bool comments, pushDenied;
  Map<String, Object?> toJson() => {
    'comments': comments,
    'pushDenied': pushDenied,
  };
  factory NoticePreferences.fromJson(Map<String, dynamic> j) =>
      NoticePreferences(
        comments: j['comments'] as bool,
        pushDenied: j['pushDenied'] as bool,
      );
}

class FollowedReport {
  const FollowedReport(this.report, this.hasNews);
  final Report report;
  final bool hasNews;
}
