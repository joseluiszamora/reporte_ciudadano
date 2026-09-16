import 'package:flutter/material.dart';

import 'app.dart';
import 'features/reports/data/demo_report_repository.dart';

void main() {
  runApp(ReporteCiudadanoApp(repository: DemoReportRepository()));
}
