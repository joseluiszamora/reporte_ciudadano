import 'package:flutter/foundation.dart';

import '../../community/domain/community_repository.dart';
import '../../follow_up/domain/follow_up_repository.dart';

import '../../submissions/domain/submission_repository.dart';
import '../domain/report.dart';
import '../domain/report_repository.dart';

/// Única proyección pública compartida por lista, detalle y coincidencias.
class ModeratedReportRepository extends ChangeNotifier
    implements ReportRepository, ReportNoticeRepository {
  ModeratedReportRepository(
    this.catalog,
    this.submissions, {
    CommunityRepository? community,
    FollowUpRepository? followUp,
  }) : followUp =
           followUp ??
           (submissions is FollowUpRepository
               ? submissions as FollowUpRepository
               : null),
       community =
           community ??
           (submissions is CommunityRepository
               ? submissions as CommunityRepository
               : null) {
    _publicVersion = submissions.publicVersion;
    submissions.addListener(_changed);
    if (this.followUp != null &&
        !identical(this.followUp, submissions) &&
        !identical(this.followUp, this.community)) {
      this.followUp!.addListener(notifyListeners);
    }
    if (this.community != null && !identical(this.community, submissions)) {
      this.community!.addListener(notifyListeners);
    }
    if (catalog is Listenable) {
      (catalog as Listenable).addListener(notifyListeners);
    }
  }
  final ReportRepository catalog;
  final SubmissionRepository submissions;
  final CommunityRepository? community;
  final FollowUpRepository? followUp;
  late int _publicVersion;
  void _changed() {
    if (_publicVersion == submissions.publicVersion) return;
    _publicVersion = submissions.publicVersion;
    notifyListeners();
  }

  @override
  Future<List<Report>> listPublicReports() async {
    final base = await catalog.listPublicReports();
    return [...base, ...submissions.publishedReports].map(_decorate).toList()
      ..sort((a, b) => b.observedAt.compareTo(a.observedAt));
  }

  @override
  Future<Report?> getPublicReport(String id) async {
    // La lectura local se realiza después del await para no devolver una versión
    // que haya sido ocultada mientras se consultaba el catálogo.
    final base = await catalog.getPublicReport(id);
    for (final report in submissions.publishedReports) {
      if (report.id == id) return _decorate(report);
    }
    return base == null ? null : _decorate(base);
  }

  Report _decorate(Report report) {
    final result = community?.decoratePublicReport(report) ?? report;
    return followUp?.decoratePublicWorkflow(result) ?? result;
  }

  @override
  PublicReportNotice? publicNotice(String reportId) =>
      submissions.publicNotice(reportId) ??
      (catalog is ReportNoticeRepository
          ? (catalog as ReportNoticeRepository).publicNotice(reportId)
          : null);
  @override
  void dispose() {
    submissions.removeListener(_changed);
    if (followUp != null &&
        !identical(followUp, submissions) &&
        !identical(followUp, community)) {
      followUp!.removeListener(notifyListeners);
    }
    if (community != null && !identical(community, submissions)) {
      community!.removeListener(notifyListeners);
    }
    if (catalog is Listenable) {
      (catalog as Listenable).removeListener(notifyListeners);
    }
    super.dispose();
  }
}
