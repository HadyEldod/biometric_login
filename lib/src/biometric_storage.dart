import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'biometric_config.dart';

/// Abstraction over the secure key/value store used to persist the opaque
/// secret and the "enabled" flag.
///
/// Implement this to plug in a custom backing store (e.g. for tests, or a
/// different secure store). The default [SecureBiometricStorage] is backed by
/// `flutter_secure_storage` (Android Keystore / iOS Keychain) and is what you
/// get if you don't provide one.
abstract class BiometricSecretStorage {
  /// Const constructor so implementations can be `const`.
  const BiometricSecretStorage();

  /// Reads the value for [key], or `null` if absent.
  Future<String?> read(String key);

  /// Writes [value] under [key].
  Future<void> write(String key, String value);

  /// Deletes the value for [key] (no-op if absent).
  Future<void> delete(String key);
}

/// Default [BiometricSecretStorage] backed by `flutter_secure_storage`.
///
/// Secrets are stored using platform-encrypted storage only:
/// - Android: Keystore-backed cipher storage (`flutter_secure_storage` 11+; the
///   old `EncryptedSharedPreferences` backend was removed upstream and any
///   legacy data is auto-migrated).
/// - iOS / macOS: Keychain, bound to this device/installation.
/// - Windows: DPAPI-protected storage.
///
/// Plain `SharedPreferences`, files, or other insecure stores are never used.
class SecureBiometricStorage implements BiometricSecretStorage {
  /// Creates secure storage using the Android/iOS options from [config]. Pass
  /// [storage] to inject a fake `FlutterSecureStorage` in tests; otherwise the
  /// platform default is used.
  SecureBiometricStorage({
    BiometricConfig config = const BiometricConfig(),
    FlutterSecureStorage? storage,
  })  : _androidOptions = config.androidOptions,
        _iosOptions = config.iosOptions,
        _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final AndroidOptions _androidOptions;
  final IOSOptions _iosOptions;

  @override
  Future<String?> read(String key) => _storage.read(
        key: key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

  @override
  Future<void> write(String key, String value) => _storage.write(
        key: key,
        value: value,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );

  @override
  Future<void> delete(String key) => _storage.delete(
        key: key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
}
