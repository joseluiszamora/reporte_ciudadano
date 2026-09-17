import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/app.dart';
import 'package:reporte_ciudadano/core/theme/app_theme.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/data/moderated_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/reports/presentation/report_detail_page.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/presentation/moderation_page.dart';
import 'package:reporte_ciudadano/features/submissions/presentation/report_form_page.dart';
import 'package:reporte_ciudadano/features/submissions/prototype_services.dart';

import 'submission_flow_test.dart' show valid, tapVisible;

void main() {
  testWidgets(
    'comparación en dos columnas y decisión con teclado y área segura',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
      final item = await services.submissions.submit(valid(services));
      services.session.enterModerationScenario();
      await services.submissions.review(
        item.id,
        ReviewStatus.approved,
        'Revisado',
      );
      await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
      final draft = await services.submissions.startRevision(item.id);
      final edit = await services.submissions.submit(
        draft.copyWith(title: 'Edición ficticia con nueva referencia'),
      );
      services.session.enterModerationScenario();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReviewPage(
            id: edit.id,
            repository: services.submissions,
            session: services.session,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final prior = tester.getTopLeft(find.text('Versión aprobada conservada'));
      final proposed = tester.getTopLeft(find.text('Versión enviada'));
      expect(prior.dy, proposed.dy);
      expect(prior.dx, lessThan(proposed.dx));
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Aprobar versión'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Revisión con teclado visible',
      );
      await tapVisible(tester, find.text('Confirmar decisión'));
      expect(
        services.submissions.reviewItem(edit.id)!.status,
        ReviewStatus.approved,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );

  testWidgets(
    'Perfil abre moderación, exige motivo y permite corregir desde el estado propio',
    (tester) async {
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
      final item = await services.submissions.submit(valid(services));
      await tester.pumpWidget(
        ReporteCiudadanoApp(
          repository: DemoReportRepository(),
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Escenario de moderación · demo'));
      await tapVisible(tester, find.text('Abrir moderación'));
      expect(find.text('Cola de revisión (1)'), findsOneWidget);
      await tapVisible(tester, find.text(item.draft.title).first);
      await tapVisible(tester, find.text('Solicitar corrección'));
      await tapVisible(tester, find.text('Confirmar decisión'));
      expect(find.textContaining('Escribe un motivo'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Aclara la referencia del ejemplo',
      );
      await tapVisible(tester, find.text('Confirmar decisión'));
      expect(
        services.submissions.reviewItem(item.id)!.status,
        ReviewStatus.correctionRequested,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text(item.draft.title));
      expect(
        find.textContaining('Motivo: Aclara la referencia'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Corregir y reenviar'));
      expect(find.byType(ReportFormPage), findsOneWidget);
      expect(services.submissions.ownDrafts.single.reportId, item.reportId);
      expect(
        services.submissions.ownSubmissions.single.status,
        ReviewStatus.correctionRequested,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );

  testWidgets(
    'ocultamiento actualiza un detalle abierto y elimina texto y adjuntos',
    (tester) async {
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
      final item = await services.submissions.submit(
        valid(services).copyWith(photos: ['Adjunto público ficticio']),
      );
      services.session.enterModerationScenario();
      await services.submissions.review(
        item.id,
        ReviewStatus.approved,
        'Revisado',
      );
      final public = ModeratedReportRepository(
        DemoReportRepository(),
        services.submissions,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReportDetailPage(repository: public, reportId: item.reportId),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(item.draft.title), findsOneWidget);
      expect(find.textContaining('Adjunto público ficticio'), findsOneWidget);
      await services.submissions.setDisposition(
        item.reportId,
        PublicDisposition.hidden,
        'Motivo privado',
      );
      await tester.pumpAndSettle();
      expect(find.text('Reporte oculto'), findsOneWidget);
      expect(find.text(item.draft.title), findsNothing);
      expect(find.textContaining('Adjunto público ficticio'), findsNothing);
      expect(find.textContaining('Motivo privado'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      public.dispose();
      services.dispose();
    },
  );

  testWidgets('aprobar y ocultar actualiza Explorar y conserva la búsqueda', (
    tester,
  ) async {
    final services = PrototypeServices.memory();
    await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
    final item = await services.submissions.submit(
      valid(services).copyWith(zone: 'Zona única ficticia'),
    );
    await tester.pumpWidget(
      ReporteCiudadanoApp(
        repository: DemoReportRepository(),
        services: services,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Zona única');
    await tester.pumpAndSettle();
    expect(find.text('0 reportes · Abiertos'), findsOneWidget);
    services.session.enterModerationScenario();
    await services.submissions.review(
      item.id,
      ReviewStatus.approved,
      'Revisado',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 reportes · Abiertos'), findsOneWidget);
    await services.submissions.setDisposition(
      item.reportId,
      PublicDisposition.hidden,
      'Privacidad',
    );
    await tester.pumpAndSettle();
    expect(find.text('0 reportes · Abiertos'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Zona única'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    services.dispose();
  });

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(1440, 900),
  ]) {
    testWidgets('comparación y confirmación al 200 % en $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
      final first = await services.submissions.submit(valid(services));
      services.session.enterModerationScenario();
      await services.submissions.review(
        first.id,
        ReviewStatus.approved,
        'Revisado',
      );
      await services.session.signIn(DemoProvider.email, 'Vecina ficticia');
      final draft = await services.submissions.startRevision(first.id);
      final edit = await services.submissions.submit(
        draft.copyWith(title: 'Edición pendiente de demostración'),
      );
      services.session.enterModerationScenario();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ReviewPage(
            id: edit.id,
            repository: services.submissions,
            session: services.session,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Versión aprobada conservada'), findsOneWidget);
      expect(find.text('Versión enviada'), findsOneWidget);
      await tapVisible(tester, find.text('Rechazar versión'));
      await tester.enterText(
        find.byType(TextField),
        'Motivo ficticio de rechazo',
      );
      await tapVisible(tester, find.text('Cancelar'));
      expect(
        services.submissions.reviewItem(edit.id)!.status,
        ReviewStatus.pending,
      );
      await tapVisible(tester, find.text('Ocultar reporte'));
      await tester.enterText(find.byType(TextField), 'Revisar privacidad');
      await tapVisible(tester, find.text('Confirmar decisión'));
      expect(
        services.submissions.reviewRecord(first.id).disposition,
        PublicDisposition.hidden,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    });
  }
}
