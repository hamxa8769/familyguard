import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../network/api_client.dart';
import 'app_theme.dart';

/// Lets the user point the app at a different server address (e.g. a new
/// public tunnel URL) without signing in or pairing again: the saved token
/// stays valid because it is the same server behind a new address.
///
/// Returns true when the address was changed.
Future<bool> showServerDialog(BuildContext context) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => const _ServerDialog(),
  );
  return changed == true;
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  final _auth = AuthService.instance;
  late final _url = TextEditingController(text: _auth.api.baseUrl);
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _url.text.trim();
    if (!RegExp(r'^https?://\S+$').hasMatch(value)) {
      setState(() => _error = 'Enter a full address starting with http:// or https://');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    // Check the new address answers before switching to it.
    final probe = ApiClient(baseUrl: value);
    probe.setBaseUrl(value);
    try {
      final res = await probe.get('/health');
      if (res is! Map || res['service'] != 'familyguard-backend') {
        throw ApiException(0, 'That address is not a FamilyGuard server');
      }
      await _auth.setBaseUrl(value);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return AlertDialog(
      title: const Text('Server address'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _url,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'https://example.trycloudflare.com',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: FgSpace.sm),
          Text(
            'Use the address shown by "npm run public" on the server PC, or '
            'http://<PC address>:4000 on the same Wi-Fi.',
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
          if (_error != null) ...[
            const SizedBox(height: FgSpace.sm),
            Text(_error!, style: TextStyle(color: c.danger, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _checking ? null : _save,
          child: Text(_checking ? 'Checking…' : 'Save'),
        ),
      ],
    );
  }
}
