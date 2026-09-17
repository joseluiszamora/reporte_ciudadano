import '../../reports/domain/report.dart';

String reviewLabel(ReviewStatus status) => switch (status) {
  ReviewStatus.pending => 'Pendiente de aprobación',
  ReviewStatus.correctionRequested => 'Corrección solicitada',
  ReviewStatus.approved => 'Aprobado',
  ReviewStatus.rejected => 'Rechazado',
};

String dispositionLabel(PublicDisposition disposition) => switch (disposition) {
  PublicDisposition.visible => 'Visible',
  PublicDisposition.hidden => 'Oculto',
  PublicDisposition.duplicate => 'Duplicado',
};

class ModerationEvent {
  const ModerationEvent({
    required this.action,
    required this.reason,
    required this.actor,
    required this.at,
    this.revisionId,
  });
  final String action, reason, actor;
  final DateTime at;
  final String? revisionId;
  Map<String, Object?> toJson() => {
    'action': action,
    'reason': reason,
    'actor': actor,
    'at': at.toUtc().toIso8601String(),
    'revisionId': revisionId,
  };
  factory ModerationEvent.fromJson(Map<String, dynamic> json) =>
      ModerationEvent(
        action: json['action'] as String,
        reason: json['reason'] as String,
        actor: json['actor'] as String,
        at: DateTime.parse(json['at'] as String).toUtc(),
        revisionId: json['revisionId'] as String?,
      );
}

/// Punteros editoriales y disposición independientes. Nunca se entrega al lector público.
class PublicationRecord {
  PublicationRecord({
    required this.id,
    required this.latestRevisionId,
    this.approvedRevisionId,
    this.disposition = PublicDisposition.visible,
    this.duplicateOf,
    this.firstPublishedAt,
    List<ModerationEvent> history = const [],
  }) : history = List.unmodifiable(history);
  final String id, latestRevisionId;
  final String? approvedRevisionId, duplicateOf;
  final PublicDisposition disposition;
  final DateTime? firstPublishedAt;
  final List<ModerationEvent> history;
  PublicationRecord copyWith({
    String? latestRevisionId,
    String? approvedRevisionId,
    PublicDisposition? disposition,
    String? duplicateOf,
    DateTime? firstPublishedAt,
    List<ModerationEvent>? history,
  }) => PublicationRecord(
    id: id,
    latestRevisionId: latestRevisionId ?? this.latestRevisionId,
    approvedRevisionId: approvedRevisionId ?? this.approvedRevisionId,
    disposition: disposition ?? this.disposition,
    duplicateOf: disposition == null ? this.duplicateOf : duplicateOf,
    firstPublishedAt: firstPublishedAt ?? this.firstPublishedAt,
    history: history ?? this.history,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'latestRevisionId': latestRevisionId,
    'approvedRevisionId': approvedRevisionId,
    'disposition': disposition.name,
    'duplicateOf': duplicateOf,
    'firstPublishedAt': firstPublishedAt?.toUtc().toIso8601String(),
    'history': history.map((e) => e.toJson()).toList(),
  };
  factory PublicationRecord.fromJson(Map<String, dynamic> json) =>
      PublicationRecord(
        id: json['id'] as String,
        latestRevisionId: json['latestRevisionId'] as String,
        approvedRevisionId: json['approvedRevisionId'] as String?,
        disposition: PublicDisposition.values.byName(
          json['disposition'] as String,
        ),
        duplicateOf: json['duplicateOf'] as String?,
        firstPublishedAt: json['firstPublishedAt'] == null
            ? null
            : DateTime.parse(json['firstPublishedAt'] as String).toUtc(),
        history: (json['history'] as List)
            .map((e) => ModerationEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
