import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Configuration for a [BiometricLogin] instance.
///
/// Everything here has a sensible, secure default, so most apps can use
/// `const BiometricConfig()`. Override [secretKey] when a single app stores more
/// than one biometric secret, and override the localized [signInReason] /
/// [enableReason] to control the text shown in the system biometric prompt.
class BiometricConfig {
  /// Creates an immutable configuration. Every field has a secure, sensible
  /// default, so `const BiometricConfig()` is a valid starting point; override
  /// only what you need.
  const BiometricConfig({
    this.secretKey = 'biometric_login.secret',
    this.enabledKey = 'biometric_login.enabled',
    this.signInReason = 'Authenticate to sign in',
    this.enableReason = 'Authenticate to enable biometric login',
    this.biometricOnly = true,
    this.stickyAuth = true,
    this.useErrorDialogs = true,
    this.androidOptions = _defaultAndroidOptions,
    this.iosOptions = _defaultIosOptions,
  });

  /// Secure-storage key under which the opaque secret is stored.
  final String secretKey;

  /// Secure-storage key holding the "biometric login enabled" flag. Kept in
  /// secure storage (not SharedPreferences) so clearing app preferences does not
  /// accidentally forget the enrollment.
  final String enabledKey;

  /// Localized message shown in the system prompt when [BiometricLogin.unlock]
  /// runs.
  final String signInReason;

  /// Localized message shown in the system prompt when [BiometricLogin.saveSecret]
  /// runs.
  final String enableReason;

  /// Requests that only true biometrics be accepted, with no device
  /// PIN/passcode fallback. Recommended (and the default) for protecting a
  /// stored secret.
  ///
  /// This is **best-effort and platform-dependent — not a hard guarantee**:
  /// - Android / iOS / macOS: enforced by the platform.
  /// - **Windows: NOT enforceable.** Windows Hello may still allow a PIN, so a
  ///   `true` value here does not guarantee a biometric-only check on Windows.
  ///
  /// Do not rely on this flag as a security boundary on Windows; treat it as a
  /// preference the platform honors where it can.
  final bool biometricOnly;

  /// Keeps the authentication session alive if the app is backgrounded during
  /// the prompt (maps to `local_auth`'s `persistAcrossBackgrounding`).
  final bool stickyAuth;

  /// Whether the platform should show its built-in error dialogs.
  ///
  /// Retained for source compatibility, but **ignored on `local_auth` 3.x**,
  /// which always treats this as `false`. It has no effect on current builds.
  final bool useErrorDialogs;

  /// Android secure-storage options. Defaults to the Keystore-backed cipher
  /// storage (`flutter_secure_storage` 11+ removed the `EncryptedSharedPreferences`
  /// backend and auto-migrates any legacy data).
  final AndroidOptions androidOptions;

  /// iOS secure-storage options. Defaults to a Keychain item that is bound to
  /// THIS device/installation (`first_unlock_this_device`) so it is never
  /// migrated to a new device via an encrypted/iCloud backup restore.
  final IOSOptions iosOptions;

  static const AndroidOptions _defaultAndroidOptions = AndroidOptions();

  static const IOSOptions _defaultIosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Returns a copy of this config with the given fields replaced.
  BiometricConfig copyWith({
    String? secretKey,
    String? enabledKey,
    String? signInReason,
    String? enableReason,
    bool? biometricOnly,
    bool? stickyAuth,
    bool? useErrorDialogs,
    AndroidOptions? androidOptions,
    IOSOptions? iosOptions,
  }) {
    return BiometricConfig(
      secretKey: secretKey ?? this.secretKey,
      enabledKey: enabledKey ?? this.enabledKey,
      signInReason: signInReason ?? this.signInReason,
      enableReason: enableReason ?? this.enableReason,
      biometricOnly: biometricOnly ?? this.biometricOnly,
      stickyAuth: stickyAuth ?? this.stickyAuth,
      useErrorDialogs: useErrorDialogs ?? this.useErrorDialogs,
      androidOptions: androidOptions ?? this.androidOptions,
      iosOptions: iosOptions ?? this.iosOptions,
    );
  }
}
