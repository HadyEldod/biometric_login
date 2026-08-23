# biometric_auth_login

Backend-agnostic biometric (Face ID / Touch ID / fingerprint) gate with secure
secret storage and a ready-made login button for Flutter.

The package protects a single **opaque secret** behind the device's biometrics.
It never interprets that secret — *your app* decides whether it's a token, JSON
credentials, or anything else — so the package stays completely independent of
any backend, API, or state-management choice.

## Features

- 🔎 Biometric availability & kind detection (face / fingerprint / iris).
- 👆 Face ID / Touch ID / fingerprint prompt with graceful error handling
  (cancel, lockout, not enrolled, unavailable).
- 🔐 Secure storage only — Android Keystore-backed `EncryptedSharedPreferences`
  and iOS Keychain. `SharedPreferences`, plain files, etc. are never used.
- 🧩 Simple opaque-secret API: `saveSecret` / `unlock` / `deleteSecret` /
  `isEnabled`.
- 🎨 Ready-made, themeable `BiometricLoginButton` with auto icon/label.
- 🚫 No backend, API, or login logic inside the package.
- ✅ Null-safe, documented public API, unit + widget tests, runnable example.

## Installation

```yaml
dependencies:
  biometric_auth_login: ^1.0.0
```

```dart
import 'package:biometric_auth_login/biometric_auth_login.dart';
```

## Platform setup

### Android

1. `local_auth` requires the host activity to be a `FragmentActivity`. In
   `android/app/src/main/kotlin/.../MainActivity.kt`:

   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity

   class MainActivity : FlutterFragmentActivity()
   ```

2. Add the biometric permissions to `AndroidManifest.xml`:

   ```xml
   <uses-permission android:name="android.permission.USE_BIOMETRIC" />
   <!-- Legacy fingerprint support for Android < 9 -->
   <uses-permission android:name="android.permission.USE_FINGERPRINT" />
   ```

### iOS

Add a Face ID usage description to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to securely sign in to your account.</string>
```

## Basic usage

```dart
final biometric = BiometricLogin(
  config: const BiometricConfig(secretKey: 'my_app.session'),
);

// Can we use biometrics on this device right now?
if (await biometric.isAvailable()) {

  // Store whatever your app wants protected (a token, JSON, ...).
  await biometric.saveSecret(mySecretString);

  // Later, unlock it behind the biometric gate.
  final result = await biometric.unlock();
  if (result.isSuccess) {
    final secret = result.secret!; // hand this to YOUR login logic
  }

  // Disable / clear (e.g. on logout).
  await biometric.deleteSecret();
}
```

The secret is opaque. A common pattern is to store JSON credentials or a token:

```dart
await biometric.saveSecret(jsonEncode({'username': u, 'password': p}));
// ...
final creds = jsonDecode(result.secret!) as Map<String, dynamic>;
```

## API

### `saveSecret(String secret, {String? reason}) → Future<bool>`

Runs the biometric prompt and, only if it succeeds, writes `secret` to secure
storage and marks biometric login as enabled. Returns `true` on success;
`false` if `secret` is empty, the prompt is cancelled/fails, or storage fails.
Call this right after your app already has a valid secret (e.g. just after a
successful password login).

### `unlock({String? reason}) → Future<BiometricUnlockResult>`

Checks availability, verifies a secret is stored, runs the biometric prompt, and
returns the stored secret. Inspect the result:

```dart
final result = await biometric.unlock();
if (result.isSuccess) {
  use(result.secret!);
} else {
  switch (result.status) {
    case BiometricStatus.canceled:    // user dismissed the prompt
    case BiometricStatus.lockedOut:   // too many attempts
    case BiometricStatus.notEnrolled: // no biometrics enrolled
    case BiometricStatus.notEnabled:  // nothing saved yet
    case BiometricStatus.unavailable: // no hardware / no passcode
    // ...
    default: break;
  }
}
```

### `deleteSecret() → Future<void>`

Removes the stored secret and disables biometric login. Best-effort and never
throws, so it is safe to call on logout.

### Other members

- `isAvailable()` — hardware present **and** at least one biometric enrolled.
- `hasHardware()` — hardware present, regardless of enrollment.
- `isEnabled()` — a secret has been saved for this app.
- `getBiometricKind()` — `BiometricKind.face` / `fingerprint` / `iris` /
  `generic` / `none`, for choosing an icon/label.
- `BiometricConfig` — storage keys, prompt reasons, `biometricOnly`, and the
  Android/iOS secure-storage options.
- `BiometricSecretStorage` — implement it to plug in a custom secure store; the
  default `SecureBiometricStorage` uses `flutter_secure_storage`.

## `BiometricLoginButton`

```dart
BiometricLoginButton(
  biometric: biometric,
  onUnlocked: (secret) async {
    // App-specific login with the unlocked secret.
  },
  onError: (status) {
    // Show a message for canceled / lockedOut / ...
  },
)
```

The button auto-detects the biometric kind to pick its icon and label, shows a
loading indicator while the prompt is up, and contains no login logic. Customize
it with `BiometricButtonStyle`, or override `label` / `icon` / `kind`. For full
manual control (run your own gate), pass `onPressed` instead of
`biometric` / `onUnlocked`.

## Security considerations

- The secret lives only in platform-encrypted secure storage
  (Android Keystore / iOS Keychain). Insecure stores are never used.
- A biometric success is only a **gate**: `unlock()` hands your secret back, but
  your app remains responsible for using it to authenticate against your
  backend. Treat the returned secret as sensitive and keep it in memory only as
  long as needed.
- iOS Keychain items use `first_unlock_this_device` accessibility and Android
  keys are Keystore-bound, so a stored secret is not usable after being restored
  onto a different device — the user re-enrols there.
- The device's own biometric enrollment is the trust anchor. If someone else's
  biometric is enrolled on the device, they can pass the gate. This is inherent
  to `local_auth`, not specific to this package.

## Limitations

- **No backend logic.** The package deliberately does not perform any login; it
  only gates access to your stored secret. Wiring the secret to your auth flow
  is up to your app.
- **One secret per config.** Each `BiometricLogin` manages a single secret keyed
  by `BiometricConfig.secretKey`. Use different keys for multiple secrets.
- **Platform coverage.** Targets Android and iOS (the platforms `local_auth`
  supports for biometrics). Other platforms are not supported.
- **Default prompt strings are English.** Pass localized `signInReason` /
  `enableReason` (or the per-call `reason`) for other languages.

## Example

See [`example/`](example/) for a runnable app that demonstrates checking
availability, saving a secret, using `BiometricLoginButton`, unlocking, reading
the returned secret, and deleting it.

## License

MIT — see [LICENSE](LICENSE).
