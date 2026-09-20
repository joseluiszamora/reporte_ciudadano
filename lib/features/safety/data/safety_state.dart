import '../domain/safety_repository.dart';
import '../../submissions/domain/review_record.dart';

class SafetyState {
  SafetyState({
    Map<String, ModerationEvent> withdrawals = const {},
    Map<String, ContentComplaint> complaints = const {},
    this.publicVersion = 0,
  }) : withdrawals = Map.unmodifiable(withdrawals),
       complaints = Map.unmodifiable(complaints);
  final Map<String, ModerationEvent> withdrawals;
  final Map<String, ContentComplaint> complaints;
  final int publicVersion;
  SafetyState copyWith({
    Map<String, ModerationEvent>? withdrawals,
    Map<String, ContentComplaint>? complaints,
    bool publicChanged = false,
  }) => SafetyState(
    withdrawals: withdrawals ?? this.withdrawals,
    complaints: complaints ?? this.complaints,
    publicVersion: publicVersion + (publicChanged ? 1 : 0),
  );
  Map<String, Object?> toJson() => {
    'withdrawals': withdrawals.map((k, v) => MapEntry(k, v.toJson())),
    'complaints': complaints.values.map((c) => c.toJson()).toList(),
    'publicVersion': publicVersion,
  };
  factory SafetyState.fromJson(Map<String, dynamic> j) => SafetyState(
    withdrawals: (j['withdrawals'] as Map<String, dynamic>).map(
      (k, v) =>
          MapEntry(k, ModerationEvent.fromJson(v as Map<String, dynamic>)),
    ),
    complaints: {
      for (final c in j['complaints'] as List)
        c['id'] as String: ContentComplaint.fromJson(c as Map<String, dynamic>),
    },
    publicVersion: j['publicVersion'] as int,
  );
}
