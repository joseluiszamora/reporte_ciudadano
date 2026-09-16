import 'package:flutter/material.dart';

import '../../reports/domain/report.dart';
import '../../reports/presentation/report_widgets.dart';
import '../domain/session_repository.dart';
import '../domain/submission.dart';
import '../domain/submission_repository.dart';
import 'flow_widgets.dart';

class SubmissionStatusPage extends StatelessWidget {
  const SubmissionStatusPage({
    required this.id,
    required this.repository,
    required this.session,
    super.key,
  });
  final String id;
  final SubmissionRepository repository;
  final SessionRepository session;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([repository, session]),
    builder: (context, _) {
      final item = repository.ownSubmission(id);
      return Scaffold(
        appBar: flowAppBar(context, 'Estado de mi envío'),
        body: item == null
            ? const FlowBody(
                children: [Text('Envío no disponible para esta sesión.')],
              )
            : FlowBody(
                children: [
                  const DemoNotice(),
                  Text(
                    item.draft.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text(
                    'Pendiente de aprobación',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Solo tú puedes consultar este envío en la sesión de demostración. '
                    'No está publicado en Explorar.',
                  ),
                  Text(
                    'Enviado: ${boliviaDate(item.sentAt)} · hora de Bolivia',
                  ),
                  const Text(
                    'Revisamos contenido de 08:00 a 20:00, hora de Bolivia',
                  ),
                  Text(moderationMessage(item.sentAt)),
                  Text(
                    'Alias al enviar: ${item.alias}\nCategoría: ${item.draft.category}',
                  ),
                  Text(item.draft.description),
                  Text('Observado: ${boliviaDate(item.draft.observedAt)}'),
                  Text(
                    'El Alto (declarado)\nPunto: ${item.draft.latitude}, ${item.draft.longitude}\n'
                    '${item.draft.zone}\n${item.draft.reference}',
                  ),
                  Text(
                    item.draft.photos.isEmpty
                        ? 'Sin foto adjunta'
                        : '${item.draft.photos.length} adjuntos simulados pendientes',
                  ),
                  const Text('Historial de revisión'),
                  Text(
                    '${boliviaDate(item.sentAt)} · Recibido en la simulación y puesto en cola.',
                  ),
                  const Text(
                    'Aún no hay una decisión de moderación. La revisión se implementará en la siguiente entrega.',
                  ),
                ],
              ),
      );
    },
  );
}
