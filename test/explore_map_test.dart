import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/reports/domain/report_repository.dart';
import 'package:reporte_ciudadano/features/reports/presentation/explore_page.dart';
import 'package:reporte_ciudadano/features/reports/presentation/demo_report_map.dart';

class ChangingReports extends ChangeNotifier implements ReportRepository {
  List<Report> reports = demoReports();
  @override
  Future<List<Report>> listPublicReports() async =>
      reports.where((r) => r.isPublic).toList();
  @override
  Future<Report?> getPublicReport(String id) async =>
      reports.where((r) => r.id == id && r.isPublic).firstOrNull;
  void removeAll() {
    reports = [];
    notifyListeners();
  }
}

Future<void> tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    tester
        .state<ScrollableState>(
          find
              .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
              )
              .last,
        )
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Mapa comparte filtros, selección desaparece al retirar contenido',
    (tester) async {
      final repository = ChangingReports();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExplorePage(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Ver mapa');
      final map = tester.widget<DemoReportMap>(find.byType(DemoReportMap));
      expect(map.reports.length, 5);
      final marker = find.descendant(of: find.byType(DemoReportMap),
        matching: find.byType(FilledButton)).first;
      await tester.ensureVisible(marker);
      await tester.pumpAndSettle();
      expect(tester.getSize(marker), const Size(48, 48));
      await tester.tap(marker);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bache en el pasaje comunitario'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      expect(find.text('Bache en el pasaje comunitario'), findsOneWidget);
      repository.removeAll();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(DemoReportMap),
        -250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      expect(
        tester.widget<DemoReportMap>(find.byType(DemoReportMap)).reports,
        isEmpty,
      );
      expect(find.text('Bache en el pasaje comunitario'), findsNothing);
    },
  );

  testWidgets(
    'Aplicar y cancelar filtros conserva selección entre mapa y lista',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExplorePage(repository: DemoReportRepository())),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Filtros');
      await tap(tester, 'Basura');
      await tap(tester, 'Aplicar filtros');
      expect(find.text('0 reportes · Abiertos'), findsOneWidget);
      await tap(tester, 'Ver mapa');
      expect(
        tester.widget<DemoReportMap>(find.byType(DemoReportMap)).reports,
        isEmpty,
      );
      await tap(tester, 'Ver lista');
      await tap(tester, 'Filtros');
      await tap(tester, 'Baches y calzada');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('0 reportes · Abiertos'), findsOneWidget);
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(1440, 900),
  ]) {
    testWidgets('Mapa y filtros al 200 % en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: ExplorePage(repository: DemoReportRepository())),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Ver mapa');
      await tap(tester, 'Buscar en esta zona');
      await tap(tester, 'Ensayar GPS rechazado');
      expect(find.textContaining('Ubicación rechazada.'), findsOneWidget);
      await tap(tester, 'Usar ubicación simulada');
      await tap(tester, 'Filtros');
      await tap(tester, 'Aplicar filtros');
      expect(tester.takeException(), isNull);
    });
  }
}
