/// Backend-agnostic biometric (Face ID / Touch ID / fingerprint) gate with
/// secure secret storage and a ready-made login button for Flutter.
///
/// Import only this file:
///
/// ```dart
/// import 'package:biometric_auth_login/biometric_auth_login.dart';
/// ```
///
/// The package protects a single **opaque secret** behind the device's
/// biometrics. It never interprets that secret — your app decides whether it is
/// a token, JSON credentials, or anything else — so it stays completely
/// independent of any backend.
///
/// See [BiometricLogin] for the core API and [BiometricLoginButton] for the UI.
library biometric_auth_login;

export 'src/biometric_button.dart'
    show BiometricLoginButton, BiometricButtonStyle;
export 'src/biometric_config.dart' show BiometricConfig;
export 'src/biometric_login_base.dart' show BiometricLogin;
export 'src/biometric_service.dart' show BiometricService;
export 'src/biometric_storage.dart'
    show BiometricSecretStorage, SecureBiometricStorage;
export 'src/biometric_types.dart'
    show
        BiometricKind,
        BiometricStatus,
        BiometricStatusX,
        BiometricUnlockResult;
