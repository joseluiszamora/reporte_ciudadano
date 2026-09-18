import '../../reports/domain/report.dart';
import '../../submissions/domain/review_record.dart';

/// Únicamente los campos revisables destinados a publicación.
class ManagementSummary {
  ManagementSummary({
    required this.occurredAt,
    this.recipient = '',
    this.action = '',
    this.reference = '',
    this.response = '',
    this.nextStep = '',
    this.summary = '',
    List<String> evidence = const [],
  }) : evidence = List.unmodifiable(evidence);
  final DateTime occurredAt;
  final String recipient, action, reference, response, nextStep, summary;
  final List<String> evidence;
  ManagementSummary copyWith({
    DateTime? occurredAt,
    String? recipient,
    String? action,
    String? reference,
    String? response,
    String? nextStep,
    String? summary,
    List<String>? evidence,
  }) => ManagementSummary(
    occurredAt: occurredAt ?? this.occurredAt,
    recipient: recipient ?? this.recipient,
    action: action ?? this.action,
    reference: reference ?? this.reference,
    response: response ?? this.response,
    nextStep: nextStep ?? this.nextStep,
    summary: summary ?? this.summary,
    evidence: evidence ?? this.evidence,
  );
  String get publicText =>
      'Gestión registrada · Datos de demostración\n$summary\nDestinatario: $recipient\nAcción: $action${reference.isEmpty ? '' : '\nReferencia: $reference'}${response.isEmpty ? '' : '\nRespuesta revisada: $response'}${nextStep.isEmpty ? '' : '\nSiguiente paso: $nextStep'}${evidence.isEmpty ? '' : '\nAdjuntos simulados aprobados:\n${evidence.join('\n')}'}\nNo acredita recepción oficial ni solución del problema.';
  Map<String, Object?> toJson() => {
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'recipient': recipient,
    'action': action,
    'reference': reference,
    'response': response,
    'nextStep': nextStep,
    'summary': summary,
    'evidence': evidence,
  };
  factory ManagementSummary.fromJson(Map<String, dynamic> j) =>
      ManagementSummary(
        occurredAt: DateTime.parse(j['occurredAt'] as String).toUtc(),
        recipient: j['recipient'] as String,
        action: j['action'] as String,
        reference: j['reference'] as String,
        response: j['response'] as String,
        nextStep: j['nextStep'] as String,
        summary: j['summary'] as String,
        evidence: (j['evidence'] as List).cast<String>(),
      );
}

class ManagementDraft {
  ManagementDraft({
    required this.id,
    required this.reportId,
    required this.publicSummary,
    this.responsible = '',
    this.notes = '',
    List<String> privateDocuments = const [],
    this.previousId,
    this.groupId,
  }) : privateDocuments = List.unmodifiable(privateDocuments);
  final String id, reportId, responsible, notes;
  final String? previousId, groupId;
  final ManagementSummary publicSummary;
  final List<String> privateDocuments;
  String get group => groupId ?? id;
  ManagementDraft copyWith({
    String? id,
    ManagementSummary? publicSummary,
    String? responsible,
    String? notes,
    List<String>? privateDocuments,
    String? previousId,
    String? groupId,
  }) => ManagementDraft(
    id: id ?? this.id,
    reportId: reportId,
    publicSummary: publicSummary ?? this.publicSummary,
    responsible: responsible ?? this.responsible,
    notes: notes ?? this.notes,
    privateDocuments: privateDocuments ?? this.privateDocuments,
    previousId: previousId ?? this.previousId,
    groupId: groupId ?? this.groupId,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'reportId': reportId,
    'publicSummary': publicSummary.toJson(),
    'responsible': responsible,
    'notes': notes,
    'privateDocuments': privateDocuments,
    'previousId': previousId,
    'groupId': groupId,
  };
  factory ManagementDraft.fromJson(Map<String, dynamic> j) => ManagementDraft(
    id: j['id'] as String,
    reportId: j['reportId'] as String,
    publicSummary: ManagementSummary.fromJson(
      j['publicSummary'] as Map<String, dynamic>,
    ),
    responsible: j['responsible'] as String,
    notes: j['notes'] as String,
    privateDocuments: (j['privateDocuments'] as List).cast<String>(),
    previousId: j['previousId'] as String?,
    groupId: j['groupId'] as String?,
  );
}

class ManagementEntry {
  const ManagementEntry({
    required this.draft,
    required this.sentAt,
    required this.author,
    this.status = ReviewStatus.pending,
    this.decision,
  });
  final ManagementDraft draft;
  final DateTime sentAt;
  final String author;
  final ReviewStatus status;
  final ModerationEvent? decision;
  String get id => draft.id;
  ManagementEntry reviewed(ReviewStatus status, ModerationEvent decision) =>
      ManagementEntry(
        draft: draft,
        sentAt: sentAt,
        author: author,
        status: status,
        decision: decision,
      );
  Map<String, Object?> toJson() => {
    'draft': draft.toJson(),
    'sentAt': sentAt.toUtc().toIso8601String(),
    'author': author,
    'status': status.name,
    'decision': decision?.toJson(),
  };
  factory ManagementEntry.fromJson(Map<String, dynamic> j) => ManagementEntry(
    draft: ManagementDraft.fromJson(j['draft'] as Map<String, dynamic>),
    sentAt: DateTime.parse(j['sentAt'] as String).toUtc(),
    author: j['author'] as String,
    status: ReviewStatus.values.byName(j['status'] as String),
    decision: j['decision'] == null
        ? null
        : ModerationEvent.fromJson(j['decision'] as Map<String, dynamic>),
  );
}

class ResolutionRecord {
  ResolutionRecord({
    this.status,
    this.candidateId,
    this.version = 0,
    List<String> reviewIds = const [],
    List<ModerationEvent> history = const [],
  }) : reviewIds = List.unmodifiable(reviewIds),
       history = List.unmodifiable(history);
  final TrackingStatus? status;
  final String? candidateId;
  final int version;
  final List<String> reviewIds;
  // En este historial el motivo es un texto explícitamente revisado para publicación.
  // La identidad del revisor se conserva solo para la auditoría del equipo.
  final List<ModerationEvent> history;
  ResolutionRecord changed({
    TrackingStatus? status,
    String? candidateId,
    List<String>? reviewIds,
    required ModerationEvent event,
  }) => ResolutionRecord(
    status: status ?? this.status,
    candidateId: candidateId ?? this.candidateId,
    version: version + 1,
    reviewIds: reviewIds ?? this.reviewIds,
    history: [...history, event],
  );
  Map<String, Object?> toJson() => {
    'status': status?.name,
    'candidateId': candidateId,
    'version': version,
    'reviewIds': reviewIds,
    'history': history.map((e) => e.toJson()).toList(),
  };
  factory ResolutionRecord.fromJson(Map<String, dynamic> j) => ResolutionRecord(
    status: j['status'] == null
        ? null
        : TrackingStatus.values.byName(j['status'] as String),
    candidateId: j['candidateId'] as String?,
    version: j['version'] as int,
    reviewIds: (j['reviewIds'] as List).cast<String>(),
    history: (j['history'] as List)
        .map((e) => ModerationEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
