import 'biometric_config.dart';
import 'biometric_service.dart';
import 'biometric_storage.dart';
import 'biometric_types.dart';

/// The main entry point of the package.
///
/// [BiometricLogin] combines the biometric gate ([BiometricService]) with secure
/// storage ([BiometricSecretStorage]) to protect a single **opaque secret**
/// behind Face ID / Touch ID / fingerprint.
///
/// The package never interprets the secret — the consuming app decides what it
/// means (a token, JSON credentials, anything). A successful biometric check is
/// only a GATE: it returns the stored secret, and the app remains responsible
/// for whatever authentication that secret enables.
///
/// ```dart
/// final biometric = BiometricLogin(
///   config: const BiometricConfig(secretKey: 'my_app.session'),
/// );
///
/// if (await biometric.isAvailable()) {
///   await biometric.saveSecret(myToken);      // gate → store
///   final result = await biometric.unlock();  // gate → result.secret
///   if (result.isSuccess) use(result.secret!);
///   await biometric.deleteSecret();
/// }
/// ```
class BiometricLogin {
  BiometricLogin({
    this.config = const BiometricConfig(),
    BiometricService? service,
    BiometricSecretStorage? storage,
  })  : _service = service ?? BiometricService(),
        _storage = storage ?? SecureBiometricStorage(config: config);

  /// The active configuration (keys, prompt reasons, storage options).
  final BiometricConfig config;

  final BiometricService _service;
  final BiometricSecretStorage _storage;

  // ---------------------------------------------------------------------------
  // Capability
  // ---------------------------------------------------------------------------

  /// True only when biometric hardware exists (regardless of enrollment).
  Future<bool> hasHardware() => _service.hasHardware();

  /// True when the device has biometric hardware AND at least one enrolled
  /// biometric, i.e. biometric authentication can actually run right now.
  Future<bool> isAvailable() => _service.isAvailable();

  /// The most representative biometric affordance for the current device, for
  /// picking an icon/label in the UI.
  Future<BiometricKind> getBiometricKind() => _service.getBiometricKind();

  // ---------------------------------------------------------------------------
  // Enrollment state
  // ---------------------------------------------------------------------------

  /// Whether a secret has been saved for this app (biometric login is set up).
  Future<bool> isEnabled() async {
    try {
      final enabled = await _storage.read(config.enabledKey);
      if (enabled != 'true') return false;
      final secret = await _storage.read(config.secretKey);
      return secret != null && secret.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Secret lifecycle
  // ---------------------------------------------------------------------------

  /// Stores [secret] behind the biometric gate.
  ///
  /// Runs the biometric prompt (using [BiometricConfig.enableReason]) and, only
  /// if it succeeds, writes the secret to secure storage. Returns `true` on
  /// success; `false` if [secret] is empty, the prompt is cancelled/fails, or
  /// storage fails.
  ///
  /// Pass [reason] to override the prompt text for this call.
  Future<bool> saveSecret(String secret, {String? reason}) async {
    if (secret.isEmpty) return false;
    try {
      final status = await _service.authenticate(
        reason: reason ?? config.enableReason,
        biometricOnly: config.biometricOnly,
        stickyAuth: config.stickyAuth,
        useErrorDialogs: config.useErrorDialogs,
      );
      if (status != BiometricStatus.success) return false;

      await _storage.write(config.secretKey, secret);
      await _storage.write(config.enabledKey, 'true');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs the biometric gate and, on success, returns the stored secret.
  ///
  /// The flow is: availability check → "is a secret saved?" → biometric prompt
  /// (using [BiometricConfig.signInReason]) → read secret. Every failure branch
  /// is reported via [BiometricUnlockResult.status]. On success,
  /// [BiometricUnlockResult.secret] holds the opaque secret.
  ///
  /// Pass [reason] to override the prompt text for this call.
  Future<BiometricUnlockResult> unlock({String? reason}) async {
    // Availability.
    if (!await _service.hasHardware()) {
      return const BiometricUnlockResult.failure(BiometricStatus.unavailable);
    }
    if (!await _service.isAvailable()) {
      return const BiometricUnlockResult.failure(BiometricStatus.notEnrolled);
    }

    // Must have a saved secret.
    if (!await isEnabled()) {
      return const BiometricUnlockResult.failure(BiometricStatus.notEnabled);
    }

    // Biometric gate.
    final status = await _service.authenticate(
      reason: reason ?? config.signInReason,
      biometricOnly: config.biometricOnly,
      stickyAuth: config.stickyAuth,
      useErrorDialogs: config.useErrorDialogs,
    );
    if (status != BiometricStatus.success) {
      return BiometricUnlockResult.failure(status);
    }

    // Read the protected secret.
    String? secret;
    try {
      secret = await _storage.read(config.secretKey);
    } catch (_) {
      return const BiometricUnlockResult.failure(BiometricStatus.storageError);
    }
    if (secret == null || secret.isEmpty) {
      // Enabled flag without a secret: clean up and report "not enabled".
      await deleteSecret();
      return const BiometricUnlockResult.failure(BiometricStatus.notEnabled);
    }

    return BiometricUnlockResult.success(secret);
  }

  /// Removes the stored secret and disables biometric login. Best-effort: never
  /// throws (safe to call on logout).
  Future<void> deleteSecret() async {
    try {
      await _storage.delete(config.secretKey);
      await _storage.delete(config.enabledKey);
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
