import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'features/reports/data/demo_report_repository.dart';
import 'features/submissions/data/local_submission_repository.dart';
import 'features/submissions/data/preferences_draft_storage.dart';
import 'features/submissions/domain/device_adapters.dart';
import 'features/submissions/domain/session_repository.dart';
import 'features/submissions/presentation/flow_widgets.dart';
import 'features/submissions/prototype_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Bootstrap());
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();
  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  PrototypeServices? _services;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    final session = DemoSessionRepository();
    final submissions = LocalSubmissionRepository(
      session: session,
      storage: PreferencesDraftStorage(),
    );
    try {
      await submissions.load();
      if (!mounted) {
        submissions.dispose();
        session.dispose();
        return;
      }
      setState(
        () => _services = PrototypeServices(
          session: session,
          submissions: submissions,
          location: DemoLocationAdapter(),
          photos: DemoPhotoAdapter(),
        ),
      );
    } catch (_) {
      submissions.dispose();
      session.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _services?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_services != null) {
      return ReporteCiudadanoApp(
        repository: DemoReportRepository(),
        services: _services,
      );
    }
    return MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: _failed
            ? FlowBody(
                children: [
                  const Text('No pudimos recuperar los borradores guardados.'),
                  const Text(
                    'No se han borrado tus datos. Puedes volver a intentar la lectura.',
                  ),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Reintentar'),
                  ),
                ],
              )
            : const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Recuperando borradores',
                ),
              ),
      ),
    );
  }
}
