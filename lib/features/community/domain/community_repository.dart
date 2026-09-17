import 'package:flutter/foundation.dart';

import '../../reports/domain/report.dart';
import '../../submissions/domain/submission_repository.dart';
import 'community.dart';

abstract class CommunityRepository extends ChangeNotifier {
  CommunityRules get communityRules;
  Report decoratePublicReport(Report report);
  Observation? ownObservation(String reportId);
  Future<void> confirmObservation(String reportId, DateTime observedAt);
  bool isFollowing(String reportId);
  Future<void> follow(String reportId, bool value);
  Future<List<FollowedReport>> following();
  Future<void> visitFollowed(String reportId);
  Future<List<CommunityNotice>> inbox();
  Future<void> readNotice(String id);
  NoticePreferences get preferences;
  Future<void> savePreferences(NoticePreferences value);
  Future<ContributionDraft> createContribution(
    String reportId, {
    String? previousId,
  });
  List<ContributionDraft> get ownContributionDrafts;
  List<Contribution> get ownContributions;
  List<Contribution> ownContributionVersions(String groupId);
  Future<void> saveContributionDraft(ContributionDraft draft);
  Future<void> discardContributionDraft(String id);
  Future<Contribution> sendContribution(
    ContributionDraft draft, {
    SendScenario scenario = SendScenario.normal,
  });
  List<Contribution> get contributionQueue;
  List<Contribution> get reviewedContributions;
  Contribution? contributionForReview(String id);
  Future<void> reviewContribution(
    String id,
    ReviewStatus status,
    String reason,
  );
}
