import 'package:flutter/material.dart';

import '../../reports/domain/report_repository.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/report_widgets.dart';
import '../domain/submission.dart';
import '../prototype_services.dart';
import 'access_page.dart';
import 'flow_widgets.dart';
import 'report_form_page.dart';
import 'submission_status_page.dart';

Future<void> openReportForm(
  BuildContext context,
  PrototypeServices services,
  ReportRepository publicReports, {
  ReportDraft? draft,
}) async {
  if (!await requestDemoAccess(context, services.session) || !context.mounted) {
    return;
  }
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ReportFormPage(
        draft: draft ?? services.submissions.createDraft(),
        repository: services.submissions,
        publicReports: publicReports,
        session: services.session,
        location: services.location,
        photos: services.photos,
      ),
    ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.services,
    required this.publicReports,
    super.key,
  });
  final PrototypeServices services;
  final ReportRepository publicReports;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([services.session, services.submissions]),
    builder: (context, _) {
      final user = services.session.current;
      if (user == null) {
        return FlowBody(
          children: [
            const Text('Estás explorando como visitante'),
            const Text(
              'Consulta reportes públicos sin cuenta. Para guardar borradores y consultar tus envíos, entra en una cuenta de demostración.',
            ),
            FilledButton(
              onPressed: () => requestDemoAccess(context, services.session),
              child: const Text('Acceso simulado'),
            ),
          ],
        );
      }
      final drafts = services.submissions.ownDrafts;
      final submissions = services.submissions.ownSubmissions;
      return FlowBody(
        children: [
          const DemoNotice(),
          Text(
            'Hola, ${user.alias}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Cuenta ${user.provider.name == 'email' ? 'correo' : 'Google'} de demostración. '
            'Los borradores y envíos se guardan solo en este dispositivo. No uses información sensible.',
          ),
          OutlinedButton(
            onPressed: services.session.signOut,
            child: const Text('Cerrar sesión simulada'),
          ),
          Text(
            'Borradores (${drafts.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (drafts.isEmpty) const Text('Aún no tienes borradores.'),
          for (final draft in drafts)
            Card(
              child: ListTile(
                title: Text(
                  draft.title.trim().isEmpty
                      ? 'Reporte sin título'
                      : draft.title,
                ),
                subtitle: Text(
                  'Borrador · paso ${draft.step + 1}/3 · Datos de demostración',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => openReportForm(
                  context,
                  services,
                  publicReports,
                  draft: draft,
                ),
              ),
            ),
          FilledButton(
            onPressed: () => openReportForm(context, services, publicReports),
            child: const Text('Crear reporte'),
          ),
          Text(
            'Mis envíos (${submissions.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (submissions.isEmpty)
            const Text('Aún no has enviado reportes a revisión.'),
          for (final item in submissions)
            Card(
              child: ListTile(
                title: Text(item.draft.title),
                subtitle: Text(
                  'Pendiente de aprobación\n${boliviaDate(item.sentAt)}\nDatos de demostración',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SubmissionStatusPage(
                      id: item.id,
                      repository: services.submissions,
                      session: services.session,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
