import 'package:flutter/services.dart';

import '../domain/submission_repository.dart';

class PreferencesDraftStorage implements DraftStorage {
  static const channel = MethodChannel('bo.reporte.demo/draft_storage');
  @override
  Future<String?> read() => channel.invokeMethod<String>('read');
  @override
  Future<void> write(String value) =>
      channel.invokeMethod<void>('write', value);
}
