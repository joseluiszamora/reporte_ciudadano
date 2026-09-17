import '../domain/community.dart';

/// Instantánea inmutable compartida con envíos para confirmar datos y avisos juntos.
class CommunityState {
  CommunityState({
    Map<String, Observation> observations = const {},
    Map<String, FollowRecord> follows = const {},
    Map<String, ContributionDraft> drafts = const {},
    Map<String, Contribution> contributions = const {},
    Map<String, CommunityNotice> notices = const {},
    Map<String, NoticePreferences> preferences = const {},
    this.publicVersion = 0,
  }) : observations = Map.unmodifiable(observations),
       follows = Map.unmodifiable(follows),
       drafts = Map.unmodifiable(drafts),
       contributions = Map.unmodifiable(contributions),
       notices = Map.unmodifiable(notices),
       preferences = Map.unmodifiable(preferences);
  final Map<String, Observation> observations;
  final Map<String, FollowRecord> follows;
  final Map<String, ContributionDraft> drafts;
  final Map<String, Contribution> contributions;
  final Map<String, CommunityNotice> notices;
  final Map<String, NoticePreferences> preferences;
  final int publicVersion;
  CommunityState copyWith({
    Map<String, Observation>? observations,
    Map<String, FollowRecord>? follows,
    Map<String, ContributionDraft>? drafts,
    Map<String, Contribution>? contributions,
    Map<String, CommunityNotice>? notices,
    Map<String, NoticePreferences>? preferences,
    bool publicChanged = false,
  }) => CommunityState(
    observations: observations ?? this.observations,
    follows: follows ?? this.follows,
    drafts: drafts ?? this.drafts,
    contributions: contributions ?? this.contributions,
    notices: notices ?? this.notices,
    preferences: preferences ?? this.preferences,
    publicVersion: publicVersion + (publicChanged ? 1 : 0),
  );
  CommunityState withNotice(CommunityNotice notice) =>
      copyWith(notices: {...notices, notice.id: notice});
  Map<String, Object?> toJson() => {
    'observations': observations.values.map((v) => v.toJson()).toList(),
    'follows': follows.values.map((v) => v.toJson()).toList(),
    'drafts': drafts.values.map((v) => v.toJson()).toList(),
    'contributions': contributions.values.map((v) => v.toJson()).toList(),
    'notices': notices.values.map((v) => v.toJson()).toList(),
    'preferences': preferences.map((k, v) => MapEntry(k, v.toJson())),
    'publicVersion': publicVersion,
  };
  factory CommunityState.fromJson(Map<String, dynamic> j) {
    List<T> read<T>(String key, T Function(Map<String, dynamic>) fromJson) =>
        (j[key] as List)
            .map((v) => fromJson(v as Map<String, dynamic>))
            .toList();
    return CommunityState(
      observations: {
        for (final v in read('observations', Observation.fromJson)) v.key: v,
      },
      follows: {
        for (final v in read('follows', FollowRecord.fromJson)) v.key: v,
      },
      drafts: {
        for (final v in read('drafts', ContributionDraft.fromJson)) v.id: v,
      },
      contributions: {
        for (final v in read('contributions', Contribution.fromJson)) v.id: v,
      },
      notices: {
        for (final v in read('notices', CommunityNotice.fromJson)) v.id: v,
      },
      preferences: (j['preferences'] as Map<String, dynamic>).map(
        (k, v) =>
            MapEntry(k, NoticePreferences.fromJson(v as Map<String, dynamic>)),
      ),
      publicVersion: j['publicVersion'] as int,
    );
  }
}
