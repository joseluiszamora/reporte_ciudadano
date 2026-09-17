import 'package:flutter/material.dart';

import '../../reports/domain/report_repository.dart';
import '../../submissions/prototype_services.dart';

class CommunityScope extends InheritedWidget {
  const CommunityScope({
    required this.services,
    required this.reports,
    required super.child,
    super.key,
  });
  final PrototypeServices services;
  final ReportRepository reports;
  static CommunityScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommunityScope>();
  static CommunityScope of(BuildContext context) => maybeOf(context)!;
  @override
  bool updateShouldNotify(CommunityScope oldWidget) =>
      services != oldWidget.services || reports != oldWidget.reports;
}
