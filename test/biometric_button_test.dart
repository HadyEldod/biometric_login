import 'package:biometric_auth_login/biometric_auth_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

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
}
