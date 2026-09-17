import 'package:flutter/foundation.dart';

import 'submission.dart';
import 'review_record.dart';
import '../../reports/domain/report.dart';
import '../../reports/domain/report_repository.dart';

enum SendScenario { normal, offline, failBeforeSend, lostResponse }

abstract class SubmissionRepository extends ChangeNotifier {
  ReportRules get rules;
  ReportDraft createDraft();
  List<ReportDraft> get ownDrafts;
  List<ReportSubmission> get ownSubmissions;
  ReportSubmission? ownSubmission(String id);
  List<ReportSubmission> ownVersions(String reportId);
  Future<void> saveDraft(ReportDraft draft);
  Future<void> discardDraft(String id);
  Future<ReportDraft> startRevision(String submissionId);
  List<ReportSubmission> get reviewQueue;
  List<ReportSubmission> get moderationReports;
  ReportSubmission? reviewItem(String id);
  PublicationRecord reviewRecord(String reportId);
  Report? approvedForReview(String reportId);
  List<Report> get publishedReports;
  int get publicVersion;
  PublicReportNotice? publicNotice(String reportId);
  Future<void> review(String id, ReviewStatus decision, String reason);
  Future<void> setDisposition(
    String reportId,
    PublicDisposition disposition,
    String reason, {
    String? duplicateOf,
  });
  Future<ReportSubmission> submit(
    ReportDraft draft, {
    SendScenario scenario = SendScenario.normal,
  });
}

abstract interface class DraftStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class MemoryDraftStorage implements DraftStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
