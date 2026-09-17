import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/reports/data/moderated_report_repository.dart';
import 'features/reports/domain/report_repository.dart';
import 'features/reports/presentation/explore_page.dart';
import 'features/community/presentation/community_scope.dart';
import 'features/community/presentation/community_pages.dart';
import 'features/submissions/prototype_services.dart';
import 'features/submissions/presentation/profile_page.dart';

class ReporteCiudadanoApp extends StatefulWidget {
  const ReporteCiudadanoApp({
    required this.repository,
    this.services,
    super.key,
  });
  final ReportRepository repository;
  final PrototypeServices? services;
  @override
  State<ReporteCiudadanoApp> createState() => _ReporteCiudadanoAppState();
}

class _ReporteCiudadanoAppState extends State<ReporteCiudadanoApp> {
  late final PrototypeServices _services =
      widget.services ?? PrototypeServices.memory();
  late final ModeratedReportRepository _public = ModeratedReportRepository(
    widget.repository,
    _services.submissions,
    community: _services.community,
  );
  @override
  void dispose() {
    _public.dispose();
    if (widget.services == null) _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Reporte Ciudadano',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    locale: const Locale('es', 'BO'),
    supportedLocales: const [Locale('es', 'BO')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) =>
        CommunityScope(services: _services, reports: _public, child: child!),
    home: _Home(repository: _public, services: _services),
  );
}

class _Home extends StatefulWidget {
  const _Home({required this.repository, required this.services});
  final ReportRepository repository;
  final PrototypeServices services;
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _selected = 0;
  void _select(int index) {
    if (index == 1) {
      openReportForm(context, widget.services, widget.repository);
    } else {
      setState(() => _selected = index);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
      title: const Text('Reporte Ciudadano', maxLines: 2),
      actions: [
        IconButton(
          tooltip: 'Notificaciones simuladas',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
          ),
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: IndexedStack(
        index: _selected == 0 ? 0 : _selected - 1,
        children: [
          ExplorePage(repository: widget.repository),
          FollowingPage(onExplore: () => _select(0)),
          ProfilePage(
            services: widget.services,
            publicReports: widget.repository,
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
