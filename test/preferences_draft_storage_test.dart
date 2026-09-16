import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reporte_ciudadano/features/submissions/data/preferences_draft_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(
      PreferencesDraftStorage.channel,
      null,
    ),
  );

  test(
    'adaptador Android conserva la instantánea por el canal nativo',
    () async {
      String? saved;
      messenger.setMockMethodCallHandler(PreferencesDraftStorage.channel, (
        call,
      ) async {
        if (call.method == 'write') {
          saved = call.arguments as String;
          return null;
        }
        if (call.method == 'read') return saved;
        throw MissingPluginException();
      });
      final storage = PreferencesDraftStorage();
      expect(await storage.read(), isNull);
      await storage.write('{"version":1,"drafts":[],"submissions":[]}');
      expect(await PreferencesDraftStorage().read(), saved);
    },
  );

  test('fallo de disco nativo se propaga y no simula éxito', () async {
    messenger.setMockMethodCallHandler(PreferencesDraftStorage.channel, (
      call,
    ) async {
      throw PlatformException(code: 'storage_write');
    });
    await expectLater(
      PreferencesDraftStorage().write('snapshot'),
      throwsA(isA<PlatformException>()),
    );
  });
}
