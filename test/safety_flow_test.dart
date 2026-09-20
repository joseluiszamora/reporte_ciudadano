import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/app.dart';
import 'package:reporte_ciudadano/core/theme/app_theme.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/data/moderated_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/safety/presentation/safety_pages.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/submission_repository.dart';
import 'package:reporte_ciudadano/features/submissions/presentation/submission_status_page.dart';
import 'package:reporte_ciudadano/features/submissions/prototype_services.dart';

import 'submission_flow_test.dart' show valid, tapVisible;

Future<String> publish(PrototypeServices services) async {
  await services.session.signIn(DemoProvider.email, 'Alias anterior');
  final item = await services.submissions.submit(valid(services));
  services.session.enterModerationScenario();
  await services.submissions.review(item.id, ReviewStatus.approved, 'Apto');
  await services.session.signIn(DemoProvider.email, 'Alias anterior');
  return item.id;
}

void main() {
  testWidgets(
    'Perfil abre retiro, cancelar conserva alias y confirmar anonimiza lectura compartida',
    (tester) async {
      final services = PrototypeServices.memory();
      final id = await publish(services);
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
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Bache ficticio en el pasaje'));
      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Retirar autoría'),
      );
      await tapVisible(tester, find.text('Cancelar'));
      expect((await public.getPublicReport(id))!.authorAlias, 'Alias anterior');
      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Retirar autoría'),
      );
      await tapVisible(tester, find.text('Confirmar retiro'));
      expect(find.textContaining('Autoría retirada'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Bache ficticio en el pasaje'));
      await tapVisible(tester, find.text('Lectura pública y enlace · demo'));
      expect(find.textContaining('Autor: Autor anónimo'), findsOneWidget);
      expect(find.textContaining('Alias anterior'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      public.dispose();
      services.dispose();
    },
  );

  testWidgets(
    'visitante accede sin enviar; denuncia con respuesta perdida se recupera y moderación revisa',
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
      await tapVisible(tester, find.text('Denunciar contenido'));
      await tester.enterText(find.byKey(const Key('alias')), 'Vecino ficticio');
      await tapVisible(tester, find.text('Simular acceso con Google'));
      expect(services.safety.ownComplaints, isEmpty);
      expect(find.byType(ComplaintFormPage), findsNothing);
      await tapVisible(tester, find.text('Denunciar contenido'));
      await tester.enterText(
        find.byKey(const Key('complaint-details')),
        'Contenido ficticio para revisión privada',
      );
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<SendScenario>),
      );
      await tester.tap(find.text('Respuesta perdida').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Enviar denuncia a revisión'));
      expect(
        find.textContaining('Respuesta perdida. Reintenta'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Enviar denuncia a revisión'));
      expect(services.safety.ownComplaints, hasLength(1));
      expect(
        find.text('Denuncia recibida · pendiente de revisión'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Volver al reporte'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Mis denuncias de contenido'));
      expect(find.text('Privacidad · Pendiente de revisión'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Escenario de moderación · demo'));
      await tapVisible(tester, find.text('Abrir moderación'));
      await tapVisible(tester, find.text('Revisar denuncias de contenido'));
      await tapVisible(tester, find.text('Privacidad · Pendiente de revisión'));
      await tester.enterText(find.byType(TextField), 'Motivo interno ficticio');
      await tapVisible(tester, find.text('Cerrar sin cambiar visibilidad'));
      await tapVisible(tester, find.text('Confirmar revisión'));
      expect(services.safety.complaintsForReview.single.decision, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
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
      'retiro y revisión con ocultamiento al 200 %, teclado y área segura en $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetPadding);
        final services = PrototypeServices.memory();
        final id = await publish(services);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: SubmissionStatusPage(
              id: id,
              repository: services.submissions,
              session: services.session,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tapVisible(
          tester,
          find.widgetWithText(OutlinedButton, 'Retirar autoría'),
        );
        await tapVisible(tester, find.text('Confirmar retiro'));
        final complaint = services.safety.createComplaint(id);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: ComplaintFormPage(
              draft: complaint,
              repository: services.safety,
              session: services.session,
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(
          find.byKey(const Key('complaint-details')),
          'Contenido ficticio observado',
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Enviar denuncia a revisión'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tapVisible(tester, find.text('Enviar denuncia a revisión'));
        expect(
          find.text('Denuncia recibida · pendiente de revisión'),
          findsOneWidget,
        );
        tester.view.resetViewInsets();
        services.session.enterModerationScenario();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: ComplaintReviewPage(
              id: complaint.id,
              repository: services.safety,
              session: services.session,
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        await tester.enterText(
          find.byType(TextField),
          'Revisión interna ficticia',
        );
        await tapVisible(
          tester,
          find.text('Ocultar reporte y cerrar denuncia'),
        );
        await tapVisible(tester, find.text('Confirmar revisión'));
        expect(services.submissions.publishedReports, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        services.dispose();
      },
    );
  }
}
