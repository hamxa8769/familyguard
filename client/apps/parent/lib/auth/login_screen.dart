import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Parent sign-in / account creation.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService.instance;
  late final _server = TextEditingController(text: _auth.api.baseUrl);
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_server, _name, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password');
      return;
    }
    if (_register && password.length < 8) {
      setState(() => _error = 'Use a password of at least 8 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.setBaseUrl(_server.text);
      if (_register) {
        await _auth.register(
          email: email,
          password: password,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
      } else {
        await _auth.login(email: email, password: password);
      }
      widget.onSignedIn();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_register ? 'Create parent account' : 'Parent sign in')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.shield_outlined, size: 64),
          const SizedBox(height: 16),
          if (_register)
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
          if (_register) const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _submit(),
          ),
          ExpansionTile(
            title: const Text('Server'),
            tilePadding: EdgeInsets.zero,
            children: [
              TextField(
                controller: _server,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Server URL',
                  helperText: 'e.g. http://192.168.1.10:4000',
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_register ? 'Create account' : 'Sign in'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _register = !_register;
                      _error = null;
                    }),
            child: Text(_register
                ? 'I already have an account'
                : 'New here? Create an account'),
          ),
        ],
      ),
    );
  }
}
