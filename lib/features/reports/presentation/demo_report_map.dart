import 'package:flutter/material.dart';

import '../domain/explore_filter.dart';
import '../domain/report.dart';

/// Sustituible por cartografía real cuando se acuerde un proveedor.
/// Agrupa por celdas de pantalla para mantener objetivos táctiles de 48 px.
class DemoReportMap extends StatelessWidget {
  const DemoReportMap({
    required this.reports,
    required this.area,
    required this.onSelect,
    this.onAreaChanged,
    super.key,
  });
  final List<Report> reports;
  final ExploreArea area;
  final ValueChanged<List<String>> onSelect;
  final ValueChanged<ExploreArea>? onAreaChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Mapa esquemático · sin calles ni límites oficiales'),
      const Text(
        'Datos de demostración. Norte arriba; usa la lista para consultar todos los resultados.',
      ),
      SizedBox(
        height: 288,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 64).floor().clamp(1, 12);
            const rows = 4;
            final groups = <(int, int), List<Report>>{};
            for (final report in reports.where(
              (r) => r.isPublic && area.contains(r.point),
            )) {
              final x =
                  (((report.point!.longitude - area.center.longitude) /
                                  area.span +
                              .5) *
                          columns)
                      .floor()
                      .clamp(0, columns - 1);
              final y =
                  ((.5 -
                              (report.point!.latitude - area.center.latitude) /
                                  area.span) *
                          rows)
                      .floor()
                      .clamp(0, rows - 1);
              groups.putIfAbsent((x, y), () => []).add(report);
            }
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Stack(
                children: [
                  const Positioned(top: 4, left: 8, child: Text('N ↑')),
                  for (final entry in groups.entries)
                    Positioned(
                      left:
                          (entry.key.$1 + .5) * constraints.maxWidth / columns -
                          24,
                      top: 24 + (entry.key.$2 + .5) * 256 / rows - 24,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Semantics(
                          label: entry.value.length == 1
                              ? 'Reporte: ${entry.value.single.publicRevision!.title}'
                              : '${entry.value.length} reportes agrupados',
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () =>
                                onSelect(entry.value.map((r) => r.id).toList()),
                            child: ExcludeSemantics(
                              child: Text('${entry.value.length}'),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      Text(
        'Centro: ${area.center.latitude.toStringAsFixed(5)}, ${area.center.longitude.toStringAsFixed(5)}',
      ),
      if (onAreaChanged != null)
        Wrap(
          spacing: 4,
          children: [
            for (final direction in <(String, IconData, double, double)>[
              ('Mover al norte', Icons.north, .5, 0),
              ('Mover al sur', Icons.south, -.5, 0),
              ('Mover al oeste', Icons.west, 0, -.5),
              ('Mover al este', Icons.east, 0, .5),
            ])
              IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: direction.$1,
                onPressed: () =>
                    onAreaChanged!(area.move(direction.$3, direction.$4)),
                icon: Icon(direction.$2),
              ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: 'Acercar mapa',
              onPressed: () => onAreaChanged!(area.zoom(.5)),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              tooltip: 'Alejar mapa',
              onPressed: () => onAreaChanged!(area.zoom(2)),
              icon: const Icon(Icons.remove),
            ),
          ],
        ),
    ],
  );
}
