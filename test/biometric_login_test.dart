import 'dart:async';

import 'package:biometric_auth_login/biometric_auth_login.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [BiometricSecretStorage] for tests. Set [failReads]/[failWrites]/
/// [failDeletes] to simulate a failing secure store.
class _MemoryStorage implements BiometricSecretStorage {
  final Map<String, String> _data = {};
  bool failReads = false;
  bool failWrites = false;
  bool failDeletes = false;

  /// When set, reads of exactly this key throw (models one entry that can no
  /// longer be decrypted, e.g. after a biometric enrollment change).
  String? failReadKey;

  @override
  Future<String?> read(String key) async {
    if (failReads || key == failReadKey) throw StateError('read failed');
    return _data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('write failed');
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) throw StateError('delete failed');
    _data.remove(key);
  }
}

/// Fake [BiometricService] with scriptable outcomes — no real device needed.
///
/// Set [gate] to a pending completer to hold `authenticate` open (so overlapping
/// calls can be exercised); complete it to release the prompt.
class _FakeService extends BiometricService {
  _FakeService({
    this.hardware = true,
    this.authResult = BiometricStatus.success,
  });

  bool hardware;
  bool available = true;
  BiometricKind kind = BiometricKind.fingerprint;
  List<BiometricKind> availableKinds = const [BiometricKind.fingerprint];
  BiometricStatus authResult;
  int authCalls = 0;
  String? lastReason;
  Completer<void>? gate;

  @override
  Future<bool> hasHardware() async => hardware;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricKind> getBiometricKind() async => kind;

  @override
  Future<List<BiometricKind>> getAvailableBiometrics() async => availableKinds;

  @override
  Future<BiometricStatus> authenticate({
    required String reason,
    bool biometricOnly = true,
    bool stickyAuth = true,
    bool useErrorDialogs = true,
  }) async {
    authCalls++;
    lastReason = reason;
    if (gate != null) await gate!.future;
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
      expect(
          await storage.read(const BiometricConfig().secretKey), 'token-123');
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
      final biometric =
          BiometricLogin(service: service, storage: _MemoryStorage());

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
      final biometric =
          BiometricLogin(service: service, storage: _MemoryStorage());

      final result = await biometric.unlock();

      expect(result.status, BiometricStatus.unavailable);
      expect(result.secret, isNull);
    });

    test('reports notEnabled when nothing was saved', () async {
      final service = _FakeService();
      final biometric =
          BiometricLogin(service: service, storage: _MemoryStorage());

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
      final biometric =
          BiometricLogin(service: service, storage: _MemoryStorage());

      await biometric.saveSecret('s');
      expect(await biometric.isEnabled(), isTrue);

      await biometric.deleteSecret();
      expect(await biometric.isEnabled(), isFalse);
      final result = await biometric.unlock();
      expect(result.status, BiometricStatus.notEnabled);
    });

    test('never throws even when the store fails', () async {
      final storage = _MemoryStorage();
      final biometric =
          BiometricLogin(service: _FakeService(), storage: storage);
      await biometric.saveSecret('s');

      storage.failDeletes = true;
      // Must not throw.
      await biometric.deleteSecret();
    });
  });

  group('storage failures', () {
    test('saveSecret returns false when the write fails', () async {
      final storage = _MemoryStorage()..failWrites = true;
      final biometric =
          BiometricLogin(service: _FakeService(), storage: storage);

      final ok = await biometric.saveSecret('s');

      expect(ok, isFalse);
    });

    test('unlock reports storageError when the secret cannot be read',
        () async {
      final storage = _MemoryStorage();
      final biometric =
          BiometricLogin(service: _FakeService(), storage: storage);
      await biometric.saveSecret('s');

      // The enabled flag still reads, but the secret entry can't be decrypted.
      storage.failReadKey = const BiometricConfig().secretKey;
      final result = await biometric.unlock();

      expect(result.status, BiometricStatus.storageError);
      expect(result.secret, isNull);
    });
  });

  group('lifecycle', () {
    test('enable -> logout -> unlock reports notEnabled', () async {
      final biometric =
          BiometricLogin(service: _FakeService(), storage: _MemoryStorage());
      await biometric.saveSecret('s');
      await biometric.deleteSecret();

      final result = await biometric.unlock();
      expect(result.status, BiometricStatus.notEnabled);
    });

    test('enable -> logout -> re-enable then unlock returns new secret',
        () async {
      final biometric =
          BiometricLogin(service: _FakeService(), storage: _MemoryStorage());
      await biometric.saveSecret('first');
      await biometric.deleteSecret();
      await biometric.saveSecret('second');

      final result = await biometric.unlock();
      expect(result.secret, 'second');
    });

    test('unlock cleans up an enabled flag left without a secret', () async {
      final storage = _MemoryStorage();
      final biometric =
          BiometricLogin(service: _FakeService(), storage: storage);
      // Simulate a half-written state: enabled flag but no secret.
      await storage.write(const BiometricConfig().enabledKey, 'true');

      final result = await biometric.unlock();

      expect(result.status, BiometricStatus.notEnabled);
      expect(await biometric.isEnabled(), isFalse);
    });
  });

  group('concurrency', () {
    test('a second unlock while one is in flight is rejected as busy',
        () async {
      final service = _FakeService();
      final biometric =
          BiometricLogin(service: service, storage: _MemoryStorage());
      await biometric.saveSecret('s');

      // Now hold the next prompt open and start two overlapping unlocks.
      service.gate = Completer<void>();
      final first = biometric.unlock(); // parks on the gate
      await Future<void>.delayed(Duration.zero);
      final second = await biometric.unlock(); // rejected immediately

      expect(second.status, BiometricStatus.busy);

      service.gate!.complete();
      final firstResult = await first;
      expect(firstResult.isSuccess, isTrue);
      // Only the first (save aside) unlock reached the prompt.
      expect(service.authCalls, 2); // 1 for saveSecret, 1 for the first unlock
    });

    test('saveSecret while an unlock is in flight is rejected', () async {
      final service = _FakeService();
      final biometric =
          BiometricLogin(service: service, storage: _MemoryStorage());
      await biometric.saveSecret('s');

      service.gate = Completer<void>();
      final unlocking = biometric.unlock();
      await Future<void>.delayed(Duration.zero);
      final saved = await biometric.saveSecret('other');

      expect(saved, isFalse);
      service.gate!.complete();
      await unlocking;
    });

    test('the guard is released so later operations still work', () async {
      final biometric =
          BiometricLogin(service: _FakeService(), storage: _MemoryStorage());
      await biometric.saveSecret('s');

      final r1 = await biometric.unlock();
      final r2 = await biometric.unlock();
      expect(r1.isSuccess, isTrue);
      expect(r2.isSuccess, isTrue);
    });

    test('deleteSecret wins over an in-flight unlock (no deadlock)', () async {
      final service = _FakeService();
      final biometric =
          BiometricLogin(service: service, storage: _MemoryStorage());
      await biometric.saveSecret('s');

      // Park the unlock inside the prompt, then log out underneath it.
      service.gate = Completer<void>();
      final unlocking = biometric.unlock();
      await Future<void>.delayed(Duration.zero);
      await biometric.deleteSecret(); // not blocked by the busy guard

      service.gate!.complete();
      final result = await unlocking;

      // The prompt "passed" but the secret was gone: reported as notEnabled.
      expect(result.status, BiometricStatus.notEnabled);
      expect(await biometric.isEnabled(), isFalse);
      // And the guard was released, so a fresh operation is accepted.
      expect(
          await biometric.unlock(),
          predicate<BiometricUnlockResult>(
              (r) => r.status == BiometricStatus.notEnabled));
    });
  });

  group('capability API', () {
    test('canAuthenticate reflects service availability', () async {
      final service = _FakeService()..available = false;
      final biometric =
          BiometricLogin(service: service, storage: _MemoryStorage());
      expect(await biometric.canAuthenticate(), isFalse);

      service.available = true;
      expect(await biometric.canAuthenticate(), isTrue);
    });

    test('getAvailableBiometrics returns the service list', () async {
      final service = _FakeService()
        ..availableKinds = const [
          BiometricKind.face,
          BiometricKind.fingerprint
        ];
      final biometric =
          BiometricLogin(service: service, storage: _MemoryStorage());

      expect(
        await biometric.getAvailableBiometrics(),
        const [BiometricKind.face, BiometricKind.fingerprint],
      );
    });
  });

  group('BiometricStatusX', () {
    // The complete, authoritative truth table. Each row: the status and the
    // single bucket it belongs to ('' == unknown/no bucket). Every helper is
    // asserted for every status, so the buckets stay mutually exclusive.
    const successBucket = 'isSuccess';
    const retry = 'canRetry';
    const deviceSetup = 'requiresDeviceSetup';
    const appEnroll = 'requiresEnrollmentInApp';
    const fallBack = 'shouldFallBack';

    const table = <BiometricStatus, String>{
      BiometricStatus.success: successBucket,
      BiometricStatus.canceled: retry,
      BiometricStatus.failed: retry,
      BiometricStatus.busy: retry,
      BiometricStatus.notEnrolled: deviceSetup,
      BiometricStatus.notEnabled: appEnroll,
      BiometricStatus.unavailable: fallBack,
      BiometricStatus.lockedOut: fallBack,
      BiometricStatus.storageError: fallBack,
      BiometricStatus.unknown: '', // deliberately unclassified
    };

    test('covers every BiometricStatus value', () {
      expect(table.keys.toSet(), BiometricStatus.values.toSet());
    });

    table.forEach((status, bucket) {
      test('$status is classified as "${bucket.isEmpty ? 'none' : bucket}"',
          () {
        expect(status.isSuccess, bucket == successBucket,
            reason: 'isSuccess for $status');
        expect(status.canRetry, bucket == retry,
            reason: 'canRetry for $status');
        expect(status.requiresDeviceSetup, bucket == deviceSetup,
            reason: 'requiresDeviceSetup for $status');
        expect(status.requiresEnrollmentInApp, bucket == appEnroll,
            reason: 'requiresEnrollmentInApp for $status');
        expect(status.shouldFallBack, bucket == fallBack,
            reason: 'shouldFallBack for $status');
      });
    });

    test('buckets are mutually exclusive (at most one true per status)', () {
      for (final status in BiometricStatus.values) {
        final trues = [
          status.isSuccess,
          status.canRetry,
          status.requiresDeviceSetup,
          status.requiresEnrollmentInApp,
          status.shouldFallBack,
        ].where((b) => b).length;
        expect(trues, lessThanOrEqualTo(1), reason: '$status is in >1 bucket');
      }
    });
  });
}
