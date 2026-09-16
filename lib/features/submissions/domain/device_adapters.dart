import '../../../core/geo_point.dart';

abstract interface class LocationAdapter {
  Future<GeoPoint?> request({required bool simulateDenial});
}

class DemoLocationAdapter implements LocationAdapter {
  @override
  Future<GeoPoint?> request({required bool simulateDenial}) async =>
      simulateDenial ? null : const GeoPoint(-16.5000, -68.1600);
}

abstract interface class PhotoAdapter {
  Future<String> select(bool camera);
}

class DemoPhotoAdapter implements PhotoAdapter {
  @override
  Future<String> select(bool camera) async =>
      '${camera ? 'Cámara' : 'Galería'} simulada · ${DateTime.now().microsecondsSinceEpoch}';
}
