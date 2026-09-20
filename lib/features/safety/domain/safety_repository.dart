import 'package:flutter/foundation.dart';

import '../../submissions/domain/review_record.dart';
import '../../submissions/domain/submission_repository.dart';

enum ComplaintReason {
  privacy('Privacidad'),
  harassment('Acoso'),
  falseInformation('Información falsa'),
  spam('Spam'),
  other('Otro');

  const ComplaintReason(this.label);
  final String label;
}

class ContentComplaint {
  const ContentComplaint({
    required this.id,
    required this.reportId,
    required this.ownerId,
    required this.createdAt,
    this.reason = ComplaintReason.privacy,
    this.details = '',
    this.decision,
  });
  final String id, reportId, ownerId, details;
  final DateTime createdAt;
  final ComplaintReason reason;
  final ModerationEvent? decision;
  ContentComplaint copyWith({
    ComplaintReason? reason,
    String? details,
    ModerationEvent? decision,
  }) => ContentComplaint(
    id: id,
    reportId: reportId,
    ownerId: ownerId,
    createdAt: createdAt,
    reason: reason ?? this.reason,
    details: details ?? this.details,
    decision: decision ?? this.decision,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'reportId': reportId,
    'ownerId': ownerId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'reason': reason.name,
    'details': details,
    'decision': decision?.toJson(),
  };
  factory ContentComplaint.fromJson(Map<String, dynamic> j) => ContentComplaint(
    id: j['id'] as String,
    reportId: j['reportId'] as String,
    ownerId: j['ownerId'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String).toUtc(),
    reason: ComplaintReason.values.byName(j['reason'] as String),
    details: j['details'] as String,
    decision: j['decision'] == null
        ? null
        : ModerationEvent.fromJson(j['decision'] as Map<String, dynamic>),
  );
}

abstract class SafetyRepository extends ChangeNotifier {
  int get complaintTextMax;
  bool canWithdrawAuthorship(String reportId);
  bool ownAuthorshipWithdrawn(String reportId);
  Future<void> withdrawAuthorship(String reportId);
  ContentComplaint createComplaint(String reportId);
  Future<void> submitComplaint(
    ContentComplaint complaint, {
    SendScenario scenario = SendScenario.normal,
  });
  List<ContentComplaint> get ownComplaints;
  List<ContentComplaint> get complaintsForReview;
  bool canHideForComplaint(String reportId);
  Future<void> resolveComplaint(
    String id,
    String reason, {
    bool hideReport = false,
  });
}
