import 'package:flutter/foundation.dart';

import '../../reports/domain/report.dart';
import '../../community/domain/community.dart';
import '../../submissions/domain/submission_repository.dart';
import 'follow_up.dart';

abstract class FollowUpRepository extends ChangeNotifier {
  int get maxManagementPhotos;
  Report decoratePublicWorkflow(Report report);
  Future<List<Report>> reportsForFollowUp();
  Future<Report?> reportForFollowUp(String reportId);
  ResolutionRecord resolutionForReview(String reportId);
  List<Contribution> solutionEvidenceForReview(String reportId);
  Future<void> verifySolution(
    String reportId, {
    required int expectedVersion,
    required String reason,
  });
  Future<void> reopenReport(
    String reportId, {
    required int expectedVersion,
    required String reason,
  });
  Future<void> keepResolution(
    String reportId, {
    required int expectedVersion,
    required String reason,
  });
  Future<ManagementDraft> createManagement(
    String reportId, {
    String? previousId,
  });
  List<ManagementDraft> managementDrafts(String reportId);
  List<ManagementEntry> managementEntries(String reportId);
  Future<void> saveManagementDraft(ManagementDraft draft);
  Future<void> discardManagementDraft(String id);
  Future<ManagementEntry> submitManagement(
    ManagementDraft draft, {
    SendScenario scenario = SendScenario.normal,
  });
  Future<void> reviewManagement(String id, ReviewStatus status, String reason);
}
