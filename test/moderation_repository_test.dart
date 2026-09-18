import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/data/moderated_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/submissions/data/local_submission_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/find_matches.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/submission.dart';
import 'package:reporte_ciudadano/features/submissions/domain/submission_repository.dart';

class _Storage extends MemoryDraftStorage {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Disco no disponible');
    await super.write(value);
  }
}

void main() {
  late DemoSessionRepository session;
  late _Storage storage;
  late LocalSubmissionRepository repository;
  late ModeratedReportRepository public;
  final now = DateTime.utc(2026, 9, 16, 16);
  Future<void> author() =>
      session.signIn(DemoProvider.email, 'Vecina ficticia');
  ReportDraft valid() => repository.createDraft().copyWith(
    category: 'Baches y calzada',
    title: 'Bache ficticio en el pasaje',
    description: 'Una descripción de demostración para revisar el problema.',
    latitude: '-16.5000',
    longitude: '-68.1600',
    cityConfirmed: true,
    photos: ['Foto anterior simulada'],
  );
  Future<ReportSubmission> publish() async {
    await author();
    final item = await repository.submit(valid());
    session.enterModerationScenario();
    await repository.review(
      item.id,
      ReviewStatus.approved,
      'Contenido revisado',
    );
    return item;
  }

  setUp(() async {
    session = DemoSessionRepository();
    storage = _Storage();
    repository = LocalSubmissionRepository(
      session: session,
      storage: storage,
      clock: () => now,
    );
    public = ModeratedReportRepository(DemoReportRepository(), repository);
    await author();
  });
  tearDown(() {
    public.dispose();
    repository.dispose();
    session.dispose();
  });

  test('aprobación oculta no inventa una fecha de publicación', () async {
    final item = await repository.submit(valid());
    session.enterModerationScenario();
    await repository.setDisposition(
      item.id,
      PublicDisposition.hidden,
      'Revisar exposición',
    );
    await repository.review(
      item.id,
      ReviewStatus.approved,
      'Contenido aprobado',
    );
    expect(repository.reviewRecord(item.id).firstPublishedAt, isNull);
    expect(await public.getPublicReport(item.id), isNull);
    await repository.setDisposition(
      item.id,
      PublicDisposition.visible,
      'Exposición revisada',
    );
    expect((await public.getPublicReport(item.id))!.publishedAt, now);
  });

  test('corrección privada, reenvío idempotente y aprobación publican un solo reporte', () async {
    final first = await repository.submit(valid());
    expect(await public.getPublicReport(first.reportId), isNull);
    session.enterModerationScenario();
    await repository.review(
      first.id,
      ReviewStatus.correctionRequested,
      'Aclara la referencia ficticia',
    );
    await author();
    expect(
      repository.ownSubmission(first.id)!.decision!.reason,
      'Aclara la referencia ficticia',
    );
    final draft = await repository.startRevision(first.id);
    expect((await repository.startRevision(first.id)).id, draft.id);
    final corrected = draft.copyWith(reference: 'Referencia corregida');
    final results = await Future.wait([
      repository.submit(corrected),
      repository.submit(corrected),
    ]);
    expect(results.map((s) => s.id).toSet(), hasLength(1));
    expect(repository.ownSubmissions, hasLength(1));
    session.enterModerationScenario();
    expect(repository.reviewQueue.single.id, draft.id);
    await repository.review(
      draft.id,
      ReviewStatus.approved,
      'Corrección suficiente',
    );
    session.signOut();
    final report = (await public.getPublicReport(first.reportId))!;
    expect(report.reference, 'Referencia corregida');
    expect(report.pendingRevision, isNull);
    expect(report.tracking, TrackingStatus.reported);
    expect(report.observedAt, first.draft.observedAt);
    expect(
      (await public.listPublicReports()).where((r) => r.id == first.reportId),
      hasLength(1),
    );
    expect(
      report.history.single.text,
      isNot(contains('Corrección suficiente')),
    );
  });

  test(
    'edición pendiente conserva todos los campos y adjuntos aprobados',
    () async {
      final first = await publish();
      final before = (await public.getPublicReport(first.id))!;
      await author();
      final draft = (await repository.startRevision(first.id)).copyWith(
        title: 'Título de edición privada',
        description: 'Descripción privada pendiente con cambios relevantes.',
        photos: ['Foto privada nueva'],
        category: 'Alumbrado',
        latitude: '-16.6',
        reference: 'Referencia privada',
      );
      await repository.submit(draft);
      var report = (await public.getPublicReport(first.id))!;
      expect(report.publicRevision!.title, before.publicRevision!.title);
      expect(report.publicRevision!.demoAttachments, [
        'Foto anterior simulada',
      ]);
      expect(report.category, before.category);
      expect(report.reference, before.reference);
      session.enterModerationScenario();
      await repository.review(
        draft.id,
        ReviewStatus.approved,
        'Edición revisada',
      );
      report = (await public.getPublicReport(first.id))!;
      expect(report.publicRevision!.title, draft.title);
      expect(report.publicRevision!.demoAttachments, ['Foto privada nueva']);
      expect(report.category, 'Alumbrado');
      expect(report.publishedAt, before.publishedAt);
      expect(await public.getPublicReport(draft.id), isNull);
    },
  );

  test('ocultar retira detalle, lista, medios y coincidencias; aprobar no restaura', () async {
    final first = await publish();
    await author();
    final draft = await repository.startRevision(first.id);
    await repository.submit(draft);
    session.enterModerationScenario();
    await repository.setDisposition(
      first.id,
      PublicDisposition.hidden,
      'Privacidad',
    );
    await repository.review(
      draft.id,
      ReviewStatus.approved,
      'Versión revisada',
    );
    expect(await public.getPublicReport(first.id), isNull);
    expect(
      (await public.listPublicReports()).any((r) => r.id == first.id),
      isFalse,
    );
    expect(
      (await findPublicMatches(
        public,
        first.draft,
        repository.rules,
      )).any((r) => r.id == first.id),
      isFalse,
    );
    expect(
      public.publicNotice(first.id)!.disposition,
      PublicDisposition.hidden,
    );
    expect(repository.reviewRecord(first.id).history, hasLength(3));
    await repository.setDisposition(
      first.id,
      PublicDisposition.visible,
      'Revisión de privacidad completada',
    );
    expect(await public.getPublicReport(first.id), isNotNull);
    expect(
      (await findPublicMatches(
        public,
        draft,
        repository.rules,
      )).any((r) => r.id == first.id),
      isFalse,
    );
  });

  test(
    'rechazo de edición conserva versión anterior y motivo solo para autor',
    () async {
      final first = await publish();
      await author();
      final draft = (await repository.startRevision(first.id))
          .copyWith(title: 'Título que será rechazado');
      await repository.submit(draft);
      session.enterModerationScenario();
      await repository.review(
        draft.id,
        ReviewStatus.rejected,
        'Motivo privado de rechazo',
      );
      expect(
        (await public.getPublicReport(first.id))!.publicRevision!.title,
        first.draft.title,
      );
      await session.signIn(DemoProvider.google, 'Otro vecino');
      expect(repository.ownSubmission(draft.id), isNull);
      expect(repository.ownSubmissions, isEmpty);
      expect(repository.ownVersions(first.id), isEmpty);
      expect(() => repository.reviewQueue, throwsStateError);
      expect(() => repository.reviewRecord(first.id), throwsStateError);
      await author();
      expect(
        repository.ownSubmission(draft.id)!.decision!.reason,
        'Motivo privado de rechazo',
      );
      expect(repository.ownVersions(first.id), hasLength(2));
      expect(
        (await repository.startRevision(draft.id)).baseRevisionId,
        draft.id,
      );
    },
  );

  test(
    'visitante y ciudadano no revisan ni se asignan la identidad moderadora',
    () async {
      final item = await repository.submit(valid());
      await expectLater(
        repository.review(item.id, ReviewStatus.approved, 'Intento propio'),
        throwsStateError,
      );
      await expectLater(
        repository.setDisposition(item.id, PublicDisposition.hidden, 'Intento'),
        throwsStateError,
      );
      session.signOut();
      await expectLater(
        repository.review(item.id, ReviewStatus.approved, 'Intento visitante'),
        throwsStateError,
      );
      expect(public.publicNotice(item.id), isNull);
      session.enterModerationScenario();
      expect(session.current!.id, isNot(item.draft.ownerId));
      expect(() => repository.createDraft(), throwsStateError);
      await expectLater(
        repository.review(item.id, ReviewStatus.approved, ' '),
        throwsArgumentError,
      );
    },
  );

  test('decisiones serializadas, versión obsoleta y fallo de disco no publican parcialmente', () async {
    final item = await repository.submit(valid());
    session.enterModerationScenario();
    storage.fail = true;
    await expectLater(
      repository.review(item.id, ReviewStatus.approved, 'Revisado'),
      throwsStateError,
    );
    expect(repository.reviewQueue.single.status, ReviewStatus.pending);
    expect(repository.reviewRecord(item.id).history, isEmpty);
    expect(await public.getPublicReport(item.id), isNull);
    storage.fail = false;
    final first = repository.review(
      item.id,
      ReviewStatus.approved,
      'Primera decisión',
    );
    final second = repository.review(
      item.id,
      ReviewStatus.rejected,
      'Segunda decisión',
    );
    await expectLater(second, throwsStateError);
    await first;
    expect(repository.reviewRecord(item.id).history, hasLength(1));
    await author();
    final edit = await repository.startRevision(item.id);
    await repository.submit(edit);
    await expectLater(repository.startRevision(item.id), throwsStateError);
    await expectLater(
      repository.submit(edit.copyWith(id: 'otro-intento-obsoleto')),
      throwsStateError,
    );
  });

  test(
    'duplicado enlaza solo a principal público; ocultarlo retira el enlace',
    () async {
      final one = await publish();
      final two = await publish();
      await expectLater(
        repository.setDisposition(
          one.id,
          PublicDisposition.duplicate,
          'Duplicado',
          duplicateOf: one.id,
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.setDisposition(
          one.id,
          PublicDisposition.duplicate,
          'Duplicado',
          duplicateOf: 'inexistente',
        ),
        throwsArgumentError,
      );
      await repository.setDisposition(
        one.id,
        PublicDisposition.duplicate,
        'Mismo hecho ficticio',
        duplicateOf: two.id,
      );
      expect(await public.getPublicReport(one.id), isNull);
      expect(public.publicNotice(one.id)!.duplicateOf, two.id);
      await repository.setDisposition(
        two.id,
        PublicDisposition.hidden,
        'Revisar privacidad',
      );
      expect(public.publicNotice(one.id)!.duplicateOf, isNull);
      await expectLater(
        repository.setDisposition(
          two.id,
          PublicDisposition.duplicate,
          'Ciclo',
          duplicateOf: one.id,
        ),
        throwsArgumentError,
      );
      expect(repository.moderationReports, hasLength(2));
    },
  );

  test(
    'reinicio conserva versiones, motivos, ocultamiento y borrador de edición',
    () async {
      final first = await publish();
      await repository.setDisposition(
        first.id,
        PublicDisposition.hidden,
        'Motivo de ocultamiento',
      );
      await author();
      final draft = await repository.startRevision(first.id);
      final restored = LocalSubmissionRepository(
        session: session,
        storage: storage,
        clock: () => now,
      );
      await restored.load();
      expect(restored.ownDrafts.single.id, draft.id);
      expect(restored.ownSubmissions.single.status, ReviewStatus.approved);
      expect(restored.publishedReports, isEmpty);
      session.enterModerationScenario();
      expect(restored.reviewRecord(first.id).approvedRevisionId, first.id);
      expect(
        restored.reviewRecord(first.id).history.last.reason,
        'Motivo de ocultamiento',
      );
      restored.dispose();
    },
  );

  test(
    'migra datos de la segunda entrega sin perder claves ni pendientes',
    () async {
      final draft = valid();
      final item = ReportSubmission(
        draft: draft,
        alias: 'Alias anterior',
        sentAt: now,
      );
      storage.value = jsonEncode({
        'version': 1,
        'drafts': [],
        'submissions': [
          item.toJson()
            ..remove('status')
            ..remove('decision'),
        ],
      });
      await repository.load();
      expect(repository.ownSubmissions.single.id, draft.id);
      session.enterModerationScenario();
      await repository.review(
        draft.id,
        ReviewStatus.approved,
        'Revisión tras migrar',
      );
      expect((jsonDecode(storage.value!) as Map)['version'], 4);
      expect(await public.getPublicReport(draft.id), isNotNull);
    },
  );
}
