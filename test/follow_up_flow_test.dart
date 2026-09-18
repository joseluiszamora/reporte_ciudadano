import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/app.dart';
import 'package:reporte_ciudadano/core/theme/app_theme.dart';
import 'package:reporte_ciudadano/features/community/domain/community.dart';
import 'package:reporte_ciudadano/features/follow_up/presentation/follow_up_page.dart';
import 'package:reporte_ciudadano/features/follow_up/presentation/management_page.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/data/moderated_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/prototype_services.dart';

import 'submission_flow_test.dart' show tapVisible, enter;

Future<void> reason(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tapVisible(tester, find.text('Confirmar decisión'));
}

Future<void> openModeration(WidgetTester tester) async {
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
  await tapVisible(tester, find.text('Abrir moderación'));
}

void main() {
  testWidgets(
    'gestión navegable separa campos internos y publica solo después de aprobar',
    (tester) async {
      final services = PrototypeServices.memory();
      services.session.enterModerationScenario();
      final public = ModeratedReportRepository(
        DemoReportRepository(),
        services.submissions,
      );
      await tester.pumpWidget(
        ReporteCiudadanoApp(
          repository: DemoReportRepository(),
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      await openModeration(tester);
      await tapVisible(tester, find.text('Gestiones y solución'));
      await tapVisible(tester, find.text('Bache en el pasaje comunitario'));
      final priorCount = (await public.getPublicReport('1'))!.management.length;
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Registrar gestión'),
      );
      await enter(
        tester,
        'Destinatario ficticio',
        'Junta ficticia del ejemplo',
      );
      await enter(
        tester,
        'Acción realizada',
        'Entrega ficticia de antecedentes',
      );
      await enter(
        tester,
        'Resumen público',
        'Se registró una gestión de demostración',
      );
      await tapVisible(tester, find.text('Agregar evidencia pública simulada'));
      await enter(tester, 'Responsable interno', 'RESPONSABLE PRIVADO');
      await enter(tester, 'Notas internas', 'NOTAS PRIVADAS');
      await tapVisible(tester, find.text('Agregar documento interno simulado'));
      await tapVisible(tester, find.text('Enviar gestión a revisión'));
      expect(find.byType(ManagementFormPage), findsNothing);
      expect(
        (await public.getPublicReport('1'))!.management,
        hasLength(priorCount),
      );
      await tapVisible(tester, find.text('Revisar gestión e historial'));
      expect(find.textContaining('NOTAS PRIVADAS'), findsOneWidget);
      await tapVisible(tester, find.text('Aprobar gestión'));
      await tapVisible(tester, find.text('Confirmar decisión'));
      expect(find.text('Escribe un motivo.'), findsOneWidget);
      await reason(tester, 'MOTIVO INTERNO');
      final events = (await public.getPublicReport('1'))!.management;
      final text = events.last.text;
      expect(events, hasLength(priorCount + 1));
      expect(text, contains('Se registró una gestión'));
      expect(text, isNot(contains('PRIVADO')));
      expect(text, isNot(contains('INTERNO')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      public.dispose();
      services.dispose();
    },
  );

  testWidgets(
    'ciudadanía propone, moderación aprueba y verifica; reapertura conserva historial',
    (tester) async {
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
      final public = ModeratedReportRepository(
        DemoReportRepository(),
        services.submissions,
      );
      await tester.pumpWidget(
        ReporteCiudadanoApp(
          repository: DemoReportRepository(),
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Bache en el pasaje comunitario'));
      await tapVisible(tester, find.text('Aportar comentario o evidencia'));
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<ContributionKind>),
      );
      await tester.tap(find.text('Proponer solución').last);
      await tester.pumpAndSettle();
      await enter(
        tester,
        'contribution-body',
        'La reparación ficticia resuelve el problema observado.',
      );
      await tapVisible(tester, find.text('Enviar aporte a revisión'));
      expect(
        (await public.getPublicReport('1'))!.tracking,
        isNot(TrackingStatus.solutionReported),
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      services.session.enterModerationScenario();
      await tester.pumpAndSettle();
      await openModeration(tester);
      await tapVisible(
        tester,
        find.text('Proponer solución · Pendiente de aprobación'),
      );
      await tester.enterText(
        find.byType(TextField),
        'Texto y explicación revisados',
      );
      await tapVisible(tester, find.text('Aprobar aporte'));
      await tapVisible(tester, find.text('Confirmar decisión'));
      expect(
        (await public.getPublicReport('1'))!.tracking,
        TrackingStatus.solutionReported,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Gestiones y solución'));
      await tapVisible(tester, find.text('Bache en el pasaje comunitario'));
      await tapVisible(tester, find.text('Verificar solución'));
      await reason(tester, 'La solución ficticia fue revisada por separado');
      expect(
        (await public.getPublicReport('1'))!.tracking,
        TrackingStatus.verified,
      );
      await tapVisible(tester, find.text('Reabrir problema'));
      await reason(tester, 'La revisión anterior era incorrecta');
      final report = (await public.getPublicReport('1'))!;
      expect(report.tracking, isNot(TrackingStatus.verified));
      expect(
        report.history.last.text,
        contains('La revisión anterior era incorrecta'),
      );
      expect(report.updates, isNotEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      public.dispose();
      services.dispose();
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'gestión, guardado y revisión con teclado y texto 200 % en $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final services = PrototypeServices.memory();
        services.session.enterModerationScenario();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: FollowUpDashboard(
              repository: services.followUp,
              session: services.session,
              photos: services.photos,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Bache en el pasaje comunitario'));
        await tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Registrar gestión'),
        );
        await enter(
          tester,
          'Destinatario ficticio',
          'Junta ficticia de prueba',
        );
        await enter(tester, 'Acción realizada', 'Entrega simulada');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        await enter(tester, 'Resumen público', 'Resumen ficticio ampliado');
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Guardar borrador'));
        expect(services.followUp.managementDrafts('1'), hasLength(1));
        await tapVisible(tester, find.textContaining('Continuar borrador:'));
        await tapVisible(tester, find.text('Enviar gestión a revisión'));
        await tapVisible(tester, find.text('Revisar gestión e historial'));
        await tapVisible(tester, find.text('Aprobar gestión'));
        await reason(tester, 'Resumen revisado');
        expect(
          services.followUp.managementEntries('1').single.status,
          ReviewStatus.approved,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        services.dispose();
      },
    );
  }

  testWidgets('cerrar sesión retira campos internos de un formulario abierto', (
    tester,
  ) async {
    final services = PrototypeServices.memory();
    services.session.enterModerationScenario();
    final draft = (await services.followUp.createManagement('1'))
        .copyWith(notes: 'NOTA PRIVADA DE PRUEBA');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: ManagementFormPage(
          draft: draft,
          repository: services.followUp,
          session: services.session,
          photos: services.photos,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NOTA PRIVADA DE PRUEBA'), findsOneWidget);
    services.session.signOut();
    await tester.pumpAndSettle();
    expect(find.text('NOTA PRIVADA DE PRUEBA'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });
}
