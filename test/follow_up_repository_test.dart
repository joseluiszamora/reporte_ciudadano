import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/features/community/domain/community.dart';
import 'package:reporte_ciudadano/features/follow_up/domain/follow_up.dart';
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
  final now = DateTime.utc(2026, 9, 17, 16);
  Future<void> citizen([DemoProvider provider = DemoProvider.email]) =>
      session.signIn(provider, 'Alias ficticio ${provider.name}');
  Future<String> publish() async {
    await citizen();
    final draft = repo.createDraft().copyWith(
      category: 'Baches y calzada',
      title: 'Problema ficticio persistente',
      description: 'Descripción ficticia para pruebas de gestiones y solución.',
      latitude: '-16.5000',
      longitude: '-68.1600',
      cityConfirmed: true,
    );
    await repo.submit(draft);
    session.enterModerationScenario();
    await repo.review(draft.id, ReviewStatus.approved, 'Revisión ficticia');
    return draft.id;
  }

  Future<ManagementDraft> management(String id) async {
    session.enterModerationScenario();
    final draft = await repo.createManagement(id);
    return draft.copyWith(
      publicSummary: draft.publicSummary.copyWith(
        recipient: 'Junta ficticia del ejemplo',
        action: 'Entrega simulada',
        summary: 'Resumen seguro de la gestión',
        evidence: ['Evidencia pública simulada'],
        response: 'Trabajo anunciado ficticio',
      ),
      responsible: 'RESPONSABLE PRIVADO',
      notes: 'NOTAS PRIVADAS',
      privateDocuments: ['DOCUMENTO SIN DEPURAR'],
    );
  }

  Future<Contribution> send(
    String id,
    ContributionKind kind, {
    String? previousId,
  }) async {
    await citizen();
    final draft = (await repo.createContribution(id, previousId: previousId))
        .copyWith(
          kind: kind,
          body: '${kind.label}: explicación ficticia observada',
          photos: ['Evidencia de solución simulada'],
        );
    return repo.sendContribution(draft);
  }

  Future<Contribution> approveSolution(String id) async {
    final item = await send(id, ContributionKind.solution);
    session.enterModerationScenario();
    await repo.reviewContribution(
      item.id,
      ReviewStatus.approved,
      'MOTIVO INTERNO',
    );
    return item;
  }

  setUp(() {
    session = DemoSessionRepository();
    storage = _Storage();
    repo = LocalSubmissionRepository(
      session: session,
      storage: storage,
      clock: () => now,
    );
    public = ModeratedReportRepository(DemoReportRepository(), repo);
  });
  tearDown(() {
    public.dispose();
    repo.dispose();
    session.dispose();
  });

  test('gestión pendiente privada; aprobación publica solo resumen seguro y no soluciona', () async {
    final id = await publish();
    await citizen(DemoProvider.google);
    await repo.follow(id, true);
    final draft = await management(id);
    await repo.submitManagement(draft);
    expect((await public.getPublicReport(id))!.management, isEmpty);
    await citizen(DemoProvider.google);
    expect(await repo.inbox(), isEmpty);
    session.enterModerationScenario();
    await repo.reviewManagement(
      draft.id,
      ReviewStatus.approved,
      'MOTIVO INTERNO',
    );
    final report = (await public.getPublicReport(id))!;
    expect(report.tracking, TrackingStatus.reported);
    final text = report.management.single.text;
    expect(text, contains('Resumen seguro'));
    expect(text, contains('Evidencia pública'));
    for (final private in [
      'RESPONSABLE PRIVADO',
      'NOTAS PRIVADAS',
      'DOCUMENTO SIN DEPURAR',
      'MOTIVO INTERNO',
    ]) {
      expect(text, isNot(contains(private)));
    }
    await citizen(DemoProvider.google);
    expect((await repo.inbox()).single.kind, NoticeKind.management);
  });

  test('edición de gestión conserva texto y medios aprobados hasta nueva aprobación', () async {
    final id = await publish();
    final first = await management(id);
    await repo.submitManagement(first);
    await repo.reviewManagement(
      first.id,
      ReviewStatus.approved,
      'Primera decisión',
    );
    final edit = (await repo.createManagement(id, previousId: first.id))
        .copyWith(
          publicSummary: first.publicSummary.copyWith(
            summary: 'NUEVA REVISIÓN',
            evidence: ['NUEVO ADJUNTO'],
          ),
        );
    await repo.submitManagement(edit);
    expect(
      (await public.getPublicReport(id))!.management.single.text,
      isNot(contains('NUEVA')),
    );
    await repo.reviewManagement(
      edit.id,
      ReviewStatus.correctionRequested,
      'Aclarar respuesta',
    );
    final corrected = await repo.createManagement(id, previousId: edit.id);
    await repo.submitManagement(corrected);
    await repo.reviewManagement(
      corrected.id,
      ReviewStatus.approved,
      'Corregido',
    );
    final text = (await public.getPublicReport(id))!.management.single.text;
    expect(text, contains('NUEVA REVISIÓN'));
    expect(text, contains('NUEVO ADJUNTO'));
    expect(text, isNot(contains('Evidencia pública simulada')));
    expect(repo.managementEntries(id), hasLength(3));
    await expectLater(
      repo.createManagement(id, previousId: first.id),
      throwsStateError,
    );
  });

  test('reintentos sin duplicados; desconexión conserva borrador; fechas futuras rechazadas', () async {
    final id = await publish();
    final draft = await management(id);
    await expectLater(
      repo.submitManagement(
        draft.copyWith(
          publicSummary: draft.publicSummary.copyWith(
            occurredAt: now.add(const Duration(days: 1)),
          ),
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      repo.submitManagement(draft, scenario: SendScenario.offline),
      throwsStateError,
    );
    expect(repo.managementDrafts(id).single.id, draft.id);
    await expectLater(
      repo.submitManagement(draft, scenario: SendScenario.lostResponse),
      throwsStateError,
    );
    final retried = await repo.submitManagement(draft);
    expect(retried.id, draft.id);
    expect(repo.managementEntries(id), hasLength(1));
    expect(repo.managementDrafts(id), isEmpty);
  });

  test('rechazo conserva versión anterior y no emite aviso público', () async {
    final id = await publish();
    final first = await management(id);
    await repo.submitManagement(first);
    await repo.reviewManagement(first.id, ReviewStatus.approved, 'Seguro');
    await citizen(DemoProvider.google);
    await repo.follow(id, true);
    session.enterModerationScenario();
    final rejected = await repo.createManagement(id, previousId: first.id);
    await repo.submitManagement(rejected);
    await repo.reviewManagement(rejected.id, ReviewStatus.rejected, 'No apto');
    expect((await public.getPublicReport(id))!.management, hasLength(1));
    await citizen(DemoProvider.google);
    expect(await repo.inbox(), isEmpty);
  });

  test('aprobar solución no verifica; motivo y evidencia quedan auditados por separado', () async {
    final id = await publish();
    final item = await send(id, ContributionKind.solution);
    expect(
      (await public.getPublicReport(id))!.tracking,
      TrackingStatus.reported,
    );
    session.enterModerationScenario();
    await repo.reviewContribution(
      item.id,
      ReviewStatus.approved,
      'MOTIVO INTERNO',
    );
    final proposed = (await public.getPublicReport(id))!;
    expect(proposed.tracking, TrackingStatus.solutionReported);
    expect(proposed.updates.single.text, contains('Proponer solución'));
    expect(
      proposed.history.map((e) => e.text).join(),
      isNot(contains('MOTIVO INTERNO')),
    );
    await repo.verifySolution(
      id,
      expectedVersion: repo.resolutionForReview(id).version,
      reason: 'Se revisó la solución ficticia',
    );
    final verified = (await public.getPublicReport(id))!;
    expect(verified.tracking, TrackingStatus.verified);
    expect(
      verified.history.last.text,
      contains('Se revisó la solución ficticia'),
    );
    final record = repo.resolutionForReview(id);
    expect(record.candidateId, item.id);
    expect(record.history.last.actor, session.current!.alias);
    await expectLater(
      repo.verifySolution(
        id,
        expectedVersion: record.version,
        reason: 'Duplicada',
      ),
      throwsStateError,
    );
  });

  test('contradicción aprobada conserva estado y evidencia hasta reapertura motivada', () async {
    final id = await publish();
    await approveSolution(id);
    await repo.verifySolution(
      id,
      expectedVersion: repo.resolutionForReview(id).version,
      reason: 'Solución revisada',
    );
    final contradiction = await send(id, ContributionKind.contradiction);
    expect((await public.getPublicReport(id))!.solutionReviewRequired, isFalse);
    session.enterModerationScenario();
    await repo.reviewContribution(
      contradiction.id,
      ReviewStatus.approved,
      'Evidencia apta',
    );
    final before = (await public.getPublicReport(id))!;
    expect(before.tracking, TrackingStatus.verified);
    expect(before.solutionReviewRequired, isTrue);
    expect(before.updates, hasLength(2));
    final version = repo.resolutionForReview(id).version;
    await expectLater(
      repo.reopenReport(id, expectedVersion: version, reason: '  '),
      throwsArgumentError,
    );
    await repo.reopenReport(
      id,
      expectedVersion: version,
      reason: 'La solución anterior fue incorrecta',
    );
    final after = (await public.getPublicReport(id))!;
    expect(after.tracking, TrackingStatus.reported);
    expect(after.solutionReviewRequired, isFalse);
    expect(after.updates, hasLength(2));
    expect(
      after.history.last.text,
      contains('La solución anterior fue incorrecta'),
    );
  });

  test('contradicción bloquea verificar hasta resolución explícita; decisiones obsoletas fallan', () async {
    final id = await publish();
    await approveSolution(id);
    final old = repo.resolutionForReview(id).version;
    final contradictory = await send(id, ContributionKind.contradiction);
    session.enterModerationScenario();
    await repo.reviewContribution(
      contradictory.id,
      ReviewStatus.approved,
      'Apta',
    );
    await expectLater(
      repo.verifySolution(
        id,
        expectedVersion: old,
        reason: 'Decisión obsoleta',
      ),
      throwsStateError,
    );
    await expectLater(
      repo.verifySolution(
        id,
        expectedVersion: repo.resolutionForReview(id).version,
        reason: 'Sin revisar',
      ),
      throwsStateError,
    );
    await repo.keepResolution(
      id,
      expectedVersion: repo.resolutionForReview(id).version,
      reason: 'La evidencia corresponde a otra fecha',
    );
    final version = repo.resolutionForReview(id).version;
    await repo.verifySolution(
      id,
      expectedVersion: version,
      reason: 'Solución revisada',
    );
    await expectLater(
      repo.reopenReport(
        id,
        expectedVersion: version,
        reason: 'Acción concurrente',
      ),
      throwsStateError,
    );
    expect(
      (await public.getPublicReport(id))!.tracking,
      TrackingStatus.verified,
    );
  });

  test('edición de evidencia verificada abre revisión sin degradar ni cambiar de tipo', () async {
    final id = await publish();
    final original = await approveSolution(id);
    await repo.verifySolution(
      id,
      expectedVersion: repo.resolutionForReview(id).version,
      reason: 'Revisada',
    );
    await citizen();
    final draft = await repo.createContribution(id, previousId: original.id);
    await expectLater(
      repo.sendContribution(draft.copyWith(kind: ContributionKind.comment)),
      throwsArgumentError,
    );
    final edited = await repo.sendContribution(
      draft.copyWith(body: 'Explicación de solución ampliada'),
    );
    expect(
      (await public.getPublicReport(id))!.updates.single.text,
      isNot(contains('ampliada')),
    );
    session.enterModerationScenario();
    await repo.reviewContribution(
      edited.id,
      ReviewStatus.approved,
      'Edición apta',
    );
    expect(
      (await public.getPublicReport(id))!.tracking,
      TrackingStatus.verified,
    );
    expect(repo.resolutionForReview(id).reviewIds, [edited.id]);
    await repo.keepResolution(
      id,
      expectedVersion: repo.resolutionForReview(id).version,
      reason: 'Se revisó nuevamente y se conserva la solución',
    );
    expect(repo.resolutionForReview(id).candidateId, edited.id);
  });

  test(
    'reapertura conserva confirmaciones únicas y Siguiendo comparte el estado',
    () async {
      final id = await publish();
      for (final provider in [DemoProvider.google, DemoProvider.neighbor]) {
        await citizen(provider);
        await repo.confirmObservation(id, now);
      }
      await approveSolution(id);
      await repo.reopenReport(
        id,
        expectedVersion: repo.resolutionForReview(id).version,
        reason: 'Solución incorrecta',
      );
      await citizen();
      await repo.follow(id, true);
      expect(
        (await public.getPublicReport(id))!.tracking,
        TrackingStatus.confirmed,
      );
      expect(
        (await repo.following()).single.report.tracking,
        TrackingStatus.confirmed,
      );
      expect(
        (await public.listPublicReports())
            .firstWhere((r) => r.id == id)
            .confirmations,
        2,
      );
    },
  );

  test('ocultar impide exposición de gestiones, soluciones y avisos, incluso tras aprobación', () async {
    final id = await publish();
    await citizen(DemoProvider.google);
    await repo.follow(id, true);
    final item = await send(id, ContributionKind.solution);
    final draft = await management(id);
    await repo.submitManagement(draft);
    await repo.setDisposition(id, PublicDisposition.hidden, 'Retiro público');
    await repo.reviewManagement(draft.id, ReviewStatus.approved, 'Apta');
    await repo.reviewContribution(item.id, ReviewStatus.approved, 'Apta');
    await repo.verifySolution(
      id,
      expectedVersion: repo.resolutionForReview(id).version,
      reason: 'Revisión local de oculto',
    );
    expect(await public.getPublicReport(id), isNull);
    expect(
      (await repo.reportForFollowUp(id))!.disposition,
      PublicDisposition.hidden,
    );
    await citizen(DemoProvider.google);
    expect(await repo.inbox(), isEmpty);
    expect(await repo.following(), isEmpty);
    session.enterModerationScenario();
    await repo.setDisposition(id, PublicDisposition.visible, 'Restaurado');
    expect(
      (await public.getPublicReport(id))!.tracking,
      TrackingStatus.verified,
    );
    expect((await public.getPublicReport(id))!.management, hasLength(1));
  });

  test('fallo de almacenamiento no publica parcialmente gestión ni decisión ni notificación', () async {
    final id = await publish();
    await citizen(DemoProvider.google);
    await repo.follow(id, true);
    final draft = await management(id);
    await repo.submitManagement(draft);
    final saved = storage.value;
    storage.fail = true;
    await expectLater(
      repo.reviewManagement(draft.id, ReviewStatus.approved, 'Apta'),
      throwsStateError,
    );
    expect(storage.value, saved);
    expect(repo.managementEntries(id).single.status, ReviewStatus.pending);
    expect((await public.getPublicReport(id))!.management, isEmpty);
    storage.fail = false;
    await approveSolution(id);
    final version = repo.resolutionForReview(id).version;
    storage.fail = true;
    await expectLater(
      repo.verifySolution(id, expectedVersion: version, reason: 'Revisada'),
      throwsStateError,
    );
    expect(repo.resolutionForReview(id).version, version);
    expect(
      (await public.getPublicReport(id))!.tracking,
      TrackingStatus.solutionReported,
    );
    await citizen(DemoProvider.google);
    expect(
      (await repo.inbox()).where(
        (n) =>
            n.kind == NoticeKind.management || n.kind == NoticeKind.resolution,
      ),
      isEmpty,
    );
  });

  test(
    'roles no autorizados no consultan datos internos ni toman decisiones',
    () async {
      final id = await publish();
      final draft = await management(id);
      await repo.submitManagement(draft);
      await citizen();
      expect(() => repo.managementEntries(id), throwsStateError);
      expect(() => repo.managementDrafts(id), throwsStateError);
      expect(() => repo.resolutionForReview(id), throwsStateError);
      await expectLater(repo.reportsForFollowUp(), throwsStateError);
      await expectLater(
        repo.reviewManagement(draft.id, ReviewStatus.approved, 'No autorizado'),
        throwsStateError,
      );
      await expectLater(
        repo.verifySolution(id, expectedVersion: 0, reason: 'No autorizado'),
        throwsStateError,
      );
      session.signOut();
      await expectLater(repo.saveManagementDraft(draft), throwsStateError);
    },
  );

  test(
    'JSON v4 conserva borradores, revisión, solución y auditoría al reiniciar',
    () async {
      final id = await publish();
      final first = await management(id);
      await repo.submitManagement(first);
      await repo.reviewManagement(first.id, ReviewStatus.approved, 'Apta');
      final draft = await repo.createManagement(id, previousId: first.id);
      await repo.saveManagementDraft(draft);
      await approveSolution(id);
      await repo.verifySolution(
        id,
        expectedVersion: repo.resolutionForReview(id).version,
        reason: 'Solución revisada',
      );
      expect((jsonDecode(storage.value!) as Map)['version'], 4);
      final restored = LocalSubmissionRepository(
        session: session,
        storage: storage,
        clock: () => now,
      );
      await restored.load();
      final projection = ModeratedReportRepository(
        DemoReportRepository(),
        restored,
      );
      expect(restored.managementDrafts(id).single.id, draft.id);
      expect(
        restored.managementEntries(id).single.draft.notes,
        'NOTAS PRIVADAS',
      );
      expect(
        (await projection.getPublicReport(id))!.tracking,
        TrackingStatus.verified,
      );
      expect(
        restored.resolutionForReview(id).history.last.reason,
        'Solución revisada',
      );
      projection.dispose();
      restored.dispose();
    },
  );

  test('migra v3 sin perder aportes y no permite verificar un ejemplo sin evidencia local', () async {
    final id = await publish();
    final contribution = await send(id, ContributionKind.evidence);
    final legacy = jsonDecode(storage.value!) as Map<String, dynamic>;
    legacy['version'] = 3;
    legacy.remove('workflow');
    await storage.write(jsonEncode(legacy));
    final restored = LocalSubmissionRepository(
      session: session,
      storage: storage,
      clock: () => now,
    );
    await restored.load();
    expect(restored.ownContributions.single.id, contribution.id);
    session.enterModerationScenario();
    await expectLater(
      restored.verifySolution('3', expectedVersion: 0, reason: 'Sin evidencia'),
      throwsStateError,
    );
    final draft = await restored.createManagement(id);
    await restored.saveManagementDraft(draft);
    expect((jsonDecode(storage.value!) as Map)['version'], 4);
    restored.dispose();
  });
}
