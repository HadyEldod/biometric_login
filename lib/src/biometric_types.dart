// Core value types for the biometric_login package.
//
// This file has ZERO dependencies (not even Flutter) so it stays trivially
// portable and testable.

/// The biometric affordance the current device leans towards. The UI uses this
/// to pick an appropriate icon/label automatically, without asking the user to
/// choose Face vs Fingerprint manually.
enum BiometricKind {
  /// No biometric hardware, or none usable.
  none,

  /// Face-based recognition (iOS Face ID, Android face unlock).
  face,

  /// Fingerprint / Touch ID.
  fingerprint,

  /// Iris scanning (some Android devices).
  iris,

  /// Hardware is present but its exact modality is opaque; show a generic
  /// biometric affordance.
  generic,
}

/// The outcome of a biometric operation (authenticate / save / unlock).
enum BiometricStatus {
  /// The operation completed successfully.
  success,

  /// No biometric hardware, or biometrics are currently unavailable (e.g. no
  /// device passcode set).
  unavailable,

  /// Hardware exists but the user has not enrolled any biometrics.
  notEnrolled,

  /// No secret has been saved for this app yet — nothing to unlock.
  notEnabled,

  /// The user cancelled the system prompt.
  canceled,

  /// The OS temporarily/permanently locked out biometrics (too many attempts).
  lockedOut,

  /// The biometric check itself failed (mismatch / generic auth failure).
  failed,

  /// Reading from / writing to secure storage failed.
  storageError,

  /// Another biometric operation for this instance was already in progress, so
  /// this call was rejected to avoid showing two system prompts at once. Safe to
  /// retry once the first operation finishes.
  busy,

  /// An unexpected error occurred.
  unknown,
}

/// Convenience classification of a [BiometricStatus], so UIs can decide what to
/// do next without hard-coding every enum value.
///
/// Every status maps to at most **one** actionable bucket below (they are
/// mutually exclusive), so a simple `if/else` chain over
/// [isSuccess] → [requiresEnrollmentInApp] → [requiresDeviceSetup] →
/// [shouldFallBack] → [canRetry] covers each case exactly once.
/// [BiometricStatus.unknown] is deliberately left in no bucket — treat it as a
/// generic failure and handle it explicitly.
///
/// These are deliberately conservative: they never promise more than the
/// underlying platform can guarantee.
///
/// | status         | isSuccess | canRetry | requiresDeviceSetup | requiresEnrollmentInApp | shouldFallBack |
/// |----------------|:--------:|:-------:|:-------------------:|:-----------------------:|:--------------:|
/// | success        | ✅ | | | | |
/// | canceled       | | ✅ | | | |
/// | failed         | | ✅ | | | |
/// | busy           | | ✅ | | | |
/// | notEnrolled    | | | ✅ | | |
/// | notEnabled     | | | | ✅ | |
/// | unavailable    | | | | | ✅ |
/// | lockedOut      | | | | | ✅ |
/// | storageError   | | | | | ✅ |
/// | unknown        | | | | | |
extension BiometricStatusX on BiometricStatus {
  /// Whether the operation completed successfully.
  bool get isSuccess => this == BiometricStatus.success;

  /// Whether retrying the *same* operation might succeed without the user first
  /// changing anything on the device: they dismissed the prompt
  /// ([BiometricStatus.canceled]), a single attempt failed
  /// ([BiometricStatus.failed]), or the instance was momentarily
  /// [BiometricStatus.busy].
  ///
  /// Note: [BiometricStatus.storageError] is intentionally NOT retryable — its
  /// usual cause (a key invalidated by an enrollment change) would fail
  /// identically on retry; it maps to [shouldFallBack] instead.
  bool get canRetry =>
      this == BiometricStatus.canceled ||
      this == BiometricStatus.failed ||
      this == BiometricStatus.busy;

  /// Whether the user must set something up in the OS settings before this can
  /// work: the device has biometric hardware but nothing usable is enrolled
  /// ([BiometricStatus.notEnrolled]). A good moment to show
  /// "Enable biometrics in Settings".
  bool get requiresDeviceSetup => this == BiometricStatus.notEnrolled;

  /// Whether biometric login has not been set up in *your app* yet
  /// ([BiometricStatus.notEnabled]) — call `saveSecret` first.
  bool get requiresEnrollmentInApp => this == BiometricStatus.notEnabled;

  /// Whether the biometric path can't produce a secret right now, so the app
  /// should fall back to another authentication method (e.g. password) and, if
  /// appropriate, re-establish the secret afterwards. Covers: no usable
  /// biometric hardware ([BiometricStatus.unavailable]), an OS lockout
  /// ([BiometricStatus.lockedOut]), and a stored secret that could not be read
  /// ([BiometricStatus.storageError]).
  bool get shouldFallBack =>
      this == BiometricStatus.unavailable ||
      this == BiometricStatus.lockedOut ||
      this == BiometricStatus.storageError;
}

/// The result of [BiometricLogin.unlock].
///
/// On [BiometricStatus.success], [secret] holds the previously saved opaque
/// secret. On any other status, [secret] is `null` and [status] explains why.
class BiometricUnlockResult {
  /// Creates a result with the given [status] and optional [secret]. Prefer the
  /// [BiometricUnlockResult.success] / [BiometricUnlockResult.failure] named
  /// constructors, which keep [status] and [secret] consistent.
  const BiometricUnlockResult(this.status, {this.secret});

  /// Convenience constructor for a successful unlock.
  const BiometricUnlockResult.success(this.secret)
      : status = BiometricStatus.success;

  /// Convenience constructor for a failed unlock.
  const BiometricUnlockResult.failure(this.status) : secret = null;

  /// Why the unlock succeeded or failed.
  final BiometricStatus status;

  /// The unlocked opaque secret, or `null` when [status] is not
  /// [BiometricStatus.success].
  final String? secret;

  /// Whether the unlock succeeded and [secret] is available.
  bool get isSuccess =>
      status == BiometricStatus.success && secret != null && secret!.isNotEmpty;

  @override
  String toString() =>
      'BiometricUnlockResult(status: $status, secret: ${secret == null ? 'null' : '***'})';
}
