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

  /// An unexpected error occurred.
  unknown,
}

/// The result of [BiometricLogin.unlock].
///
/// On [BiometricStatus.success], [secret] holds the previously saved opaque
/// secret. On any other status, [secret] is `null` and [status] explains why.
class BiometricUnlockResult {
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
