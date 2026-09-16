import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/app.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/reports/domain/report_repository.dart';
import 'package:reporte_ciudadano/features/reports/presentation/report_detail_page.dart';

class RetryRepository implements ReportRepository {
  bool fail = true;
  @override
  Future<List<Report>> listPublicReports() async {
    if (fail) throw Exception('Error simulado');
    return [];
  }

  @override
  Future<Report?> getPublicReport(String id) async => null;
}

void main() {
  testWidgets('lista, detalle, regreso y filtros conservados', (tester) async {
    await tester.pumpWidget(
      ReporteCiudadanoApp(repository: DemoReportRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('5 reportes · Abiertos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'demostración 2');
    await tester.pumpAndSettle();
    expect(find.text('1 reportes · Abiertos'), findsOneWidget);
    final title = find.text('Acera deteriorada junto al paso peatonal');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(find.byType(ReportDetailPage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Gestiones'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Junta de demostración'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'demostración 2'), findsOneWidget);
  });

  testWidgets('navegación principal y Reportar sin barra inferior', (
    tester,
  ) async {
    await tester.pumpWidget(
      ReporteCiudadanoApp(repository: DemoReportRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Estás explorando como visitante'), findsOneWidget);
    await tester.tap(find.text('Siguiendo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explorar reportes'));
    await tester.pumpAndSettle();
    expect(find.text('Tu ciudad, con seguimiento'), findsOneWidget);
    await tester.tap(find.text('Reportar'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Documentar un problema'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('soluciones verificadas y búsqueda vacía', (tester) async {
    await tester.pumpWidget(
      ReporteCiudadanoApp(repository: DemoReportRepository()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('6 reportes · Todos'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'sin coincidencias');
    await tester.pumpAndSettle();
    expect(find.text('Sin reportes para mostrar'), findsOneWidget);
    await tester.ensureVisible(find.text('Limpiar búsqueda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpiar búsqueda'));
    await tester.pumpAndSettle();
    expect(find.text('5 reportes · Abiertos'), findsOneWidget);
  });

  testWidgets('error de repositorio permite reintentar y muestra vacío', (
    tester,
  ) async {
    final repository = RetryRepository();
    await tester.pumpWidget(ReporteCiudadanoApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar los reportes'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Sin reportes para mostrar'), findsOneWidget);
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    testWidgets('lista y detalle con texto 200% en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        ReporteCiudadanoApp(repository: DemoReportRepository()),
      );
      await tester.pumpAndSettle();

      final title = find.text('Bache en el pasaje comunitario');
      await tester.scrollUntilVisible(
        title,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Historial'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
    });
  }

  testWidgets('detalle directo de oculto no revela contenido', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportDetailPage(
          repository: DemoReportRepository(),
          reportId: '7',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reporte no disponible'), findsOneWidget);
    expect(find.text('Reporte oculto'), findsNothing);
  });
}
