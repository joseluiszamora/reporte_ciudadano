import '../domain/follow_up.dart';

class WorkflowState {
  WorkflowState({
    Map<String, ManagementDraft> drafts = const {},
    Map<String, ManagementEntry> entries = const {},
    Map<String, ResolutionRecord> resolutions = const {},
    this.publicVersion = 0,
  }) : drafts = Map.unmodifiable(drafts),
       entries = Map.unmodifiable(entries),
       resolutions = Map.unmodifiable(resolutions);
  final Map<String, ManagementDraft> drafts;
  final Map<String, ManagementEntry> entries;
  final Map<String, ResolutionRecord> resolutions;
  final int publicVersion;
  WorkflowState copyWith({
    Map<String, ManagementDraft>? drafts,
    Map<String, ManagementEntry>? entries,
    Map<String, ResolutionRecord>? resolutions,
    bool publicChanged = false,
  }) => WorkflowState(
    drafts: drafts ?? this.drafts,
    entries: entries ?? this.entries,
    resolutions: resolutions ?? this.resolutions,
    publicVersion: publicVersion + (publicChanged ? 1 : 0),
  );
  Map<String, Object?> toJson() => {
    'drafts': drafts.values.map((e) => e.toJson()).toList(),
    'entries': entries.values.map((e) => e.toJson()).toList(),
    'resolutions': resolutions.map((k, v) => MapEntry(k, v.toJson())),
    'publicVersion': publicVersion,
  };
  factory WorkflowState.fromJson(Map<String, dynamic> j) => WorkflowState(
    drafts: {
      for (final v in j['drafts'] as List)
        (v['id'] as String): ManagementDraft.fromJson(
          v as Map<String, dynamic>,
        ),
    },
    entries: {
      for (final v in j['entries'] as List)
        (v['draft']['id'] as String): ManagementEntry.fromJson(
          v as Map<String, dynamic>,
        ),
    },
    resolutions: (j['resolutions'] as Map<String, dynamic>).map(
      (k, v) =>
          MapEntry(k, ResolutionRecord.fromJson(v as Map<String, dynamic>)),
    ),
    publicVersion: j['publicVersion'] as int,
  );
}
