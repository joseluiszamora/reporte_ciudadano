import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/core/geo_point.dart';
import 'package:reporte_ciudadano/features/reports/data/demo_report_repository.dart';
import 'package:reporte_ciudadano/features/reports/domain/explore_filter.dart';
import 'package:reporte_ciudadano/features/reports/domain/report.dart';

void main() {
  test('Solo públicos abiertos; combina categoría, estado y referencia', () {
    expect(const ExploreFilter().apply(demoReports()).map((r) => r.id), [
      '1',
      '2',
      '3',
      '6',
      '9',
    ]);
    final filter = ExploreFilter(
      categories: {'Aceras y accesibilidad'},
      statuses: {TrackingStatus.confirmed},
    );
    expect(filter.apply(demoReports(), query: 'DEMOSTRACIÓN 2').single.id, '2');
    expect(filter.apply(demoReports(), query: 'inexistente'), isEmpty);
    expect(const ExploreFilter(statuses: {}).apply(demoReports()), isEmpty);
  });

  test('Fecha inclusiva usa Bolivia y la última observación comunitaria', () {
    final source = demoReports().first;
    final updated = source.withCommunity(
      confirmations: 1,
      tracking: source.tracking,
      comments: [],
      updates: [],
      lastObservation: DateTime.utc(2026, 9, 11, 2),
    );
    final filter = ExploreFilter(
      from: DateTime(2026, 9, 10),
      until: DateTime(2026, 9, 10),
    );
    expect(filter.apply([source, updated]), [updated]);
    expect(
      ExploreFilter(from: DateTime(2026, 9, 11)).apply([updated]),
      isEmpty,
    );
  });

  test('Área y cercanía comparten coordenadas sin ampliar visibilidad', () {
    const area = ExploreArea(GeoPoint(-16.5001, -68.1600), span: .00005);
    expect(
      const ExploreFilter().apply(demoReports(), area: area).single.id,
      '1',
    );
    expect(
      const ExploreFilter()
          .apply(demoReports(), near: const GeoPoint(-16.5009, -68.16))
          .first
          .id,
      '9',
    );
    expect(area.contains(null), isFalse);
    expect(area.contains(const GeoPoint(double.nan, 0)), isFalse);
    expect(
      const ExploreFilter().apply(demoReports(), area: area.move(10, 10)),
      isEmpty,
    );
  });

  test('Zoom y desplazamiento limitados mantienen un área válida', () {
    const area = ExploreArea(GeoPoint(84, 178));
    expect(area.move(100000, 100000).center.isValid, isTrue);
    expect(area.zoom(.000001).span, .0001);
    expect(area.zoom(100000).span, 10);
  });
}
