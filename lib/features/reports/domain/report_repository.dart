import 'report.dart';

abstract interface class ReportRepository {
  Future<List<Report>> listPublicReports();
  Future<Report?> getPublicReport(String id);
}

abstract interface class ReportNoticeRepository {
  PublicReportNotice? publicNotice(String reportId);
}

class PublicReportNotice {
  const PublicReportNotice(this.disposition, {this.duplicateOf});
  final PublicDisposition disposition;
  final String? duplicateOf;
}
