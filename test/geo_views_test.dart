import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/core/geo_point.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/explore_filter.dart';
import 'package:reporte_ciudadano/features/reports/presentation/report_detail_page.dart';
import 'package:reporte_ciudadano/features/reports/presentation/schematic_point_map.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/presentation/report_form_page.dart';
import 'package:reporte_ciudadano/features/submissions/prototype_services.dart';

void main() {
  testWidgets('Plano selecciona coordenadas y flechas desplazan el punto', (
    tester,
  ) async {
    GeoPoint? selected;
    const center = GeoPoint(-16.5, -68.16);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SchematicPointMap(
            area: const ExploreArea(center),
            point: center,
            onPointChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    final plane = find
        .descendant(
          of: find.byType(SchematicPointMap),
          matching: find.byType(GestureDetector),
        )
        .first;
    final rect = tester.getRect(plane);
    await tester.tapAt(
      Offset(rect.left + rect.width * .75, rect.top + rect.height * .25),
    );
    await tester.pumpAndSettle();
    expect(selected!.latitude, closeTo(-16.4985, .000001));
    expect(selected!.longitude, closeTo(-68.1585, .000001));
    await tester.tap(find.byTooltip('Mover punto al norte'));
    await tester.pumpAndSettle();
    expect(selected!.latitude, closeTo(-16.49925, .000001));
    expect(selected!.longitude, closeTo(-68.16, .000001));
    final beforeScroll = selected;
    await tester.drag(plane, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(identical(selected, beforeScroll), isTrue);
  });

  testWidgets(
    'Punto gráfico actualiza campos y borrador; coordenadas manuales recentran',
    (tester) async {
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.google, 'Vecina ficticia');
      final draft = services.submissions.createDraft().copyWith(
        step: 1,
        latitude: '-16.5100',
        longitude: '-68.1700',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReportFormPage(
            draft: draft,
            repository: services.submissions,
            publicReports: DemoReportRepository(),
            session: services.session,
            location: services.location,
            photos: services.photos,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = find.byKey(const Key('report-point-map'));
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      final plane = find
          .descendant(of: map, matching: find.byType(GestureDetector))
          .first;
      final rect = tester.getRect(plane);
      await tester.tapAt(
        Offset(rect.left + rect.width * .75, rect.top + rect.height * .25),
      );
      await tester.pumpAndSettle();
      expect(
        services.submissions.ownDrafts.single.point!.latitude,
        closeTo(-16.5085, .000001),
      );
      expect(
        services.submissions.ownDrafts.single.point!.longitude,
        closeTo(-68.1685, .000001),
      );
      expect(
        find.textContaining('Punto: -16.508500, -68.168500'),
        findsOneWidget,
      );
      final latitude = find.byKey(const Key('latitude'));
      await tester.ensureVisible(latitude);
      await tester.enterText(latitude, '-16.7');
      await tester.pumpAndSettle();
      expect(
        tester.widget<SchematicPointMap>(map).area.center.latitude,
        closeTo(-16.7, .000001),
      );
    },
  );

  testWidgets('Minimapa reutiliza solo el punto público visible', (
    tester,
  ) async {
    final repository = DemoReportRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ReportDetailPage(
          repository: repository,
          reportId: '1',
          publicReading: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final minimap = find.byKey(const Key('detail-minimap'));
    await tester.ensureVisible(minimap);
    await tester.pumpAndSettle();
    expect(
      tester.widget<SchematicPointMap>(minimap).point!.latitude,
      closeTo(-16.5001, .000001),
    );
    expect(find.byTooltip('Mover punto al norte'), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: ReportDetailPage(
          repository: repository,
          reportId: '7',
          publicReading: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-minimap')), findsNothing);
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    testWidgets('Plano del reporte al 200 % en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.google, 'Vecina ficticia');
      final draft = services.submissions.createDraft().copyWith(step: 1);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ReportFormPage(
            draft: draft,
            repository: services.submissions,
            publicReports: DemoReportRepository(),
            session: services.session,
            location: services.location,
            photos: services.photos,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = find.byKey(const Key('report-point-map'));
      await tester.ensureVisible(map);
      await tester.pumpAndSettle();
      final plane = find
          .descendant(of: map, matching: find.byType(GestureDetector))
          .first;
      await tester.tapAt(tester.getRect(plane).center);
      await tester.pumpAndSettle();
      expect(services.submissions.ownDrafts.single.point!.isValid, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
