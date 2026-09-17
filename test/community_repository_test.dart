import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/features/community/domain/community.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/data/moderated_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';
import 'package:reporte_ciudadano/features/submissions/data/local_submission_repository.dart';
import 'package:reporte_ciudadano/features/submissions/domain/session_repository.dart';
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
  late LocalSubmissionRepository repo;
  late ModeratedReportRepository public;
  late _Storage storage;
  late DateTime now;
  Future<void> citizen([DemoProvider provider = DemoProvider.email]) => session.signIn(provider, 'Alias ficticio ${provider.name}');
  Future<String> publish() async {
    await citizen();
    final draft = repo.createDraft().copyWith(category: 'Baches y calzada', title: 'Problema ficticio persistente', description: 'Descripción ficticia para pruebas de participación ciudadana.', latitude: '-16.5000', longitude: '-68.1600', cityConfirmed: true);
    await repo.submit(draft);
    session.enterModerationScenario();
    await repo.review(draft.id, ReviewStatus.approved, 'Revisión ficticia');
    await citizen();
    return draft.id;
  }
  Future<Contribution> send(String reportId, {ContributionKind kind = ContributionKind.evidence, String body = 'Evidencia ficticia del problema urbano'}) async {
    final draft = (await repo.createContribution(reportId)).copyWith(body: body, kind: kind, photos: ['Adjunto privado simulado']);
    return repo.sendContribution(draft);
  }
  setUp(() {
    now = DateTime.utc(2026, 9, 17, 16);
    session = DemoSessionRepository(); storage = _Storage();
    repo = LocalSubmissionRepository(session: session, storage: storage, clock: () => now);
    public = ModeratedReportRepository(DemoReportRepository(), repo);
  });
  tearDown(() { public.dispose(); repo.dispose(); session.dispose(); });

  test('confirmación única excluye autor y notifica solo al cruzar umbral propuesto', () async {
    final id = await publish();
    final observed = (await public.getPublicReport(id))!.observedAt;
    await repo.follow(id, true);
    await repo.confirmObservation(id, now);
    expect((await public.getPublicReport(id))!.confirmations, 0);
    await citizen(DemoProvider.google);
    await Future.wait([repo.confirmObservation(id, now), repo.confirmObservation(id, now)]);
    now = now.add(const Duration(hours: 1));
    await repo.confirmObservation(id, now);
    expect((await public.getPublicReport(id))!.confirmations, 1);
    expect((await public.getPublicReport(id))!.lastCommunityObservedAt, now);
    await citizen();
    expect((await repo.inbox()).where((n) => !n.isPrivate), isEmpty);
    await citizen(DemoProvider.neighbor);
    await repo.confirmObservation(id, now);
    final report = (await public.getPublicReport(id))!;
    expect(report.confirmations, 2);
    expect(report.tracking, TrackingStatus.confirmed);
    expect(report.observedAt, observed);
    await repo.confirmObservation(id, now);
    await citizen();
    expect((await repo.inbox()).where((n) => !n.isPrivate), hasLength(1));
  });

  test('aporte pendiente privado, corrección, publicación y aviso son atómicos', () async {
    final id = await publish();
    await repo.follow(id, true);
    await citizen(DemoProvider.google);
    final first = await send(id);
    expect((await public.getPublicReport(id))!.updates, isEmpty);
    await citizen();
    expect(repo.ownContributions, isEmpty);
    expect((await repo.inbox()).where((n) => !n.isPrivate), isEmpty);
    session.enterModerationScenario();
    await repo.reviewContribution(first.id, ReviewStatus.correctionRequested, 'Aclara el punto');
    await citizen(DemoProvider.google);
    expect((await repo.inbox()).single.kind, NoticeKind.contributionReview);
    final draft = (await repo.createContribution(id, previousId: first.id)).copyWith(body: 'Aporte corregido y ficticio');
    await repo.sendContribution(draft);
    session.enterModerationScenario();
    await repo.reviewContribution(draft.id, ReviewStatus.approved, 'Motivo interno confidencial ficticio');
    final report = (await public.getPublicReport(id))!;
    expect(report.updates.single.text, contains('Aporte corregido'));
    expect(report.updates.single.text, contains('Adjunto privado simulado'));
    expect(report.updates.single.text, isNot(contains('Motivo interno')));
    expect(report.confirmations, 0);
    await citizen();
    expect((await repo.inbox()).where((n) => !n.isPrivate), hasLength(1));
    expect(repo.ownContributionVersions(first.draft.group), isEmpty);
    await citizen(DemoProvider.google);
    expect(repo.ownContributionVersions(first.draft.group), hasLength(2));
  });

  test('edición pendiente y rechazada de aporte conserva texto y adjuntos públicos', () async {
    final id = await publish();
    await citizen(DemoProvider.google);
    final first = await send(id);
    session.enterModerationScenario();
    await repo.reviewContribution(first.id, ReviewStatus.approved, 'Aprobado');
    await citizen(DemoProvider.google);
    final edit = (await repo.createContribution(id, previousId: first.id)).copyWith(body: 'Texto privado nuevo', photos: ['Adjunto nuevo privado']);
    await repo.sendContribution(edit);
    expect((await public.getPublicReport(id))!.updates.single.text, isNot(contains('nuevo')));
    session.enterModerationScenario();
    await repo.reviewContribution(edit.id, ReviewStatus.rejected, 'Motivo privado');
    expect((await public.getPublicReport(id))!.updates.single.text, contains(first.draft.body));
    await citizen(DemoProvider.google);
    await expectLater(repo.createContribution(id, previousId: first.id), throwsStateError);
    final revised = await repo.createContribution(id, previousId: edit.id);
    await repo.sendContribution(revised);
    session.enterModerationScenario();
    await repo.reviewContribution(revised.id, ReviewStatus.approved, 'Revisado');
    expect((await public.getPublicReport(id))!.updates.single.text, contains('Texto privado nuevo'));
  });

  test('ocultamiento retira aportes, conteos, seguimientos y avisos públicos', () async {
    final id = await publish();
    await repo.follow(id, true);
    await citizen(DemoProvider.google);
    await repo.confirmObservation(id, now);
    final contribution = await send(id);
    session.enterModerationScenario();
    await repo.reviewContribution(contribution.id, ReviewStatus.approved, 'Revisado');
    await repo.setDisposition(id, PublicDisposition.hidden, 'Privacidad');
    expect(await public.getPublicReport(id), isNull);
    expect((await public.listPublicReports()).any((r) => r.id == id), isFalse);
    await citizen();
    expect(await repo.following(), isEmpty);
    expect((await repo.inbox()).where((n) => !n.isPrivate), isEmpty);
    await expectLater(repo.confirmObservation(id, now), throwsStateError);
    await expectLater(repo.createContribution(id), throwsStateError);
    expect((await repo.inbox()).every((n) => n.isPrivate), isTrue);
  });

  test('aprobar aporte con reporte oculto no envía aviso público ni lo restaura', () async {
    final id = await publish();
    await repo.follow(id, true);
    await citizen(DemoProvider.google);
    final item = await send(id);
    session.enterModerationScenario();
    await repo.setDisposition(id, PublicDisposition.hidden, 'Privacidad');
    await repo.reviewContribution(item.id, ReviewStatus.approved, 'Aprobado editorialmente');
    expect(await public.getPublicReport(id), isNull);
    await repo.setDisposition(id, PublicDisposition.visible, 'Restaurado');
    await citizen();
    expect((await repo.inbox()).where((n) => !n.isPrivate), isEmpty);
    expect((await public.getPublicReport(id))!.updates, hasLength(1));
  });

  test('comentarios optativos y agrupados, lectura y push rechazado no bloquean bandeja', () async {
    final id = await publish();
    await repo.follow(id, true);
    for (var i = 0; i < 3; i++) {
      if (i == 1) { await citizen(); await repo.savePreferences(const NoticePreferences(comments: true, pushDenied: true)); }
      await citizen(DemoProvider.google);
      final item = await send(id, kind: ContributionKind.comment, body: 'Comentario ficticio $i');
      session.enterModerationScenario();
      await repo.reviewContribution(item.id, ReviewStatus.approved, 'Revisado');
      await citizen();
      expect((await repo.inbox()).where((n) => n.kind == NoticeKind.comment), hasLength(i == 0 ? 0 : 1));
    }
    expect((await repo.following()).single.hasNews, isTrue);
    await repo.visitFollowed(id);
    expect((await repo.following()).single.hasNews, isFalse);
    expect((await repo.inbox()).where((n) => n.kind == NoticeKind.comment).single.read, isTrue);
    await repo.follow(id, false);
    expect(await repo.following(), isEmpty);
    expect((await repo.inbox()).where((n) => !n.isPrivate), isEmpty);
  });

  test('reintento con respuesta perdida y fallo de disco no duplican ni publican parcialmente', () async {
    final id = await publish();
    await repo.follow(id, true);
    await citizen(DemoProvider.google);
    final draft = (await repo.createContribution(id)).copyWith(kind: ContributionKind.evidence, body: 'Evidencia ficticia guardada');
    await expectLater(repo.sendContribution(draft, scenario: SendScenario.offline), throwsStateError);
    expect(repo.ownContributionDrafts.single.id, draft.id);
    await expectLater(repo.sendContribution(draft, scenario: SendScenario.lostResponse), throwsStateError);
    final sent = await repo.sendContribution(draft);
    expect(repo.ownContributions, hasLength(1));
    expect(repo.ownContributionDrafts, isEmpty);
    session.enterModerationScenario();
    storage.fail = true;
    await expectLater(repo.reviewContribution(sent.id, ReviewStatus.approved, 'Aprobado'), throwsStateError);
    expect(repo.contributionQueue.single.id, sent.id);
    expect((await public.getPublicReport(id))!.updates, isEmpty);
    storage.fail = false;
    await repo.reviewContribution(sent.id, ReviewStatus.approved, 'Aprobado');
    await expectLater(repo.reviewContribution(sent.id, ReviewStatus.rejected, 'Rechazado'), throwsStateError);
    await citizen();
    expect((await repo.inbox()).where((n) => !n.isPrivate), hasLength(1));
  });

  test('persistencia v3 conserva cuentas, observaciones, borradores y avisos', () async {
    final id = await publish();
    await repo.follow(id, true);
    await repo.savePreferences(const NoticePreferences(comments: true));
    await citizen(DemoProvider.google);
    await repo.confirmObservation(id, now);
    final draft = (await repo.createContribution(id)).copyWith(body: 'Borrador ficticio conservado');
    await repo.saveContributionDraft(draft);
    final reopened = LocalSubmissionRepository(session: session, storage: storage, clock: () => now);
    await reopened.load();
    expect(reopened.ownObservation(id)!.at, now);
    expect(reopened.ownContributionDrafts.single.body, draft.body);
    await citizen();
    expect(reopened.ownContributionDrafts, isEmpty);
    expect(reopened.preferences.comments, isTrue);
    expect((await reopened.following()).single.report.confirmations, 1);
    expect((await reopened.inbox()).single.kind, NoticeKind.reportReview);
    reopened.dispose();
  });

  test('migración v2 conserva publicaciones y añade comunidad vacía', () async {
    final id = await publish();
    final old = jsonDecode(storage.value!) as Map<String, dynamic>;
    old['version'] = 2; old.remove('community'); storage.value = jsonEncode(old);
    final reopened = LocalSubmissionRepository(session: session, storage: storage, clock: () => now);
    await reopened.load();
    expect(reopened.publishedReports.single.id, id);
    expect(await reopened.inbox(), isEmpty);
    await reopened.follow(id, true);
    expect((jsonDecode(storage.value!) as Map)['version'], 3);
    reopened.dispose();
  });

  test('visitante y moderador no participan; futuro y motivo vacío se rechazan', () async {
    final id = await publish();
    await expectLater(repo.confirmObservation(id, now.add(const Duration(days: 1))), throwsArgumentError);
    final item = await send(id);
    await expectLater(repo.reviewContribution(item.id, ReviewStatus.approved, 'Propio'), throwsStateError);
    session.signOut();
    expect(repo.ownContributions, isEmpty);
    expect(await repo.inbox(), isEmpty);
    await expectLater(repo.follow(id, true), throwsStateError);
    session.enterModerationScenario();
    await expectLater(repo.confirmObservation(id, now), throwsStateError);
    await expectLater(repo.reviewContribution(item.id, ReviewStatus.approved, ' '), throwsArgumentError);
  });

  test('confirmaciones del catálogo no degradan solución verificada', () async {
    await citizen();
    await repo.confirmObservation('4', now);
    expect((await public.getPublicReport('4'))!.tracking, TrackingStatus.verified);
    await repo.follow('4', true);
    expect((await repo.following()).single.report.id, '4');
  });

  test('edición de reporte solo avisa al aprobar; aviso privado conserva destinatario', () async {
    final id = await publish();
    await citizen(DemoProvider.google); await repo.follow(id, true);
    await citizen();
    final edit = await repo.startRevision(id); await repo.submit(edit);
    await citizen(DemoProvider.google); expect(await repo.inbox(), isEmpty);
    session.enterModerationScenario(); await repo.review(edit.id, ReviewStatus.approved, 'Motivo reservado');
    await citizen(DemoProvider.google);
    final notices = await repo.inbox();
    expect(notices, hasLength(1)); expect(notices.single.isPrivate, isFalse);
    expect(notices.single.label, isNot(contains('Motivo reservado')));
    await citizen(); expect((await repo.inbox()).where((n) => n.targetId == edit.id).single.isPrivate, isTrue);
  });
}
