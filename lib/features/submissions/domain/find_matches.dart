import '../../reports/domain/report.dart';
import '../../reports/domain/report_repository.dart';
import 'submission.dart';

Future<List<Report>> findPublicMatches(
  ReportRepository repository,
  ReportDraft draft,
  ReportRules rules,
) async {
  final point = draft.point;
  if (point == null || !point.isValid) return [];
  final reports = await repository.listPublicReports();
  return reports
      .where(
        (report) =>
            report.isPublic &&
            report.category == draft.category &&
            report.tracking != TrackingStatus.verified &&
            report.point != null &&
            point.distanceTo(report.point!) <= rules.duplicateRadius,
      )
      .toList();
}
