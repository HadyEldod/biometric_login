import 'package:local_auth/local_auth.dart';

import 'biometric_types.dart';

/// Low-level wrapper around `local_auth`.
///
/// This class knows nothing about storage or secrets — it only answers "can we
/// use biometrics?", "which kind?", and "run the biometric prompt". It is used
/// by [BiometricLogin]; you rarely need it directly.
///
/// All methods are overridable so tests can supply a fake without a real device.
class BiometricService {
  /// Creates a service. Pass [localAuth] to inject a fake in tests; otherwise a
  /// real [LocalAuthentication] instance is used.
  BiometricService({LocalAuthentication? localAuth})
      : _auth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True only when biometric hardware exists (regardless of enrollment). Used
  /// to tell "no hardware" apart from "hardware but nothing enrolled".
  Future<bool> hasHardware() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// True when the device has biometric hardware AND at least one biometric is
  /// enrolled. Never throws.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// All biometric affordances the app can currently use, mapped to
  /// [BiometricKind]. Returns an empty list when none are available or on error.
  ///
  /// Note the platform may report opaque "strong"/"weak" classes rather than a
  /// concrete modality; those surface as [BiometricKind.generic].
  Future<List<BiometricKind>> getAvailableBiometrics() async {
    List<BiometricType> types;
    try {
      types = await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
    final kinds = <BiometricKind>{};
    for (final t in types) {
      if (t == BiometricType.face) {
        kinds.add(BiometricKind.face);
      } else if (t == BiometricType.fingerprint) {
        kinds.add(BiometricKind.fingerprint);
      } else if (t == BiometricType.iris) {
        kinds.add(BiometricKind.iris);
      } else {
        kinds.add(BiometricKind.generic);
      }
    }
    return kinds.toList(growable: false);
  }

  /// Picks the most representative biometric affordance for the current device.
  Future<BiometricKind> getBiometricKind() async {
    List<BiometricType> types;
    try {
      types = await _auth.getAvailableBiometrics();
    } catch (_) {
      return BiometricKind.none;
    }
    if (types.isEmpty) return BiometricKind.none;
    if (types.contains(BiometricType.face)) return BiometricKind.face;
    if (types.contains(BiometricType.fingerprint)) {
      return BiometricKind.fingerprint;
    }
    if (types.contains(BiometricType.iris)) return BiometricKind.iris;
    // BiometricType.strong / weak are opaque on some devices.
    return BiometricKind.generic;
  }

  /// Runs the system biometric prompt and maps the outcome to a
  /// [BiometricStatus]. Returns [BiometricStatus.success] on success.
  ///
  /// [useErrorDialogs] is accepted for backwards compatibility but no longer
  /// forwarded: `local_auth` 3.x always treats it as `false`.
  Future<BiometricStatus> authenticate({
    required String reason,
    bool biometricOnly = true,
    bool stickyAuth = true,
    bool useErrorDialogs = true,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: biometricOnly,
        persistAcrossBackgrounding: stickyAuth,
      );
      return ok ? BiometricStatus.success : BiometricStatus.canceled;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.uiUnavailable:
          return BiometricStatus.unavailable;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          return BiometricStatus.notEnrolled;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          return BiometricStatus.lockedOut;
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.userRequestedFallback:
          return BiometricStatus.canceled;
        default:
          return BiometricStatus.failed;
      }
    } catch (_) {
      return BiometricStatus.failed;
    }
  }
}
