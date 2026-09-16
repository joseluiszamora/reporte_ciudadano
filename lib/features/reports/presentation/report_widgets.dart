import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/report.dart';

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key});
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.soft,
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    child: Padding(
      padding: EdgeInsets.all(AppSpace.medium),
      child: Text(
        'Datos de demostración\nHechos, zonas y gestiones ficticios.',
        style: TextStyle(color: AppColors.primary),
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final TrackingStatus status;
  @override
  Widget build(BuildContext context) {
    final verified = status == TrackingStatus.verified;
    final proposed = status == TrackingStatus.solutionReported;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: verified
            ? AppColors.successBackground
            : proposed
            ? AppColors.warningBackground
            : AppColors.soft,
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: verified
              ? AppColors.success
              : proposed
              ? AppColors.warning
              : AppColors.primary,
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  const ReportCard({required this.report, required this.onTap, super.key});
  final Report report;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.category, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpace.small),
            Text(
              report.publicRevision!.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.small),
            Text('${report.zone} · El Alto'),
            const SizedBox(height: AppSpace.medium),
            StatusBadge(report.tracking),
            const SizedBox(height: AppSpace.medium),
            Text(
              'Última observación: ${boliviaDate(report.observedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Text('Sin foto adjunta'),
            if (report.management.isNotEmpty) ...[
              const SizedBox(height: AppSpace.small),
              Text('Última gestión: ${report.management.last.text}'),
            ],
            const SizedBox(height: AppSpace.small),
            const Text(
              'Datos de demostración',
              style: TextStyle(color: AppColors.primary, fontSize: 14),
            ),
            const SizedBox(height: AppSpace.small),
            const Row(
              children: [
                Flexible(child: Text('Ver reporte')),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class ContentMessage extends StatelessWidget {
  const ContentMessage({
    required this.title,
    required this.message,
    this.action,
    super.key,
  });
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpace.large),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpace.medium),
        Text(message),
        if (action != null) ...[
          const SizedBox(height: AppSpace.medium),
          action!,
        ],
      ],
    ),
  );
}
