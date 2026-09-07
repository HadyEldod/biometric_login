# biometric_auth_login

A lightweight, **backend-agnostic biometric unlock layer** for Flutter. It gates a
single **opaque secret** behind the device's biometrics (Face ID / Touch ID /
fingerprint / Windows Hello) and stores it in platform-encrypted secure storage —
with a ready-made unlock button included.

The package never interprets the secret. *Your app* decides whether it's a
refresh token, a session id, or JSON credentials, so the package stays completely
independent of any backend, API, or state-management choice.

> **Biometric authentication here is a *local, device-level* gate.** It proves the
> person holding the device can pass the device's own biometric check — it does
> **not** prove identity to your backend. See [Security](#security).

## What you get

- 🔎 Biometric availability & kind detection (face / fingerprint / iris).
- 👆 System biometric prompt with graceful, typed error handling.
- 🔐 Secure storage only — Android Keystore-backed cipher storage, iOS/macOS
  Keychain, Windows DPAPI. `SharedPreferences`, plain files, etc. are never used.
- 🧩 Simple opaque-secret lifecycle: `saveSecret` / `unlock` / `deleteSecret`.
- 🛡️ Overlapping-prompt protection (no double prompts) built in.
- 🎨 Ready-made, themeable `BiometricLoginButton` with auto icon/label.
- ✅ Null-safe, documented API, unit + widget tests, runnable example.

## Why not just `local_auth`?

`local_auth` answers one question: *"did the device's biometric check pass?"* It
does not store anything. This package builds the common **unlock flow** on top of
it:

| | `local_auth` | `flutter_secure_storage` | **biometric_auth_login** |
|---|:---:|:---:|:---:|
| Biometric prompt | ✅ | ❌ | ✅ (wraps it) |
| Secure secret storage | ❌ | ✅ | ✅ (wraps it) |
| Secret lifecycle (enable/unlock/logout) | ❌ | ❌ | ✅ |
| Typed result + retry/settings hints | ❌ | ❌ | ✅ |
| Overlapping-prompt guard | ❌ | ❌ | ✅ |
| Ready-made unlock button | ❌ | ❌ | ✅ |
| Backend-agnostic (opaque secret) | — | — | ✅ |

If you only need the raw prompt, use `local_auth` directly. Use this package when
you want the whole *"unlock my stored session with biometrics"* flow.

## When to use it

- Re-opening an already-authenticated session without retyping a password.
- Unlocking sensitive screens (wallets, banking/finance, enterprise apps).
- Gating access to a locally stored refresh token / session credential.

## When **not** to use it

- As backend authentication or server-side identity verification — it isn't one.
- For biometric *registration* with a backend (e.g. WebAuthn/passkeys).
- For camera-based face recognition or custom biometric matching.

## Installation

```yaml
dependencies:
  biometric_auth_login: ^1.1.0
```

```dart
import 'package:biometric_auth_login/biometric_auth_login.dart';
```

## Platform setup

### Android

1. `local_auth` requires a `FragmentActivity`. In
   `android/app/src/main/kotlin/.../MainActivity.kt`:

   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity

   class MainActivity : FlutterFragmentActivity()
   ```

2. Add biometric permission(s) to `AndroidManifest.xml`:

   ```xml
   <uses-permission android:name="android.permission.USE_BIOMETRIC" />
   ```

### iOS

Add a Face ID usage description to `ios/Runner/Info.plist`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to securely sign in to your account.</string>
```

### macOS

- Enable the **Keychain Sharing** capability (required by
  `flutter_secure_storage`) in both `macos/Runner/DebugProfile.entitlements` and
  `macos/Runner/Release.entitlements`.
- Add `NSFaceIDUsageDescription` to `macos/Runner/Info.plist` for Touch ID.
- Requires a signed app and a Mac with Touch ID (or a paired Apple Watch /
  password fallback).

### Windows

- No extra setup for a default build. Biometrics use **Windows Hello**; secure
  storage uses **DPAPI**.
- ⚠️ `biometricOnly` is **not enforceable** on Windows — Windows Hello may allow
  a PIN fallback. See [Limitations](#limitations).

## Basic usage

```dart
final biometric = BiometricLogin(
  config: const BiometricConfig(secretKey: 'my_app.session'),
);

// Can we run a biometric prompt right now?
if (await biometric.canAuthenticate()) {
  // Store whatever your app wants protected (prefer a refresh/session token).
  await biometric.saveSecret(myRefreshToken);

  // Later, unlock it behind the biometric gate.
  final result = await biometric.unlock();
  if (result.isSuccess) {
    final secret = result.secret!; // hand this to YOUR login logic
  }

  // On logout, clear it.
  await biometric.deleteSecret();
}
```

## Full lifecycle

```dart
// 1. After a normal (password) login, capture a durable credential and gate it.
await biometric.saveSecret(session.refreshToken); // runs the enable prompt

// 2. On next launch, if set up, offer biometric unlock.
if (await biometric.isEnabled()) {
  final result = await biometric.unlock();       // runs the sign-in prompt
  if (result.isSuccess) {
    await api.refreshSession(result.secret!);     // your backend call
  }
}

// 3. On logout, delete the secret (never throws).
await biometric.deleteSecret();
```

## Handling the result

`unlock()` returns a `BiometricUnlockResult`. Use the `BiometricStatus`
extension helpers to decide what to do next — without hard-coding every case:

```dart
final result = await biometric.unlock();
if (result.isSuccess) {
  useSecret(result.secret!);
  return;
}

final status = result.status;
if (status.requiresEnrollmentInApp) {
  // notEnabled — nothing saved yet; run saveSecret first.
} else if (status.requiresDeviceSetup) {
  // notEnrolled — hardware exists but no biometric is enrolled.
  showMessage('Enable biometrics in Settings, then try again.');
} else if (status.shouldFallBack) {
  // unavailable / lockedOut / storageError — biometrics can't return the
  // secret now; fall back to password login (and re-save the secret if needed).
  showPasswordLogin();
} else if (status.canRetry) {
  // canceled / failed / busy — offer a retry.
  showRetry();
}
```

`BiometricStatus` values: `success`, `unavailable`, `notEnrolled`, `notEnabled`,
`canceled`, `lockedOut`, `failed`, `storageError`, `busy`, `unknown`.

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
loading indicator while the prompt is up, ignores taps while an unlock is already
running, and contains no login logic. Customize with `BiometricButtonStyle`, or
override `label` / `icon` / `kind`. For full manual control, pass `onPressed`
instead of `biometric` / `onUnlocked`.

## Security

- **Local gate, not backend auth.** A biometric success only hands your secret
  back. Your app remains responsible for using it to authenticate against your
  backend. A biometric pass does **not** prove identity to a server.
- **Store a revocable credential, not a raw password.** Prefer a refresh token or
  session id you can revoke server-side over a user's plaintext password.
- **Secrets never touch insecure storage.** They live only in platform-encrypted
  storage (Android Keystore / iOS·macOS Keychain / Windows DPAPI).
- **No logging of secrets.** The package never logs secret values, and
  `BiometricUnlockResult.toString()` masks the secret. Don't log `result.secret`
  yourself.
- **Device-bound.** iOS/macOS Keychain items use `first_unlock_this_device`
  accessibility and Android keys are Keystore-bound, so a restored backup on a new
  device can't reuse the secret — the user re-enrolls there.
- **The device enrollment is the trust anchor.** Anyone whose biometric is
  enrolled on the device can pass the gate. This is inherent to the platform, not
  specific to this package.
- **Keep secrets in memory only as long as needed** after unlocking.

We do **not** claim any guarantee the underlying platform APIs don't provide.

## Limitations

- **No backend logic.** The package gates access to your stored secret; wiring it
  to your auth flow is up to you.
- **One secret per config.** Each `BiometricLogin` manages one secret keyed by
  `BiometricConfig.secretKey`. Use different keys for multiple secrets.
- **`biometricOnly` is best-effort per platform.** Enforced on Android/iOS; on
  Windows, Windows Hello may permit a PIN.
- **Default prompt strings are English.** Pass localized `signInReason` /
  `enableReason` (or per-call `reason`).
- **Enrollment changes.** Adding/removing biometrics is an OS-level event; the
  gate uses whatever is currently enrolled. If a platform invalidates the stored
  secret, `unlock()` surfaces `storageError` and you can re-enable.

## Platform support

| Platform | Biometrics | Secure storage | Notes |
|---|:---:|:---:|---|
| Android | ✅ BiometricPrompt | ✅ Keystore | Needs `FragmentActivity` + permission |
| iOS | ✅ Face/Touch ID | ✅ Keychain | Needs `NSFaceIDUsageDescription` |
| macOS | ✅ Touch ID | ✅ Keychain | Needs Keychain Sharing entitlement; signed app |
| Windows | ✅ Windows Hello | ✅ DPAPI | `biometricOnly` not enforceable |
| Web / Linux | ❌ | — | Not supported |

Automated tests here are **unit/widget tests with mocked platform channels**.
Real biometric prompts, Keystore/Keychain/DPAPI behavior, and enrollment-change
handling must be verified **manually on physical devices/emulators** — no CI can
present a real fingerprint. See [`test/`](test/) for what is covered automatically.

## FAQ

**Is this a replacement for backend authentication?**
No. It's a local device gate over a secret you already obtained from your backend.

**Should I store the user's password?**
Prefer a refresh/session token you can revoke server-side. If you must store
credentials, treat them as highly sensitive.

**What happens if the user removes their fingerprint / adds a new one?**
The gate uses whatever is currently enrolled. If the platform invalidates the
stored secret, `unlock()` returns `storageError`; re-run `saveSecret` to re-enable.

**What happens when biometrics are unavailable?**
`unlock()` returns `unavailable` (no hardware / not set up) or `notEnrolled`
(hardware but nothing enrolled). Use `status.shouldFallBack` /
`status.requiresDeviceSetup` to branch.

**Does it work offline?**
Yes — the biometric check and secure storage are entirely on-device. What you do
with the unlocked secret (e.g. calling your API) may need connectivity.

**Does it work on Windows / macOS?**
Yes, with the setup above. Note `biometricOnly` isn't enforceable on Windows.

## Example

See [`example/`](example/) for a runnable app demonstrating availability checks,
enabling a secret, unlocking, result-state handling, and logout.

## License

MIT — see [LICENSE](LICENSE).
