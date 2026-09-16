import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/core/geo_point.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/submissions/data/local_submission_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/find_matches.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/submission.dart';
import 'package:reporte_ciudadano/features/submissions/domain/submission_repository.dart';

class FailingStorage extends MemoryDraftStorage {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Disco no disponible');
    await super.write(value);
  }
}

void main() {
  final now = DateTime.utc(2026, 9, 15, 16);
  late DemoSessionRepository session;
  late FailingStorage storage;
  late LocalSubmissionRepository repository;
  ReportDraft valid() => repository.createDraft().copyWith(
    category: 'Baches y calzada',
    title: 'Bache ficticio en el pasaje',
    description:
        'Descripción ficticia de un problema persistente en el pasaje.',
    latitude: '-16.5000',
    longitude: '-68.1600',
    cityConfirmed: true,
    step: 2,
  );
  setUp(() async {
    session = DemoSessionRepository();
    storage = FailingStorage();
    repository = LocalSubmissionRepository(
      session: session,
      storage: storage,
      clock: () => now,
    );
    await session.signIn(DemoProvider.email, 'Vecina ficticia');
  });

  test(
    'borrador incompleto y paso se recuperan tras recrear el repositorio',
    () async {
      final draft = repository.createDraft().copyWith(
        title: 'Sin terminar',
        step: 1,
        photos: ['Galería simulada'],
      );
      await repository.saveDraft(draft);
      final reopened = LocalSubmissionRepository(
        session: session,
        storage: storage,
      );
      await reopened.load();
      expect(reopened.ownDrafts.single.toJson(), draft.toJson());
    },
  );

  test(
    'envío sin fotos queda pendiente privado y retira el borrador',
    () async {
      final public = DemoReportRepository();
      final before = await public.listPublicReports();
      final draft = valid();
      await repository.saveDraft(draft);
      final sent = await repository.submit(draft);
      expect(sent.draft.photos, isEmpty);
      expect(repository.ownDrafts, isEmpty);
      expect(repository.ownSubmissions.single.id, sent.id);
      expect(await public.getPublicReport(sent.id), isNull);
      expect(
        (await public.listPublicReports()).map((r) => r.id),
        before.map((r) => r.id),
      );
    },
  );

  test('desconexión y fallo guardan borrador; reintento no duplica', () async {
    final draft = valid();
    for (final scenario in [
      SendScenario.offline,
      SendScenario.failBeforeSend,
    ]) {
      await expectLater(
        repository.submit(draft, scenario: scenario),
        throwsStateError,
      );
      expect(repository.ownDrafts.single.id, draft.id);
      expect(repository.ownSubmissions, isEmpty);
    }
    final sent = await repository.submit(draft);
    expect((await repository.submit(draft)).id, sent.id);
    expect(repository.ownSubmissions, hasLength(1));
  });

  test(
    'respuesta perdida, reinicio y doble envío conservan misma identidad',
    () async {
      final draft = valid();
      await expectLater(
        repository.submit(draft, scenario: SendScenario.lostResponse),
        throwsStateError,
      );
      final reopened = LocalSubmissionRepository(
        session: session,
        storage: storage,
        clock: () => now,
      );
      await reopened.load();
      final receipts = await Future.wait([
        reopened.submit(draft),
        reopened.submit(draft),
      ]);
      expect(receipts.map((s) => s.id).toSet(), {draft.id});
      expect(reopened.ownSubmissions, hasLength(1));
      await reopened.saveDraft(draft);
      expect(reopened.ownDrafts, isEmpty);
    },
  );

  test(
    'sesiones separadas no leen, guardan, envían ni descartan datos ajenos',
    () async {
      final draft = valid();
      await repository.saveDraft(draft);
      final sent = await repository.submit(valid());
      session.signOut();
      expect(repository.ownDrafts, isEmpty);
      expect(repository.ownSubmissions, isEmpty);
      expect(repository.ownSubmission(sent.id), isNull);
      expect(repository.createDraft, throwsStateError);
      await session.signIn(DemoProvider.google, 'Otra vecina');
      await expectLater(repository.saveDraft(draft), throwsStateError);
      await expectLater(repository.submit(draft), throwsStateError);
      await expectLater(repository.discardDraft(draft.id), throwsStateError);
      await session.signIn(DemoProvider.email, 'Vecina ficticia');
      expect(repository.ownDrafts.single.id, draft.id);
      expect(repository.ownSubmissions.single.id, sent.id);
    },
  );

  test(
    'escrituras ordenadas, descarte y fallo de disco sin éxito aparente',
    () async {
      final draft = valid();
      await Future.wait([
        repository.saveDraft(draft.copyWith(title: 'Primera versión')),
        repository.saveDraft(draft.copyWith(title: 'Segunda versión')),
      ]);
      expect(repository.ownDrafts.single.title, 'Segunda versión');
      storage.fail = true;
      await expectLater(repository.submit(draft), throwsStateError);
      expect(repository.ownSubmissions, isEmpty);
      expect(repository.ownDrafts.single.title, 'Segunda versión');
      storage.fail = false;
      await repository.discardDraft(draft.id);
      final reopened = LocalSubmissionRepository(
        session: session,
        storage: storage,
      );
      await reopened.load();
      expect(reopened.ownDrafts, isEmpty);
    },
  );

  test(
    'datos corruptos no se reemplazan ni se borran automáticamente',
    () async {
      storage.value = '{malformado';
      await expectLater(repository.load(), throwsFormatException);
      expect(storage.value, '{malformado');
    },
  );

  test('validación de límites, coordenadas, ciudad, fecha y fotos', () async {
    final draft = valid();
    expect(repository.rules.validate(draft, now), isNull);
    for (final invalid in [
      draft.copyWith(title: 'Corto'),
      draft.copyWith(description: 'Corto'),
      draft.copyWith(category: ''),
      draft.copyWith(latitude: 'NaN'),
      draft.copyWith(longitude: '181'),
      draft.copyWith(cityConfirmed: false),
      draft.copyWith(observedAt: now.add(const Duration(minutes: 1))),
      draft.copyWith(reference: 'x' * 201),
      draft.copyWith(photos: List.filled(6, 'foto')),
    ]) {
      await expectLater(repository.submit(invalid), throwsArgumentError);
    }
    expect(repository.ownSubmissions, isEmpty);
  });

  test(
    'coincidencias públicas por categoría y radio, sin soluciones verificadas',
    () async {
      final public = DemoReportRepository();
      expect(
        (await findPublicMatches(
          public,
          valid(),
          repository.rules,
        )).map((r) => r.id),
        ['1'],
      );
      expect(
        await findPublicMatches(
          public,
          valid().copyWith(latitude: '-17'),
          repository.rules,
        ),
        isEmpty,
      );
      expect(
        await findPublicMatches(
          public,
          valid().copyWith(category: 'Basura'),
          repository.rules,
        ),
        isEmpty,
      );
      expect(
        (await findPublicMatches(
          public,
          valid().copyWith(category: 'Aceras y accesibilidad'),
          repository.rules,
        )).map((r) => r.id),
        ['2'],
      );
      expect(
        const GeoPoint(-16.5, -68.16).distanceTo(const GeoPoint(-16.5, -68.16)),
        0,
      );
    },
  );

  test('horario Bolivia admite cola fuera de 08–20, sin prometer plazo', () {
    expect(
      moderationMessage(DateTime.utc(2026, 9, 15, 11, 59)),
      contains('horario de atención'),
    );
    expect(
      moderationMessage(DateTime.utc(2026, 9, 15, 12)),
      contains('No hay un plazo'),
    );
    expect(
      moderationMessage(DateTime.utc(2026, 9, 16, 0)),
      contains('horario de atención'),
    );
  });
}
