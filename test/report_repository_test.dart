import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';

void main() {
  test(
    'consulta pública excluye pendientes, ocultos y duplicados por lista e ID',
    () async {
      final repository = DemoReportRepository();
      final reports = await repository.listPublicReports();
      expect(reports.map((r) => r.id), ['1', '2', '3', '4', '6', '9']);
      for (final id in ['5', '7', '8', 'inexistente']) {
        expect(await repository.getPublicReport(id), isNull);
      }
      expect(reports.every((r) => r.pendingRevision == null), isTrue);
    },
  );

  test('edición pendiente no reemplaza versión aprobada ni se entrega al visitante', () async {
    final report = await DemoReportRepository().getPublicReport('6');
    expect(
      report!.publicRevision!.title,
      'Señalización deteriorada en el pasaje',
    );
    expect(report.pendingRevision, isNull);
  });

  test(
    'retirar autoría conserva reporte anónimo y gestión no cambia solución',
    () async {
      final repository = DemoReportRepository();
      expect(
        (await repository.getPublicReport('9'))!.authorAlias,
        'Autor anónimo',
      );
      final managed = (await repository.getPublicReport('2'))!;
      expect(managed.management, isNotEmpty);
      expect(managed.tracking, TrackingStatus.confirmed);
    },
  );

  test(
    'hora de Bolivia independiente del dispositivo, incluso al cambiar de día',
    () {
      expect(
        boliviaDate(DateTime.utc(2026, 9, 10, 2, 5)),
        '09/09/2026 · 22:05',
      );
    },
  );
}
