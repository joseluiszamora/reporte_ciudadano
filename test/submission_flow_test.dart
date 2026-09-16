import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/app.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/submission.dart';
import 'package:reporte_ciudadano/features/submissions/domain/submission_repository.dart';
import 'package:reporte_ciudadano/features/submissions/presentation/report_form_page.dart';
import 'package:reporte_ciudadano/features/submissions/prototype_services.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String text) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

ReportDraft valid(PrototypeServices services, {int step = 0}) =>
    services.submissions.createDraft().copyWith(
      category: 'Baches y calzada',
      title: 'Bache ficticio en el pasaje',
      description:
          'Descripción ficticia del problema observado en el espacio público.',
      latitude: '-16.5100',
      longitude: '-68.1700',
      cityConfirmed: true,
      step: step,
    );

void main() {
  testWidgets(
    'visitante accede, reporta sin fotos, revisa coincidencia y reintenta offline',
    (tester) async {
      final services = PrototypeServices.memory();
      final public = DemoReportRepository();
      await tester.pumpWidget(
        ReporteCiudadanoApp(repository: public, services: services),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await enter(tester, 'alias', 'Vecina ficticia');
      await tapVisible(tester, find.text('Simular acceso con Google'));
      expect(find.text('Documentar un problema'), findsOneWidget);
      expect(services.submissions.ownSubmissions, isEmpty);
      await tapVisible(tester, find.byKey(const Key('category')));
      await tester.tap(find.text('Baches y calzada').last);
      await tester.pumpAndSettle();
      await enter(tester, 'report-title', 'Bache ficticio en el pasaje');
      await enter(
        tester,
        'report-description',
        'Descripción ficticia del problema observado en el espacio público.',
      );
      await tapVisible(tester, find.byKey(const Key('form-next')));
      await tapVisible(tester, find.text('Simular GPS rechazado'));
      await tapVisible(tester, find.text('Usar mi ubicación · simulada'));
      expect(
        find.textContaining('GPS rechazado en la simulación'),
        findsOneWidget,
      );
      expect(find.text('Usar mi ubicación · simulada'), findsNothing);
      await enter(tester, 'latitude', '-16.5000');
      await enter(tester, 'longitude', '-68.1600');
      await tapVisible(
        tester,
        find.text('Declaro que el punto corresponde a El Alto'),
      );
      await tapVisible(tester, find.byKey(const Key('form-next')));
      expect(find.text('Posibles coincidencias públicas'), findsOneWidget);
      await tapVisible(tester, find.text('Bache en el pasaje comunitario'));
      expect(services.submissions.ownSubmissions, isEmpty);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Reportar 2/3'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('form-next')));
      expect(find.text('Reportar 3/3'), findsOneWidget);
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<SendScenario>),
      );
      await tester.tap(find.text('Sin conexión').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('form-next')));
      expect(
        find.text('No pudimos enviar. Tu borrador está guardado.'),
        findsOneWidget,
      );
      expect(services.submissions.ownSubmissions, isEmpty);
      expect(services.submissions.ownDrafts, hasLength(1));
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<SendScenario>),
      );
      await tester.tap(find.text('Envío normal').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('form-next')));
      expect(
        find.text('Reporte enviado · Pendiente de aprobación'),
        findsOneWidget,
      );
      expect(services.submissions.ownSubmissions, hasLength(1));
      final sent = services.submissions.ownSubmissions.single;
      expect(sent.draft.photos, isEmpty);
      expect(await public.getPublicReport(sent.id), isNull);
      await tapVisible(tester, find.text('Ver estado de mi envío'));
      expect(find.text('Estado de mi envío'), findsOneWidget);
      expect(find.text('Pendiente de aprobación'), findsOneWidget);
    },
  );

  testWidgets(
    'correo ficticio valida código, vuelve al contexto y no envía automáticamente',
    (tester) async {
      final services = PrototypeServices.memory();
      await tester.pumpWidget(
        ReporteCiudadanoApp(
          repository: DemoReportRepository(),
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await enter(tester, 'alias', 'Alias ficticio');
      await tapVisible(tester, find.text('Simular acceso por correo'));
      await enter(tester, 'demo-code', '000000');
      await tapVisible(tester, find.text('Entrar con código simulado'));
      expect(
        find.text('Usa el código de demostración 123456.'),
        findsOneWidget,
      );
      await enter(tester, 'demo-code', '123456');
      await tapVisible(tester, find.text('Entrar con código simulado'));
      expect(find.text('Documentar un problema'), findsOneWidget);
      expect(services.session.current!.provider, DemoProvider.email);
      expect(services.submissions.ownSubmissions, isEmpty);
    },
  );

  testWidgets(
    'salida ofrece seguir, guardar y descartar; Perfil recupera borrador',
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
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await enter(tester, 'report-title', 'Borrador incompleto');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'Borrador incompleto'),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Guardar borrador'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Borrador incompleto'));
      expect(
        find.widgetWithText(TextFormField, 'Borrador incompleto'),
        findsOneWidget,
      );
      await enter(tester, 'report-title', 'Borrador a descartar');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(services.submissions.ownDrafts, isEmpty);
      expect(find.text('Aún no tienes borradores.'), findsOneWidget);
    },
  );

  testWidgets('formulario valida campos y limita adjuntos simulados a cinco', (
    tester,
  ) async {
    final services = PrototypeServices.memory();
    await services.session.signIn(DemoProvider.google, 'Vecina ficticia');
    await tester.pumpWidget(
      ReporteCiudadanoApp(
        repository: DemoReportRepository(),
        services: services,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reportar'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('form-next')));
    expect(find.text('Reportar 1/3'), findsOneWidget);
    expect(find.text('Selecciona una categoría.'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tapVisible(tester, find.text('Simular galería'));
    }
    expect(find.text('Simular galería'), findsNothing);
    expect(services.submissions.ownDrafts.single.photos, hasLength(5));
    await tapVisible(tester, find.byTooltip('Quitar adjunto 1'));
    expect(services.submissions.ownDrafts.single.photos, hasLength(4));
    expect(find.text('Simular galería'), findsOneWidget);
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
  ]) {
    testWidgets('formulario tres pasos al 200% en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.google, 'Vecina ficticia');
      final draft = valid(services);
      await services.submissions.saveDraft(draft);
      await tester.pumpWidget(
        ReporteCiudadanoApp(
          repository: DemoReportRepository(),
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text(draft.title));
      expect(find.byType(ReportFormPage), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('form-next')));
      expect(find.text('Reportar 2/3'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('form-next')));
      expect(find.text('Reportar 3/3'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('form-next')));
      expect(
        find.text('Reporte enviado · Pendiente de aprobación'),
        findsOneWidget,
      );
    });
  }
}
