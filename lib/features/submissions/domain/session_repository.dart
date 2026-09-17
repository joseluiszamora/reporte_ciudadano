import 'package:flutter/foundation.dart';

enum DemoProvider { email, google, neighbor }

enum DemoRole { citizen, moderator }

class DemoIdentity {
  const DemoIdentity(
    this.id,
    this.alias,
    this.provider, {
    this.role = DemoRole.citizen,
  });
  final DemoRole role;
  final String id;
  final String alias;
  final DemoProvider provider;
}

abstract class SessionRepository extends ChangeNotifier {
  DemoIdentity? get current;
  Future<void> signIn(DemoProvider provider, String alias);
  void signOut();
  void enterModerationScenario();
}

/// Dos identidades locales fijas. No es autenticación ni autorización real.
class DemoSessionRepository extends SessionRepository {
  DemoIdentity? _current;
  @override
  DemoIdentity? get current => _current;
  @override
  void enterModerationScenario() {
    _current = const DemoIdentity(
      'demo-moderator',
      'Moderación de demostración',
      DemoProvider.email,
      role: DemoRole.moderator,
    );
    notifyListeners();
  }

  @override
  Future<void> signIn(DemoProvider provider, String alias) async {
    final value = alias.trim();
    if (value.length < 3 || value.length > 30 || value.contains('@')) {
      throw ArgumentError('Usa un alias de 3–30 caracteres, sin correo.');
    }
    _current = DemoIdentity('demo-${provider.name}', value, provider);
    notifyListeners();
  }

  @override
  void signOut() {
    _current = null;
    notifyListeners();
  }
}
