import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/reports/domain/report_repository.dart';
import 'features/reports/presentation/explore_page.dart';
import 'features/reports/presentation/report_widgets.dart';

class ReporteCiudadanoApp extends StatelessWidget {
  const ReporteCiudadanoApp({required this.repository, super.key});
  final ReportRepository repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Reporte Ciudadano',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    locale: const Locale('es', 'BO'),
    supportedLocales: const [Locale('es', 'BO')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: _Home(repository: repository),
  );
}

class _Home extends StatefulWidget {
  const _Home({required this.repository});
  final ReportRepository repository;
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _selected = 0;
  void _select(int index) {
    if (index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Reportar')),
            body: const SingleChildScrollView(
              child: ContentMessage(
                title: 'Documentar un problema',
                message:
                    'En esta entrega puedes explorar reportes de demostración. '
                    'El formulario de envío todavía no está implementado. No se envían datos.',
              ),
            ),
          ),
        ),
      );
    } else {
      setState(() => _selected = index);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
      title: const Text('Reporte Ciudadano', maxLines: 2),
    ),
    body: SafeArea(
      child: IndexedStack(
        index: _selected == 0 ? 0 : _selected - 1,
        children: [
          ExplorePage(repository: widget.repository),
          SingleChildScrollView(
            child: ContentMessage(
              title: 'Aún no sigues reportes',
              message: 'El seguimiento personal no está implementado en esta entrega.',
              action: FilledButton(
                onPressed: () => _select(0),
                child: const Text('Explorar reportes'),
              ),
            ),
          ),
          const SingleChildScrollView(
            child: ContentMessage(
              title: 'Estás explorando como visitante',
              message:
                  'Puedes consultar contenido público de demostración sin cuenta. '
                  'El acceso y el perfil personal todavía no están implementados. '
                  'No se recogen credenciales ni datos personales.',
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selected,
      onDestinationSelected: _select,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Explorar',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          label: 'Reportar',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_border),
          label: 'Siguiendo',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    ),
  );
}
