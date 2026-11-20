import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../feature_module.dart';

/// Parent side of remote commands: create lock/unlock/message commands and
/// request a screenshot or a short SOS audio clip.
///
/// The child polls for commands (push is a notification only). A screenshot
/// is only taken after a notification + countdown on the child device, and
/// audio is capped at 30 seconds with a visible indicator — both are
/// disclosed in the child's consent notice. There is no silent or
/// continuous capture anywhere in this flow.
class RemoteCommandsModule implements FeatureModule {
  @override
  String get id => 'remote_commands';
  @override
  String get title => 'Remote Commands';
  @override
  String get description => 'Lock now, send a message, request a screenshot or short audio';
  @override
  IconData get icon => Icons.send_to_mobile;
  @override
  FeatureSection get section => FeatureSection.rules;
  @override
  Widget buildScreen(BuildContext context) => const RemoteCommandsScreen();
}

class RemoteCommandsScreen extends StatefulWidget {
  const RemoteCommandsScreen({super.key});

  @override
  State<RemoteCommandsScreen> createState() => _RemoteCommandsScreenState();
}

class _RemoteCommandsScreenState extends State<RemoteCommandsScreen> {
  final _api = ApiClient();
  final _deviceId = TextEditingController();
  final _message = TextEditingController();
  List<RemoteCommand> _commands = [];
  String? _status;

  Future<void> _load() async {
    if (_deviceId.text.isEmpty) return;
    try {
      final data = await _api.get('/api/remotecommands?deviceId=${_deviceId.text}');
      setState(() {
        _commands = (data['commands'] as List? ?? [])
            .map((c) => RemoteCommand.fromMap(c as Map))
            .toList();
        _status = null;
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Could not load commands: ${e.message}');
    }
  }

  Future<void> _create(String type, [Map<String, dynamic> payload = const {}]) async {
    if (_deviceId.text.isEmpty) {
      setState(() => _status = 'Enter a device ID first.');
      return;
    }
    try {
      await _api.post('/api/remotecommands', {
        'deviceId': _deviceId.text,
        'type': type,
        'payload': payload,
      });
      setState(() => _status = 'Command sent — the child app polls for it.');
      await _load();
    } on ApiException catch (e) {
      setState(() => _status = 'Could not send command: ${e.message}');
    }
  }

  @override
  void dispose() {
    _deviceId.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remote Commands')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _deviceId,
            decoration: const InputDecoration(labelText: 'Child device ID'),
          ),
          TextField(
            controller: _message,
            decoration: const InputDecoration(labelText: 'Message text (for Send message)'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => _create('lock_now'),
                child: const Text('Lock now'),
              ),
              OutlinedButton(
                onPressed: () => _create('unlock'),
                child: const Text('Unlock'),
              ),
              OutlinedButton(
                onPressed: () => _create('send_message', {'text': _message.text}),
                child: const Text('Send message'),
              ),
              OutlinedButton(
                onPressed: () => _create('request_screenshot'),
                child: const Text('Request screenshot'),
              ),
              OutlinedButton(
                onPressed: () => _create('request_audio', {'source': 'parent_request'}),
                child: const Text('Request short audio (30s max)'),
              ),
              OutlinedButton(onPressed: _load, child: const Text('Refresh')),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Screenshots need a notification + countdown on the child device, '
            'and audio is SOS-only / max 30 seconds with a visible indicator. '
            'Nothing here captures silently.',
          ),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!),
          ],
          const SizedBox(height: 8),
          for (final c in _commands)
            ListTile(
              leading: Icon(c.isPending ? Icons.hourglass_top : Icons.check_circle_outline),
              title: Text('${c.type} — ${c.status}'),
              subtitle: Text(c.createdAt ?? ''),
            ),
        ],
      ),
    );
  }
}
