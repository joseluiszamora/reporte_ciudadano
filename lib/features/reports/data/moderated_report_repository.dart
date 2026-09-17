import 'package:flutter/foundation.dart';

import '../../community/domain/community_repository.dart';

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
  }) : community =
           community ??
           (submissions is CommunityRepository
               ? submissions as CommunityRepository
               : null) {
    _publicVersion = submissions.publicVersion;
    submissions.addListener(_changed);
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

  Report _decorate(Report report) =>
      community?.decoratePublicReport(report) ?? report;

  @override
  PublicReportNotice? publicNotice(String reportId) =>
      submissions.publicNotice(reportId);
  @override
  void dispose() {
    submissions.removeListener(_changed);
    if (community != null && !identical(community, submissions)) {
      community!.removeListener(notifyListeners);
    }
    if (catalog is Listenable) {
      (catalog as Listenable).removeListener(notifyListeners);
    }
    super.dispose();
  }
}
