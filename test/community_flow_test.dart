import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/app.dart';
import 'package:reporte_ciudadano/features/community/domain/community.dart';
import 'package:reporte_ciudadano/features/community/presentation/contribution_page.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/submission_repository.dart';
import 'package:reporte_ciudadano/features/submissions/prototype_services.dart';

import 'submission_flow_test.dart' show tapVisible;

void main() {
  testWidgets(
    'visitante vuelve al detalle sin confirmar automáticamente; confirma una vez y sigue',
    (tester) async {
      final services = PrototypeServices.memory();
      await tester.pumpWidget(
        ReporteCiudadanoApp(
          repository: DemoReportRepository(),
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Bache en el pasaje comunitario'));
      await tapVisible(tester, find.text('Confirmar que sigue ocurriendo'));
      await tester.enterText(find.byKey(const Key('alias')), 'Vecina ficticia');
      await tapVisible(tester, find.text('Simular acceso con Google'));
      expect(services.community.ownObservation('1'), isNull);
      await tapVisible(tester, find.text('Confirmar que sigue ocurriendo'));
      await tapVisible(tester, find.text('Confirmar ahora'));
      expect(services.community.ownObservation('1'), isNotNull);
      await tapVisible(
        tester,
        find.text('Ya confirmaste · actualizar observación'),
      );
      await tapVisible(tester, find.text('Confirmar ahora'));
      expect(find.textContaining('1 observador independiente'), findsOneWidget);
      await tapVisible(tester, find.text('Seguir reporte'));
      expect(services.community.isFollowing('1'), isTrue);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Siguiendo'));
      await tester.pumpAndSettle();
      expect(find.text('Bache en el pasaje comunitario'), findsOneWidget);
      await services.session.signIn(DemoProvider.email, 'Otro vecino');
      await tester.pumpAndSettle();
      expect(find.text('Aún no sigues reportes'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );

  testWidgets(
    'aporte con respuesta perdida se recupera y moderación publica con motivo',
    (tester) async {
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.google, 'Vecina ficticia');
      await tester.pumpWidget(
        ReporteCiudadanoApp(
          repository: DemoReportRepository(),
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Bache en el pasaje comunitario'));
      await tapVisible(tester, find.text('Aportar comentario o evidencia'));
      await tester.enterText(
        find.byKey(const Key('contribution-body')),
        'Evidencia de prueba de un hecho ficticio',
      );
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<ContributionKind>),
      );
      await tester.tap(find.text('Evidencia').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Agregar adjunto simulado'));
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<SendScenario>),
      );
      await tester.tap(find.text('Respuesta perdida').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Enviar aporte a revisión'));
      expect(
        find.textContaining('Respuesta perdida. Reintenta'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Enviar aporte a revisión'));
      expect(find.byType(ContributionPage), findsNothing);
      expect(services.community.ownContributions, hasLength(1));
      expect(find.textContaining('Evidencia de prueba'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Escenario de moderación · demo'));
      await tapVisible(tester, find.text('Abrir moderación'));
      await tapVisible(
        tester,
        find.text('Evidencia · Pendiente de aprobación'),
      );
      await tapVisible(tester, find.text('Aprobar aporte'));
      expect(find.text('Escribe el motivo de la decisión.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Evidencia ficticia revisada',
      );
      await tapVisible(tester, find.text('Aprobar aporte'));
      await tapVisible(tester, find.text('Confirmar decisión'));
      expect(
        services.community.reviewedContributions.single.status,
        ReviewStatus.approved,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await services.session.signIn(DemoProvider.google, 'Vecina ficticia');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notificaciones simuladas'));
      await tester.pumpAndSettle();
      expect(find.text('Hay una decisión sobre tu aporte'), findsOneWidget);
      await tapVisible(tester, find.text('Hay una decisión sobre tu aporte'));
      expect(find.text('Evidencia · Aprobado'), findsOneWidget);
      expect(
        find.textContaining('Motivo: Evidencia ficticia revisada'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    testWidgets('participación, aporte, salida y bandeja al 200 % en $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ReporteCiudadanoApp(
            repository: DemoReportRepository(),
            services: services,
          ),
        ),
      );
      // El escalado del sistema atraviesa el MaterialApp.
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bache en el pasaje comunitario'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tapVisible(tester, find.text('Bache en el pasaje comunitario'));
      await tapVisible(tester, find.text('Aportar comentario o evidencia'));
      await tester.enterText(
        find.byKey(const Key('contribution-body')),
        'Borrador de demostración que se conserva',
      );
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Guardar borrador'));
      expect(services.community.ownContributionDrafts, hasLength(1));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Notificaciones simuladas'));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.text('Avisos de comentarios aprobados y agrupados'),
      );
      expect(services.community.preferences.comments, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    });
  }
}
