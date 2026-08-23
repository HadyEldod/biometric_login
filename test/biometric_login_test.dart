import 'package:biometric_login/biometric_login.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [BiometricSecretStorage] for tests.
class _MemoryStorage implements BiometricSecretStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Fake [BiometricService] with scriptable outcomes — no real device needed.
class _FakeService extends BiometricService {
  _FakeService({
    this.hardware = true,
    this.authResult = BiometricStatus.success,
  });

  bool hardware;
  bool available = true;
  BiometricKind kind = BiometricKind.fingerprint;
  BiometricStatus authResult;
  int authCalls = 0;
  String? lastReason;

  @override
  Future<bool> hasHardware() async => hardware;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricKind> getBiometricKind() async => kind;

  @override
  Future<BiometricStatus> authenticate({
    required String reason,
    bool biometricOnly = true,
    bool stickyAuth = true,
    bool useErrorDialogs = true,
  }) async {
    authCalls++;
    lastReason = reason;
    return authResult;
  }
}

void main() {
  group('BiometricUnlockResult', () {
    test('success carries a secret and isSuccess is true', () {
      const r = BiometricUnlockResult.success('abc');
      expect(r.status, BiometricStatus.success);
      expect(r.secret, 'abc');
      expect(r.isSuccess, isTrue);
    });

    test('failure has no secret and isSuccess is false', () {
      const r = BiometricUnlockResult.failure(BiometricStatus.canceled);
      expect(r.status, BiometricStatus.canceled);
      expect(r.secret, isNull);
      expect(r.isSuccess, isFalse);
    });

    test('toString never leaks the secret value', () {
      const r = BiometricUnlockResult.success('super-secret-token');
      expect(r.toString(), isNot(contains('super-secret-token')));
    });
  });

  group('BiometricConfig', () {
    test('has secure, sensible defaults', () {
      const c = BiometricConfig();
      expect(c.biometricOnly, isTrue);
      expect(c.stickyAuth, isTrue);
      expect(c.secretKey, isNotEmpty);
      expect(c.enabledKey, isNotEmpty);
    });

    test('copyWith overrides only the given fields', () {
      const c = BiometricConfig(secretKey: 'a', signInReason: 'r');
      final c2 = c.copyWith(secretKey: 'b');
      expect(c2.secretKey, 'b');
      expect(c2.signInReason, 'r');
      expect(c2.biometricOnly, c.biometricOnly);
    });
  });

  group('BiometricLogin.saveSecret', () {
    test('stores the secret and enables when biometric passes', () async {
      final storage = _MemoryStorage();
      final service = _FakeService(authResult: BiometricStatus.success);
      final biometric = BiometricLogin(service: service, storage: storage);

      final ok = await biometric.saveSecret('token-123');

      expect(ok, isTrue);
      expect(service.authCalls, 1);
      expect(await biometric.isEnabled(), isTrue);
      expect(await storage.read(const BiometricConfig().secretKey), 'token-123');
    });

    test('does not store when the biometric prompt is cancelled', () async {
      final storage = _MemoryStorage();
      final service = _FakeService(authResult: BiometricStatus.canceled);
      final biometric = BiometricLogin(service: service, storage: storage);

      final ok = await biometric.saveSecret('token-123');

      expect(ok, isFalse);
      expect(await biometric.isEnabled(), isFalse);
      expect(await storage.read(const BiometricConfig().secretKey), isNull);
    });

    test('rejects an empty secret without prompting', () async {
      final service = _FakeService();
      final biometric = BiometricLogin(service: service, storage: _MemoryStorage());

      final ok = await biometric.saveSecret('');

      expect(ok, isFalse);
      expect(service.authCalls, 0);
    });
  });

  group('BiometricLogin.unlock', () {
    test('returns the stored secret on success', () async {
      final storage = _MemoryStorage();
      final service = _FakeService(authResult: BiometricStatus.success);
      final biometric = BiometricLogin(service: service, storage: storage);

      await biometric.saveSecret('my-secret');
      final result = await biometric.unlock();

      expect(result.isSuccess, isTrue);
      expect(result.secret, 'my-secret');
    });

    test('reports notAvailable when there is no hardware', () async {
      final service = _FakeService(hardware: false);
      final biometric = BiometricLogin(service: service, storage: _MemoryStorage());

      final result = await biometric.unlock();

      expect(result.status, BiometricStatus.unavailable);
      expect(result.secret, isNull);
    });

    test('reports notEnabled when nothing was saved', () async {
      final service = _FakeService();
      final biometric = BiometricLogin(service: service, storage: _MemoryStorage());

      final result = await biometric.unlock();

      expect(result.status, BiometricStatus.notEnabled);
    });

    test('propagates the biometric failure status', () async {
      final storage = _MemoryStorage();
      // Save with a passing service, then flip to lockedOut for the unlock.
      final service = _FakeService(authResult: BiometricStatus.success);
      final biometric = BiometricLogin(service: service, storage: storage);
      await biometric.saveSecret('s');

      service.authResult = BiometricStatus.lockedOut;
      final result = await biometric.unlock();

      expect(result.status, BiometricStatus.lockedOut);
      expect(result.secret, isNull);
    });
  });

  group('BiometricLogin.deleteSecret', () {
    test('clears the secret and disables', () async {
      final service = _FakeService();
      final biometric = BiometricLogin(service: service, storage: _MemoryStorage());

      await biometric.saveSecret('s');
      expect(await biometric.isEnabled(), isTrue);

      await biometric.deleteSecret();
      expect(await biometric.isEnabled(), isFalse);
      final result = await biometric.unlock();
      expect(result.status, BiometricStatus.notEnabled);
    });
  });
}
