## 1.1.0

Dependency modernization, concurrency safety, and a richer result API. No
breaking changes to existing method signatures.

### Changed
- Migrated to **`local_auth` 3.x** and support **`flutter_secure_storage` 11.x**
  (constraints: `local_auth: '>=3.0.0 <4.0.0'`,
  `flutter_secure_storage: '>=9.0.0 <12.0.0'`). `local_auth` 3.x error handling
  (`LocalAuthException`) replaces the removed `error_codes.dart`.
  > Note: the minimum `local_auth` is now 3.0.0. Apps pinned to `local_auth` 2.x
  > must upgrade.
- `isEnabled()` now checks only the lightweight "enabled" flag and no longer
  reads/decrypts the secret. This makes it cheaper and lets `unlock()` report a
  secret decrypt/read failure as `storageError` (previously misreported as
  `notEnabled`).
- `AndroidOptions` default no longer sets the removed `encryptedSharedPreferences`
  flag; Keystore-backed cipher storage is used and legacy data is auto-migrated.

### Added
- **Overlapping-prompt protection:** `saveSecret`/`unlock` on the same instance
  no longer show two system prompts at once. A rejected `unlock` returns the new
  `BiometricStatus.busy`; a rejected `saveSecret` returns `false`.
- `BiometricStatus.busy` enum value.
- `BiometricStatusX` extension: `isSuccess`, `canRetry`, `requiresDeviceSetup`,
  `requiresEnrollmentInApp`, `shouldFallBack`.
- `BiometricLogin.canAuthenticate()` and `getAvailableBiometrics()`.
- `BiometricService.getAvailableBiometrics()`.
- pub metadata: `topics` and explicit `platforms` (android, ios, macos, windows).

### Docs & tests
- README rewritten: accurate platform matrix, comparison table, FAQ, use cases,
  security section, and result-handling guide.
- Added tests for concurrency, storage failures, lifecycle transitions, the
  status extension, capability methods, and gate-mode button callbacks.

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
