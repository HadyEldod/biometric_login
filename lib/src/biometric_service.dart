import 'package:flutter/services.dart' show PlatformException;
import 'package:local_auth/error_codes.dart' as auth_error;
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
  BiometricService({LocalAuthentication? localAuth})
      : _auth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// True only when biometric hardware exists (regardless of enrollment). Used
  /// to tell "no hardware" apart from "hardware but nothing enrolled".
  Future<bool> hasHardware() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on PlatformException {
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
    } on PlatformException {
      return false;
    }
  }

  /// Picks the most representative biometric affordance for the current device.
  Future<BiometricKind> getBiometricKind() async {
    List<BiometricType> types;
    try {
      types = await _auth.getAvailableBiometrics();
    } on PlatformException {
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
  Future<BiometricStatus> authenticate({
    required String reason,
    bool biometricOnly = true,
    bool stickyAuth = true,
    bool useErrorDialogs = true,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: stickyAuth,
          useErrorDialogs: useErrorDialogs,
        ),
      );
      return ok ? BiometricStatus.success : BiometricStatus.canceled;
    } on PlatformException catch (e) {
      switch (e.code) {
        case auth_error.notAvailable:
        case auth_error.otherOperatingSystem:
        case auth_error.passcodeNotSet:
          return BiometricStatus.unavailable;
        case auth_error.notEnrolled:
          return BiometricStatus.notEnrolled;
        case auth_error.lockedOut:
        case auth_error.permanentlyLockedOut:
          return BiometricStatus.lockedOut;
        default:
          return BiometricStatus.failed;
      }
    }
  }
}
