import 'package:flutter/material.dart';

import '../../../core/geo_point.dart';
import '../domain/explore_filter.dart';

/// Plano de coordenadas local, sin cartografía ni validación territorial.
class SchematicPointMap extends StatelessWidget {
  const SchematicPointMap({
    required this.area,
    required this.point,
    this.onPointChanged,
    this.enabled = true,
    this.height = 220,
    super.key,
  });
  final ExploreArea area;
  final GeoPoint? point;
  final ValueChanged<GeoPoint>? onPointChanged;
  final bool enabled;
  final double height;

  void _select(Offset position, Size size) {
    final x = (position.dx / size.width).clamp(0.0, 1.0);
    final y = (position.dy / size.height).clamp(0.0, 1.0);
    onPointChanged?.call(
      GeoPoint(
        (area.center.latitude + (.5 - y) * area.span).clamp(-90.0, 90.0),
        (area.center.longitude + (x - .5) * area.span).clamp(-180.0, 180.0),
      ),
    );
  }

  void _nudge(double north, double east) {
    final current = point ?? area.center;
    onPointChanged?.call(
      GeoPoint(
        (current.latitude + north * area.span / 8).clamp(-90.0, 90.0),
        (current.longitude + east * area.span / 8).clamp(-180.0, 180.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          onPointChanged == null
              ? 'Minimapa esquemático · sin calles ni límites oficiales'
              : 'Ubicación esquemática · toca el plano o usa las flechas',
        ),
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final selected =
                  point != null && point!.isValid && area.contains(point);
              final dx = selected
                  ? ((point!.longitude - area.center.longitude) / area.span +
                            .5) *
                        size.width
                  : size.width / 2;
              final dy = selected
                  ? (.5 -
                            (point!.latitude - area.center.latitude) /
                                area.span) *
                        size.height
                  : size.height / 2;
              return GestureDetector(
                onTapUp: onPointChanged == null || !enabled
                    ? null
                    : (details) => _select(details.localPosition, size),
                child: Semantics(
                  label: onPointChanged == null
                      ? 'Punto del reporte en un esquema de coordenadas'
                      : 'Plano de coordenadas de demostración; toca para ajustar el punto',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color.surfaceContainer,
                      border: Border.all(color: color.outline),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GridPainter(color.outlineVariant),
                          ),
                        ),
                        const Positioned(top: 4, left: 8, child: Text('N ↑')),
                        if (selected)
                          Positioned(
                            left: dx.clamp(16.0, size.width - 16) - 16,
                            top: dy.clamp(16.0, size.height - 16) - 16,
                            child: ExcludeSemantics(
                              child: Icon(
                                Icons.place,
                                size: 32,
                                color: color.primary,
                              ),
                            ),
                          ),
                        if (!selected)
                          const Center(child: Text('Punto sin definir')),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (point != null && point!.isValid)
          Text(
            'Punto: ${point!.latitude.toStringAsFixed(6)}, ${point!.longitude.toStringAsFixed(6)}',
          ),
        if (onPointChanged != null)
          Wrap(
            spacing: 4,
            children: [
              for (final direction in <(String, IconData, double, double)>[
                ('Mover punto al norte', Icons.north, 1, 0),
                ('Mover punto al sur', Icons.south, -1, 0),
                ('Mover punto al oeste', Icons.west, 0, -1),
                ('Mover punto al este', Icons.east, 0, 1),
              ])
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: direction.$1,
                  onPressed: enabled
                      ? () => _nudge(direction.$3, direction.$4)
                      : null,
                  icon: Icon(direction.$2),
                ),
            ],
          ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final fraction in [.25, .5, .75]) {
      canvas.drawLine(
        Offset(size.width * fraction, 0),
        Offset(size.width * fraction, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, size.height * fraction),
        Offset(size.width, size.height * fraction),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}
