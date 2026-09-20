import '../../../core/geo_point.dart';
import 'report.dart';

/// Área rectangular de demostración; no acredita pertenencia territorial.
class ExploreArea {
  const ExploreArea(this.center, {this.span = .006});
  final GeoPoint center;
  final double span;
  bool contains(GeoPoint? point) =>
      point != null &&
      point.isValid &&
      (point.latitude - center.latitude).abs() <= span / 2 &&
      (point.longitude - center.longitude).abs() <= span / 2;
  ExploreArea move(double north, double east) => ExploreArea(
    GeoPoint(
      (center.latitude + north * span).clamp(-85, 85),
      (center.longitude + east * span).clamp(-179, 179),
    ),
    span: span,
  );
  ExploreArea zoom(double factor) =>
      ExploreArea(center, span: (span * factor).clamp(.0001, 10));
}

DateTime latestObservation(Report report) {
  final community = report.lastCommunityObservedAt;
  return community != null && community.isAfter(report.observedAt)
      ? community
      : report.observedAt;
}

class ExploreFilter {
  const ExploreFilter({
    this.categories = const {},
    this.statuses = const {
      TrackingStatus.reported,
      TrackingStatus.confirmed,
      TrackingStatus.solutionReported,
    },
    this.from,
    this.until,
  });
  final Set<String> categories;
  final Set<TrackingStatus> statuses;

  /// Fechas de calendario de Bolivia, sin componente de hora.
  final DateTime? from, until;

  List<Report> apply(
    Iterable<Report> source, {
    String query = '',
    ExploreArea? area,
    GeoPoint? near,
  }) {
    final text = query.trim().toLowerCase();
    final results = source.where((r) {
      final local = latestObservation(r)
          .toUtc()
          .subtract(const Duration(hours: 4));
      final day = DateTime(local.year, local.month, local.day);
      return r.isPublic &&
          statuses.contains(r.tracking) &&
          (categories.isEmpty || categories.contains(r.category)) &&
          '${r.zone} ${r.reference}'.toLowerCase().contains(text) &&
          (from == null || !day.isBefore(from!)) &&
          (until == null || !day.isAfter(until!)) &&
          (area == null || area.contains(r.point));
    }).toList();
    results.sort((a, b) {
      if (near != null) {
        final distance = (a.point?.distanceTo(near) ?? double.infinity)
            .compareTo(b.point?.distanceTo(near) ?? double.infinity);
        if (distance != 0) return distance;
      }
      final recent = latestObservation(b).compareTo(latestObservation(a));
      return recent != 0 ? recent : a.id.compareTo(b.id);
    });
    return results;
  }
}
