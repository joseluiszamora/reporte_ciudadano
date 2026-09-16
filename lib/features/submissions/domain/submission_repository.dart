import 'package:flutter/foundation.dart';

import 'submission.dart';

enum SendScenario { normal, offline, failBeforeSend, lostResponse }

abstract class SubmissionRepository extends ChangeNotifier {
  ReportRules get rules;
  ReportDraft createDraft();
  List<ReportDraft> get ownDrafts;
  List<PendingSubmission> get ownSubmissions;
  PendingSubmission? ownSubmission(String id);
  Future<void> saveDraft(ReportDraft draft);
  Future<void> discardDraft(String id);
  Future<PendingSubmission> submit(
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
