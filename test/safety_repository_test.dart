import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/features/community/domain/community.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/data/moderated_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/safety/domain/safety_repository.dart';
import 'package:reporte_ciudadano/features/submissions/data/local_submission_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/submission_repository.dart';

class _Storage extends MemoryDraftStorage {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) throw StateError('Fallo local');
    await super.write(value);
  }
}

void main() {
  late DemoSessionRepository session;
  late LocalSubmissionRepository repo;
  late ModeratedReportRepository public;
  late _Storage storage;
  Future<void> author() => session.signIn(DemoProvider.email, 'Alias anterior');
  Future<void> other() => session.signIn(DemoProvider.google, 'Otro vecino');
  Future<String> publish() async {
    await author();
    final draft = repo.createDraft().copyWith(
      category: 'Baches y calzada',
      title: 'Reporte ficticio de privacidad',
      description:
          'Descripción ficticia sin información personal para revisar.',
      latitude: '-16.5',
      longitude: '-68.16',
      cityConfirmed: true,
      photos: ['Foto simulada aprobada'],
    );
    await repo.submit(draft);
    session.enterModerationScenario();
    await repo.review(draft.id, ReviewStatus.approved, 'Apto');
    await author();
    return draft.id;
  }

  setUp(() {
    session = DemoSessionRepository();
    storage = _Storage();
    repo = LocalSubmissionRepository(session: session, storage: storage);
    public = ModeratedReportRepository(DemoReportRepository(), repo);
  });
  tearDown(() {
    public.dispose();
    repo.dispose();
    session.dispose();
  });

  test('retiro anonimiza reporte y aportes propios, conserva terceros y futuras revisiones', () async {
    final id = await publish();
    final own = await repo.sendContribution(
      (await repo.createContribution(id)).copyWith(
        body: 'Comentario propio ficticio',
        kind: ContributionKind.comment,
      ),
    );
    await other();
    final third = await repo.sendContribution(
      (await repo.createContribution(id))
          .copyWith(body: 'Comentario de otro vecino'),
    );
    session.enterModerationScenario();
    for (final c in [own, third]) {
      await repo.reviewContribution(c.id, ReviewStatus.approved, 'Apto');
    }
    await author();
    await repo.follow(id, true);
    final edit = await repo.startRevision(id);
    await repo.submit(edit.copyWith(title: 'Edición pendiente del reporte'));
    await repo.withdrawAuthorship(id);
    var report = (await public.getPublicReport(id))!;
    expect(report.authorAlias, 'Autor anónimo');
    expect(report.comments.first.text, startsWith('Autor anónimo'));
    expect(report.comments.last.text, startsWith('Otro vecino'));
    expect(report.publicRevision!.demoAttachments, ['Foto simulada aprobada']);
    expect(report.publicRevision!.title, 'Reporte ficticio de privacidad');
    expect((await repo.following()).single.report.authorAlias, 'Autor anónimo');
    expect(
      (await public.listPublicReports())
          .firstWhere((r) => r.id == id)
          .authorAlias,
      'Autor anónimo',
    );
    session.enterModerationScenario();
    await repo.review(edit.id, ReviewStatus.approved, 'Nueva revisión');
    report = (await public.getPublicReport(id))!;
    expect(report.authorAlias, 'Autor anónimo');
    expect(report.publicRevision!.title, 'Edición pendiente del reporte');
    await author();
    final next = await repo.sendContribution(
      (await repo.createContribution(id))
          .copyWith(body: 'Aporte posterior al retiro'),
    );
    session.enterModerationScenario();
    await repo.reviewContribution(next.id, ReviewStatus.approved, 'Apto');
    expect(
      (await public.getPublicReport(id))!.comments.map((e) => e.text).join(),
      isNot(contains('Alias anterior')),
    );
  });

  test('retiro requiere autor y publicación; es idempotente y no cambia visibilidad', () async {
    final id = await publish();
    await other();
    expect(repo.canWithdrawAuthorship(id), isFalse);
    await expectLater(repo.withdrawAuthorship(id), throwsStateError);
    session.enterModerationScenario();
    await expectLater(repo.withdrawAuthorship(id), throwsStateError);
    await repo.setDisposition(id, PublicDisposition.hidden, 'Oculto');
    await author();
    await Future.wait([
      repo.withdrawAuthorship(id),
      repo.withdrawAuthorship(id),
    ]);
    expect(repo.ownAuthorshipWithdrawn(id), isTrue);
    expect(repo.canWithdrawAuthorship(id), isFalse);
    expect(await public.getPublicReport(id), isNull);
    final version = repo.publicVersion;
    await repo.withdrawAuthorship(id);
    expect(repo.publicVersion, version);
    session.enterModerationScenario();
    await repo.setDisposition(id, PublicDisposition.visible, 'Restaurado');
    expect((await public.getPublicReport(id))!.authorAlias, 'Autor anónimo');
    await author();
    final pending = repo.createDraft();
    await expectLater(repo.withdrawAuthorship(pending.id), throwsStateError);
  });

  test('fallo de guardado no anonimiza parcialmente y el retiro persiste tras reinicio', () async {
    final id = await publish();
    final version = repo.publicVersion;
    storage.fail = true;
    await expectLater(repo.withdrawAuthorship(id), throwsStateError);
    expect(repo.publicVersion, version);
    expect((await public.getPublicReport(id))!.authorAlias, 'Alias anterior');
    storage.fail = false;
    await repo.withdrawAuthorship(id);
    final restored = LocalSubmissionRepository(
      session: session,
      storage: storage,
    );
    await restored.load();
    expect(restored.ownAuthorshipWithdrawn(id), isTrue);
    expect(restored.publishedReports.single.authorAlias, 'Autor anónimo');
    restored.dispose();
  });

  test('denuncias privadas, respuesta perdida idempotente y revisión sin avisos públicos', () async {
    final id = await publish();
    final complaint = repo
        .createComplaint(id)
        .copyWith(details: 'DETALLE PRIVADO');
    await expectLater(
      repo.submitComplaint(complaint, scenario: SendScenario.offline),
      throwsStateError,
    );
    expect(repo.ownComplaints, isEmpty);
    await expectLater(
      repo.submitComplaint(complaint, scenario: SendScenario.lostResponse),
      throwsStateError,
    );
    await repo.submitComplaint(complaint);
    expect(repo.ownComplaints, hasLength(1));
    await other();
    expect(repo.ownComplaints, isEmpty);
    expect(() => repo.complaintsForReview, throwsStateError);
    await expectLater(repo.submitComplaint(complaint), throwsStateError);
    session.enterModerationScenario();
    expect(repo.complaintsForReview.single.details, 'DETALLE PRIVADO');
    await repo.resolveComplaint(complaint.id, 'MOTIVO INTERNO');
    await author();
    expect(repo.ownComplaints.single.decision!.reason, isEmpty);
    expect(repo.ownComplaints.single.decision!.actor, isEmpty);
    expect((await repo.inbox()).where((notice) => !notice.isPrivate), isEmpty);
    expect((await public.getPublicReport(id))!.comments, isEmpty);
  });

  test('ocultar y resolver es atómico, retira seguimiento y protege decisión interna', () async {
    final id = await publish();
    await repo.follow(id, true);
    final c = repo.createComplaint(id);
    await repo.submitComplaint(c);
    session.enterModerationScenario();
    storage.fail = true;
    await expectLater(
      repo.resolveComplaint(c.id, 'Motivo', hideReport: true),
      throwsStateError,
    );
    expect(repo.complaintsForReview.single.decision, isNull);
    expect(await public.getPublicReport(id), isNotNull);
    storage.fail = false;
    await repo.resolveComplaint(c.id, 'MOTIVO PRIVADO', hideReport: true);
    expect(await public.getPublicReport(id), isNull);
    expect(public.publicNotice(id)!.disposition, PublicDisposition.hidden);
    expect(repo.complaintsForReview.single.decision, isNotNull);
    await expectLater(
      repo.resolveComplaint(c.id, 'Decisión repetida'),
      throwsStateError,
    );
    await author();
    expect(await repo.following(), isEmpty);
    expect(repo.ownComplaints.single.decision!.action, 'Revisión finalizada');
    final restored = LocalSubmissionRepository(
      session: session,
      storage: storage,
    );
    await restored.load();
    expect(restored.publishedReports, isEmpty);
    expect(restored.ownComplaints.single.decision, isNotNull);
    restored.dispose();
  });

  test(
    'catálogo permite recibir y revisar sin inventar capacidad de ocultarlo',
    () async {
      await author();
      final c = repo.createComplaint('1');
      await repo.submitComplaint(c);
      session.enterModerationScenario();
      expect(repo.canHideForComplaint('1'), isFalse);
      await expectLater(
        repo.resolveComplaint(c.id, 'Ocultar catálogo', hideReport: true),
        throwsStateError,
      );
      await repo.resolveComplaint(c.id, 'Revisión de ejemplo');
      expect(await public.getPublicReport('1'), isNotNull);
    },
  );

  test(
    'validación, aislamiento de pendientes y permisos de revisión',
    () async {
      final id = await publish();
      final c = repo
          .createComplaint(id)
          .copyWith(reason: ComplaintReason.other);
      await expectLater(repo.submitComplaint(c), throwsArgumentError);
      await expectLater(
        repo.submitComplaint(
          c.copyWith(details: 'x' * (repo.complaintTextMax + 1)),
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.submitComplaint(repo.createComplaint('5')),
        throwsStateError,
      );
      await repo.submitComplaint(c.copyWith(details: 'Otro motivo ficticio'));
      await expectLater(
        repo.resolveComplaint(c.id, 'Sin permiso'),
        throwsStateError,
      );
      session.enterModerationScenario();
      await expectLater(repo.resolveComplaint(c.id, ''), throwsArgumentError);
      session.signOut();
      expect(repo.ownComplaints, isEmpty);
      expect(() => repo.complaintsForReview, throwsStateError);
    },
  );

  test(
    'migración v4 conserva reporte y escribe v5 sin perder idempotencia',
    () async {
      final id = await publish();
      final json = jsonDecode(storage.value!) as Map<String, dynamic>;
      json['version'] = 4;
      json.remove('safety');
      await storage.write(jsonEncode(json));
      final restored = LocalSubmissionRepository(
        session: session,
        storage: storage,
      );
      await restored.load();
      expect(restored.publishedReports.single.id, id);
      final c = restored.createComplaint(id);
      await restored.submitComplaint(c);
      expect((jsonDecode(storage.value!) as Map)['version'], 5);
      final again = LocalSubmissionRepository(
        session: session,
        storage: storage,
      );
      await again.load();
      await again.submitComplaint(c);
      expect(again.ownComplaints, hasLength(1));
      again.dispose();
      restored.dispose();
    },
  );
}
