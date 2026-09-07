import 'dart:async';

import 'package:biometric_auth_login/biometric_auth_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

/// In-memory storage so gate-mode button tests need no real device.
class _MemoryStorage implements BiometricSecretStorage {
  final Map<String, String> _data = {};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

class _FakeService extends BiometricService {
  _FakeService(this.authResult);
  BiometricStatus authResult;
  int authCalls = 0;
  Completer<void>? gate;
  @override
  Future<bool> hasHardware() async => true;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<BiometricKind> getBiometricKind() async => BiometricKind.fingerprint;
  @override
  Future<BiometricStatus> authenticate({
    required String reason,
    bool biometricOnly = true,
    bool stickyAuth = true,
    bool useErrorDialogs = true,
  }) async {
    authCalls++;
    if (gate != null) await gate!.future;
    return authResult;
  }
}

Future<BiometricLogin> _enabledLogin(BiometricStatus unlockResult) async {
  final service = _FakeService(BiometricStatus.success);
  final login = BiometricLogin(service: service, storage: _MemoryStorage());
  await login.saveSecret('secret-token');
  service.authResult = unlockResult; // control the unlock outcome
  return login;
}

void main() {
  testWidgets('renders the given label', (tester) async {
    await tester.pumpWidget(_wrap(
      const BiometricLoginButton(label: 'Use fingerprint'),
    ));
    expect(find.text('Use fingerprint'), findsOneWidget);
  });

  testWidgets('shows a default label for the given kind', (tester) async {
    await tester.pumpWidget(_wrap(
      const BiometricLoginButton(kind: BiometricKind.face),
    ));
    expect(find.text('Sign in with Face ID'), findsOneWidget);
  });

  testWidgets('renders a custom icon when provided', (tester) async {
    await tester.pumpWidget(_wrap(
      const BiometricLoginButton(
        kind: BiometricKind.generic,
        icon: Icon(Icons.lock),
      ),
    ));
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets('invokes onPressed on tap (manual mode)', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      BiometricLoginButton(
        label: 'Go',
        onPressed: () async => tapped = true,
      ),
    ));

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('does not call onPressed when disabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_wrap(
      BiometricLoginButton(
        label: 'Go',
        enabled: false,
        onPressed: () async => tapped = true,
      ),
    ));

    await tester.tap(find.text('Go'));
    await tester.pump();

    expect(tapped, isFalse);
  });

  testWidgets('exposes button semantics', (tester) async {
    await tester.pumpWidget(_wrap(
      const BiometricLoginButton(label: 'Sign in', semanticLabel: 'Sign in'),
    ));

    final semantics = tester.getSemantics(find.byType(BiometricLoginButton));
    expect(semantics.label, contains('Sign in'));
  });

  testWidgets('gate mode calls onUnlocked with the secret on success',
      (tester) async {
    final login = await _enabledLogin(BiometricStatus.success);
    String? unlocked;
    await tester.pumpWidget(_wrap(
      BiometricLoginButton(
        label: 'Unlock',
        biometric: login,
        onUnlocked: (s) async => unlocked = s,
      ),
    ));

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(unlocked, 'secret-token');
  });

  testWidgets('gate mode reports the failure status via onError',
      (tester) async {
    final login = await _enabledLogin(BiometricStatus.lockedOut);
    BiometricStatus? error;
    await tester.pumpWidget(_wrap(
      BiometricLoginButton(
        label: 'Unlock',
        biometric: login,
        onUnlocked: (_) async {},
        onError: (s) => error = s,
      ),
    ));

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(error, BiometricStatus.lockedOut);
  });

  testWidgets('ignores repeated taps while an unlock is in progress',
      (tester) async {
    final service = _FakeService(BiometricStatus.success);
    final login = BiometricLogin(service: service, storage: _MemoryStorage());
    await login.saveSecret('secret-token');

    var unlockedCount = 0;
    await tester.pumpWidget(_wrap(
      BiometricLoginButton(
        label: 'Unlock',
        biometric: login,
        onUnlocked: (_) async => unlockedCount++,
      ),
    ));

    // Hold the prompt open, then tap twice before it resolves.
    service.gate = Completer<void>();
    await tester.tap(find.text('Unlock'));
    await tester.pump(); // enter busy state (label -> spinner)
    await tester.tap(find.byType(BiometricLoginButton), warnIfMissed: false);
    await tester.pump();

    service.gate!.complete();
    await tester.pumpAndSettle();

    // Second tap was swallowed while busy: exactly one prompt, one callback.
    expect(service.authCalls, 2); // 1 for saveSecret, 1 for the single unlock
    expect(unlockedCount, 1);
  });
}
