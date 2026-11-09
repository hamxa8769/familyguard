import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Links this device to a child profile using the one-time code shown in the
/// parent app (My Children → child → pairing code).
class PairScreen extends StatefulWidget {
  const PairScreen({super.key, required this.onPaired});

  final VoidCallback onPaired;

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _auth = AuthService.instance;
  late final _server = TextEditingController(text: _auth.api.baseUrl);
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'windows';
  }

  Future<void> _pair() async {
    if (_code.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-character code from the parent app');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.setBaseUrl(_server.text);
      await _auth.pairDevice(
        code: _code.text,
        platform: _platform,
        deviceName: Platform.localHostname,
      );
      widget.onPaired();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to your parent')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.link, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Ask your parent to open FamilyGuard (Parent) → My Children and '
            'read you the pairing code for your profile.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, letterSpacing: 6),
            decoration: const InputDecoration(labelText: 'Pairing code'),
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
            onPressed: _busy ? null : _pair,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
