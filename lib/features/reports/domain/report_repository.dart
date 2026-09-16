import 'report.dart';

abstract interface class ReportRepository {
  Future<List<Report>> listPublicReports();
  Future<Report?> getPublicReport(String id);
}
