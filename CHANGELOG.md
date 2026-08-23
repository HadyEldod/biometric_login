## 1.0.0

Initial release.

- `BiometricLogin` facade: `isAvailable`, `hasHardware`, `getBiometricKind`,
  `isEnabled`, `saveSecret`, `unlock`, `deleteSecret`.
- Backend-agnostic **opaque secret** model — the package never interprets the
  stored value.
- `BiometricLoginButton` widget with auto icon/label detection, loading state,
  theme-aware styling (`BiometricButtonStyle`), and gate/manual modes.
- `BiometricConfig` for keys, prompt reasons, and Keystore/Keychain options.
- Pluggable `BiometricSecretStorage` (default `SecureBiometricStorage` backed by
  `flutter_secure_storage`).
- Unit and widget tests; runnable `example/` app.
