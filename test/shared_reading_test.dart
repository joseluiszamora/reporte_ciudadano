import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/app.dart';
import 'package:reporte_ciudadano/core/theme/app_theme.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/data/moderated_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/reports/domain/report_repository.dart';
import 'package:reporte_ciudadano/features/reports/presentation/report_detail_page.dart';
import 'package:reporte_ciudadano/features/sharing/domain/demo_report_link.dart';
import 'package:reporte_ciudadano/features/sharing/presentation/open_demo_link_page.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/prototype_services.dart';

import 'submission_flow_test.dart' show valid, tapVisible;

class _FailingRepository extends ChangeNotifier implements ReportRepository {
  bool fail = true;
  Completer<Report?>? delayed;
  @override
  Future<Report?> getPublicReport(String id) async {
    if (delayed != null) return delayed!.future;
    if (fail) throw StateError('Sin conexión');
    return DemoReportRepository().getPublicReport(id);
  }

  @override
  Future<List<Report>> listPublicReports() =>
      DemoReportRepository().listPublicReports();
  void refresh() => notifyListeners();
}

void main() {
  test('enlace solo contiene identificador y rechaza enlaces externos o manipulados', () {
    for (final id in ['1', 'reporte_123-abc']) {
      expect(DemoReportLink.decode('  ${DemoReportLink.encode(id)}  '), id);
    }
    for (final value in [
      '',
      'https://ejemplo.com/reportes/1',
      'reporte-ciudadano-demo://otra/reportes/1',
      'reporte-ciudadano-demo://local/reportes/1?rol=moderador',
      'reporte-ciudadano-demo://local/reportes/1#privado',
      'reporte-ciudadano-demo://autor@local/reportes/1',
      'reporte-ciudadano-demo://local:80/reportes/1',
      'reporte-ciudadano-demo://local/reportes/1/otra',
      'reporte-ciudadano-demo://local/reportes/%2F',
      'reporte-ciudadano-demo://local/reportes/..',
    ]) {
      expect(
        () => DemoReportLink.decode(value),
        throwsFormatException,
        reason: value,
      );
    }
    expect(
      () => DemoReportLink.encode('demo/correo@privado'),
      throwsFormatException,
    );
  });

  testWidgets(
    'visitante copia enlace, vuelve y lo abre sin acceso ni acciones privadas',
    (tester) async {
      final services = PrototypeServices.memory();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        ReporteCiudadanoApp(
          repository: DemoReportRepository(),
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Bache en el pasaje comunitario'));
      await tapVisible(tester, find.text('Lectura pública y enlace · demo'));
      expect(find.text('Confirmar que sigue ocurriendo'), findsNothing);
      expect(find.text('Aportar comentario o evidencia'), findsNothing);
      await tapVisible(tester, find.text('Copiar enlace de demostración'));
      expect(copied, DemoReportLink.encode('1'));
      expect(services.session.current, isNull);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Abrir enlace de demostración'));
      await tester.enterText(find.byKey(const Key('demo-link-input')), copied!);
      await tapVisible(tester, find.text('Abrir lectura pública'));
      expect(find.text('Bache en el pasaje comunitario'), findsOneWidget);
      await tapVisible(tester, find.text('Abrir en la aplicación'));
      expect(find.text('Confirmar que sigue ocurriendo'), findsOneWidget);
      expect(services.session.current, isNull);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );

  testWidgets(
    'lectura compartida conserva versión aprobada y retira contenido al ocultar',
    (tester) async {
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.email, 'Alias ficticio');
      final first = await services.submissions.submit(
        valid(services).copyWith(photos: ['FOTO APROBADA']),
      );
      services.session.enterModerationScenario();
      await services.submissions.review(
        first.id,
        ReviewStatus.approved,
        'MOTIVO PRIVADO',
      );
      final mgmt = await services.followUp.createManagement(first.id);
      await services.followUp.submitManagement(
        mgmt.copyWith(
          publicSummary: mgmt.publicSummary.copyWith(
            recipient: 'Entidad ficticia',
            action: 'Gestión ficticia',
            summary: 'GESTIÓN PÚBLICA',
          ),
          notes: 'NOTA PRIVADA',
          responsible: 'RESPONSABLE PRIVADO',
          privateDocuments: ['ARCHIVO PRIVADO'],
        ),
      );
      await services.followUp.reviewManagement(
        mgmt.id,
        ReviewStatus.approved,
        'DECISIÓN PRIVADA',
      );
      await services.session.signIn(DemoProvider.email, 'Alias ficticio');
      final edit = await services.submissions.startRevision(first.id);
      await services.submissions.submit(
        edit.copyWith(
          title: 'TÍTULO PENDIENTE PRIVADO',
          photos: ['FOTO PENDIENTE'],
        ),
      );
      final public = ModeratedReportRepository(
        DemoReportRepository(),
        services.submissions,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReportDetailPage(
            repository: public,
            reportId: first.id,
            publicReading: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bache ficticio en el pasaje'), findsOneWidget);
      expect(find.textContaining('FOTO APROBADA'), findsOneWidget);
      expect(find.textContaining('GESTIÓN PÚBLICA'), findsOneWidget);
      for (final private in [
        'PENDIENTE',
        'NOTA PRIVADA',
        'RESPONSABLE PRIVADO',
        'ARCHIVO PRIVADO',
        'MOTIVO PRIVADO',
        'DECISIÓN PRIVADA',
      ]) {
        expect(find.textContaining(private), findsNothing);
      }
      services.session.enterModerationScenario();
      await services.submissions.setDisposition(
        first.id,
        PublicDisposition.hidden,
        'MOTIVO OCULTAMIENTO',
      );
      await tester.pumpAndSettle();
      expect(find.text('Reporte oculto'), findsOneWidget);
      expect(find.text('Bache ficticio en el pasaje'), findsNothing);
      expect(find.textContaining('FOTO APROBADA'), findsNothing);
      expect(find.textContaining('GESTIÓN PÚBLICA'), findsNothing);
      expect(find.text('Copiar enlace de demostración'), findsNothing);
      expect(find.textContaining('MOTIVO OCULTAMIENTO'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      public.dispose();
      services.dispose();
    },
  );

  testWidgets(
    'duplicado abre principal público y elimina el enlace cuando se oculta el principal',
    (tester) async {
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.email, 'Alias ficticio');
      final first = await services.submissions.submit(valid(services));
      final second = await services.submissions.submit(
        valid(services).copyWith(title: 'Reporte principal ficticio'),
      );
      services.session.enterModerationScenario();
      for (final item in [first, second]) {
        await services.submissions.review(
          item.id,
          ReviewStatus.approved,
          'Apto',
        );
      }
      await services.submissions.setDisposition(
        first.id,
        PublicDisposition.duplicate,
        'Duplicado',
        duplicateOf: second.id,
      );
      final public = ModeratedReportRepository(
        DemoReportRepository(),
        services.submissions,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReportDetailPage(
            repository: public,
            reportId: first.id,
            publicReading: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reporte duplicado'), findsOneWidget);
      expect(find.text('Bache ficticio en el pasaje'), findsNothing);
      await tapVisible(tester, find.text('Ver reporte principal'));
      expect(find.text('Reporte principal ficticio'), findsOneWidget);
      expect(find.text('Lectura pública · demo'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await services.submissions.setDisposition(
        second.id,
        PublicDisposition.hidden,
        'Principal oculto',
      );
      await tester.pumpAndSettle();
      expect(find.text('Ver reporte principal'), findsNothing);
      expect(find.text('Reporte duplicado'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      public.dispose();
      services.dispose();
    },
  );

  testWidgets(
    'pendiente e inexistente no revelan contenido; catálogo muestra estados públicos',
    (tester) async {
      for (final pair in [
        ('5', 'Reporte no disponible'),
        ('inexistente', 'Reporte no disponible'),
        ('7', 'Reporte oculto'),
        ('8', 'Reporte duplicado'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: ReportDetailPage(
              repository: DemoReportRepository(),
              reportId: pair.$1,
              publicReading: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(pair.$2), findsOneWidget);
        expect(find.text('Copiar enlace de demostración'), findsNothing);
        expect(find.textContaining('Basura pendiente'), findsNothing);
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReportDetailPage(
            repository: DemoReportRepository(),
            reportId: '9',
            publicReading: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Autor anónimo'), findsOneWidget);
      expect(find.textContaining('Vecina de demostración'), findsNothing);
    },
  );

  testWidgets(
    'lectura pública no marca avisos como leídos ni modifica seguimiento de la sesión',
    (tester) async {
      final services = PrototypeServices.memory();
      await services.session.signIn(DemoProvider.email, 'Alias ficticio');
      await services.community.follow('1', true);
      services.session.enterModerationScenario();
      final draft = await services.followUp.createManagement('1');
      await services.followUp.submitManagement(
        draft.copyWith(
          publicSummary: draft.publicSummary.copyWith(
            recipient: 'Entidad ficticia',
            action: 'Acción ficticia',
            summary: 'Gestión ficticia para seguidores',
          ),
        ),
      );
      await services.followUp.reviewManagement(
        draft.id,
        ReviewStatus.approved,
        'Resumen apto',
      );
      await services.session.signIn(DemoProvider.email, 'Alias ficticio');
      expect((await services.community.inbox()).single.read, isFalse);
      await tester.pumpWidget(
        ReporteCiudadanoApp(
          repository: DemoReportRepository(),
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byTooltip('Abrir enlace de demostración'));
      await tapVisible(tester, find.text('Probar reporte de ejemplo'));
      expect((await services.community.inbox()).single.read, isFalse);
      expect(services.community.isFollowing('1'), isTrue);
      expect(find.text('Confirmar que sigue ocurriendo'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      services.dispose();
    },
  );

  testWidgets(
    'error de lectura reintenta; copiar falla sin éxito falso y comprueba disponibilidad',
    (tester) async {
      final repo = _FailingRepository();
      var copies = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copies++;
            throw PlatformException(code: 'clipboard');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: ReportDetailPage(
            repository: repo,
            reportId: '1',
            publicReading: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No pudimos cargar el reporte'), findsOneWidget);
      repo.fail = false;
      await tapVisible(tester, find.text('Reintentar'));
      await tapVisible(tester, find.text('Copiar enlace de demostración'));
      expect(
        find.text('No se pudo copiar el enlace. Reintenta.'),
        findsOneWidget,
      );
      repo.delayed = Completer<Report?>();
      await tester.tap(find.text('Copiar enlace de demostración'));
      await tester.pump();
      repo.refresh();
      repo.delayed!.complete(null);
      await tester.pumpAndSettle();
      expect(copies, 1);
      expect(find.text('Reporte no disponible'), findsOneWidget);
      expect(
        find.textContaining('Enlace de demostración copiado'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );

  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'lectura y entrada de enlace al 200 %, teclado y áreas seguras en $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetPadding);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: OpenDemoLinkPage(repository: DemoReportRepository()),
          ),
        );
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.enterText(
          find.byKey(const Key('demo-link-input')),
          'https://ejemplo.com/privado',
        );
        await tapVisible(tester, find.text('Abrir lectura pública'));
        expect(
          find.textContaining('Pega un enlace de demostración generado'),
          findsOneWidget,
        );
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tapVisible(tester, find.text('Probar reporte de ejemplo'));
        await tester.ensureVisible(find.text('Historial'));
        await tester.pumpAndSettle();
        expect(find.text('Sin foto adjunta'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
