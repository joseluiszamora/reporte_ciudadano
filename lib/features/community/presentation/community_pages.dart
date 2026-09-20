import 'package:flutter/material.dart';

import '../../safety/presentation/safety_pages.dart';

import '../../reports/domain/report.dart';
import '../../reports/presentation/report_detail_page.dart';
import '../../reports/presentation/report_widgets.dart';
import '../../submissions/domain/session_repository.dart';
import '../../submissions/presentation/access_page.dart';
import '../../submissions/presentation/flow_widgets.dart';
import '../../submissions/presentation/profile_page.dart';
import '../../submissions/presentation/submission_status_page.dart';
import '../domain/community.dart';
import 'community_scope.dart';
import 'contribution_page.dart';

class ParticipationPanel extends StatefulWidget {
  const ParticipationPanel({required this.report, super.key});
  final Report report;
  @override
  State<ParticipationPanel> createState() => _ParticipationPanelState();
}

class _ParticipationPanelState extends State<ParticipationPanel> {
  bool _busy = false;
  String? _message;
  Future<void> _action(String action) async {
    final scope = CommunityScope.of(context);
    if (scope.services.session.current?.role != DemoRole.citizen) {
      await requestDemoAccess(context, scope.services.session);
      if (mounted) {
        setState(
          () => _message = 'Has vuelto al reporte. Pulsa la acción para confirmarla; no se envió nada automáticamente.',
        );
      }
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final repo = scope.services.community;
      if (action == 'confirm') {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar observación'),
            scrollable: true,
            content: const Text(
              'Declaro que observé que el problema sigue ocurriendo ahora. Es una confirmación simple de demostración; textos y fotos requieren un aporte a revisión.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar ahora'),
              ),
            ],
          ),
        );
        if (accepted != true) return;
        final repeated = repo.ownObservation(widget.report.id) != null;
        await repo.confirmObservation(widget.report.id, DateTime.now().toUtc());
        if (mounted) {
          setState(
            () => _message = repeated
                ? 'Observación actualizada; no se suma otra persona.'
                : 'Observación registrada. El autor no suma al umbral independiente.',
          );
        }
      } else if (action == 'follow') {
        final value = !repo.isFollowing(widget.report.id);
        await repo.follow(widget.report.id, value);
        if (mounted) {
          setState(
            () => _message = value
                ? 'Ahora sigues este reporte.'
                : 'Dejaste de seguir este reporte.',
          );
        }
      } else if (action == 'complaint') {
        final draft = scope.services.safety.createComplaint(widget.report.id);
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ComplaintFormPage(
                draft: draft,
                repository: scope.services.safety,
                session: scope.services.session,
              ),
            ),
          );
        }
      } else {
        final draft = await repo.createContribution(widget.report.id);
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ContributionPage(draft: draft),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'No se pudo guardar la acción. Comprueba que el reporte siga visible y reintenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = CommunityScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final services = scope.services;
    return ListenableBuilder(
      listenable: Listenable.merge([services.community, services.session]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text('Participar', style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Umbral propuesto y configurable: ${services.community.communityRules.confirmationThreshold} observadores independientes. Una persona cuenta una vez; el autor y los comentarios no suman al umbral.',
          ),
          FilledButton(
            onPressed: _busy ? null : () => _action('confirm'),
            child: Text(
              services.community.ownObservation(widget.report.id) == null
                  ? 'Confirmar que sigue ocurriendo'
                  : 'Ya confirmaste · actualizar observación',
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _action('follow'),
            child: Text(
              services.community.isFollowing(widget.report.id)
                  ? 'Dejar de seguir'
                  : 'Seguir reporte',
            ),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _action('contribute'),
            child: const Text('Aportar comentario o evidencia'),
          ),
          OutlinedButton(
            onPressed: _busy ? null : () => _action('complaint'),
            child: const Text('Denunciar contenido'),
          ),
          if (_message != null)
            Semantics(liveRegion: true, child: Text(_message!)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class FollowingPage extends StatelessWidget {
  const FollowingPage({required this.onExplore, super.key});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) {
    final scope = CommunityScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.services.community,
        scope.services.submissions,
        scope.services.session,
      ]),
      builder: (context, _) => FutureBuilder<List<FollowedReport>>(
        future: scope.services.community.following(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando reportes seguidos',
              ),
            );
          }
          if (snapshot.hasError) {
            return const FlowBody(
              children: [
                FlowError(
                  'No se pudieron cargar tus seguimientos. Vuelve a abrir esta sección.',
                ),
              ],
            );
          }
          final reports = snapshot.data ?? [];
          return FlowBody(
            children: [
              const DemoNotice(),
              if (reports.isEmpty)
                ContentMessage(
                  title: 'Aún no sigues reportes',
                  message: 'Sigue reportes públicos desde su detalle. Los reportes ocultos o duplicados se retiran de esta lista.',
                  action: FilledButton(
                    onPressed: onExplore,
                    child: const Text('Explorar reportes'),
                  ),
                ),
              for (final followed in reports)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (followed.hasNews)
                      const Text('Novedades aprobadas sin leer'),
                    ReportCard(
                      report: followed.report,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ReportDetailPage(
                            repository: scope.reports,
                            reportId: followed.report.id,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String? _error;
  Future<void> _preferences(NoticePreferences value) async {
    try {
      await CommunityScope.of(context).services.community
          .savePreferences(value);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se guardaron las preferencias. Reintenta.');
      }
    }
  }

  Future<void> _open(CommunityNotice note) async {
    final scope = CommunityScope.of(context);
    try {
      await scope.services.community.readNotice(note.id);
      if (!mounted) return;
      Widget page;
      if (note.kind == NoticeKind.reportReview) {
        page = SubmissionStatusPage(
          id: note.targetId!,
          repository: scope.services.submissions,
          session: scope.services.session,
          onRevise: (draft) => openReportForm(
            context,
            scope.services,
            scope.reports,
            draft: draft,
          ),
        );
      } else if (note.kind == NoticeKind.contributionReview) {
        page = const MyContributionsPage();
      } else {
        page = ReportDetailPage(
          repository: scope.reports,
          reportId: note.reportId,
        );
      }
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => page),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'El aviso no está disponible para esta sesión.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = CommunityScope.of(context);
    final services = scope.services;
    return ListenableBuilder(
      listenable: Listenable.merge([
        services.community,
        services.submissions,
        services.session,
      ]),
      builder: (context, _) {
        final prefs = services.community.preferences;
        return Scaffold(
          appBar: flowAppBar(context, 'Notificaciones · simuladas'),
          body: services.session.current?.role != DemoRole.citizen
              ? FlowBody(
                  children: [
                    const Text(
                      'Entra con una cuenta ciudadana para consultar tu bandeja privada.',
                    ),
                    FilledButton(
                      onPressed: () =>
                          requestDemoAccess(context, services.session),
                      child: const Text('Acceso simulado'),
                    ),
                  ],
                )
              : FutureBuilder<List<CommunityNotice>>(
                  future: services.community.inbox(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Cargando avisos',
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return const FlowBody(
                        children: [
                          FlowError(
                            'No se pudo cargar la bandeja. Vuelve a abrirla.',
                          ),
                        ],
                      );
                    }
                    final notes = snapshot.data ?? [];
                    return FlowBody(
                      children: [
                        const DemoNotice(),
                        const Text(
                          'Bandeja local simulada. No se envía push al dispositivo. La bandeja funciona aunque se rechace el permiso simulado.',
                        ),
                        SwitchListTile(
                          title: const Text(
                            'Avisos de comentarios aprobados y agrupados',
                          ),
                          value: prefs.comments,
                          onChanged: (v) => _preferences(
                            NoticePreferences(
                              comments: v,
                              pushDenied: prefs.pushDenied,
                            ),
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('Simular permiso push rechazado'),
                          value: prefs.pushDenied,
                          onChanged: (v) => _preferences(
                            NoticePreferences(
                              comments: prefs.comments,
                              pushDenied: v,
                            ),
                          ),
                        ),
                        if (_error != null) FlowError(_error!),
                        if (notes.isEmpty)
                          const Text('No hay notificaciones disponibles.'),
                        for (final note in notes)
                          Card(
                            child: ListTile(
                              title: Text(note.label),
                              subtitle: Text(
                                '${note.isPrivate ? 'Privada para el autor' : 'Contenido público aprobado'} · ${note.read ? 'Leída' : 'Sin leer'}\n${boliviaDate(note.at)}\nDatos de demostración',
                              ),
                              onTap: () => _open(note),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}
