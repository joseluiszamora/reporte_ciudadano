import 'dart:math';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
  double distanceTo(GeoPoint other) {
    double radians(double value) => value * pi / 180;
    final a =
        pow(sin(radians(other.latitude - latitude) / 2), 2) +
        cos(radians(latitude)) *
            cos(radians(other.latitude)) *
            pow(sin(radians(other.longitude - longitude) / 2), 2);
    return 6371000 * 2 * asin(sqrt(a.clamp(0, 1)));
  }
}
