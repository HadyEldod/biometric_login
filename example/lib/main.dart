import 'dart:convert';

import 'package:biometric_auth_login/biometric_auth_login.dart';
import 'package:flutter/material.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'biometric_login demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // The package instance. The secret is opaque; this demo stores fake JSON
  // "credentials", but it could be a token or anything else.
  final BiometricLogin _biometric = BiometricLogin(
    config: const BiometricConfig(
      secretKey: 'demo.secret',
      signInReason: 'Authenticate to sign in to the demo',
      enableReason: 'Authenticate to enable biometric login',
    ),
  );

  final _userCtrl = TextEditingController(text: 'demo@user.com');
  final _passCtrl = TextEditingController(text: 'hunter2');

  bool _available = false;
  bool _enabled = false;
  BiometricKind _kind = BiometricKind.generic;
  String _log = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // 1. Check availability + current enrollment state.
  Future<void> _refresh() async {
    final available = await _biometric.isAvailable();
    final enabled = await _biometric.isEnabled();
    final kind = await _biometric.getBiometricKind();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
      _kind = kind;
    });
  }

  void _print(String message) {
    setState(() => _log = message);
  }

  // 2. Save a secret behind the biometric gate.
  Future<void> _enable() async {
    final secret = jsonEncode({
      'username': _userCtrl.text.trim(),
      'password': _passCtrl.text,
    });
    final ok = await _biometric.saveSecret(secret);
    await _refresh();
    _print(ok
        ? 'Secret saved behind biometrics.'
        : 'Could not save (cancelled or unavailable).');
  }

  // 3 + 4 + 5. Unlock and read the secret (also wired to the button below).
  Future<void> _onUnlocked(String secret) async {
    final data = jsonDecode(secret) as Map<String, dynamic>;
    // In a real app you would call your backend here with these values.
    _print('Unlocked. Logged in as: ${data['username']}');
  }

  void _onError(BiometricStatus status) {
    _print('Biometric failed: ${status.name}');
  }

  // 6. Delete / disable.
  Future<void> _disable() async {
    await _biometric.deleteSecret();
    await _refresh();
    _print('Secret deleted, biometric login disabled.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('biometric_login demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusCard(
              available: _available,
              enabled: _enabled,
              kind: _kind,
            ),
            const SizedBox(height: 16),

            // Demo "credentials" that become the opaque secret.
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _available && !_enabled ? _enable : null,
              icon: const Icon(Icons.lock),
              label: const Text('Enable biometric login (save secret)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _enabled ? _disable : null,
              icon: const Icon(Icons.lock_open),
              label: const Text('Disable (delete secret)'),
            ),
            const SizedBox(height: 24),

            // The ready-made button — only meaningful once a secret is saved.
            if (_enabled)
              BiometricLoginButton(
                biometric: _biometric,
                onUnlocked: _onUnlocked,
                onError: _onError,
              ),

            const SizedBox(height: 24),
            Text(_log, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refresh,
        tooltip: 'Refresh state',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.available,
    required this.enabled,
    required this.kind,
  });

  final bool available;
  final bool enabled;
  final BiometricKind kind;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Biometrics available', available ? 'yes' : 'no'),
            _row('Detected kind', kind.name),
            _row('Biometric login enabled', enabled ? 'yes' : 'no'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text(value)],
        ),
      );
}
