import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

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

class RemoteCommandsScreen extends StatelessWidget {
  const RemoteCommandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Remote Commands',
      builder: (context, deviceId) => _RemoteCommandsBody(deviceId: deviceId),
    );
  }
}

class _RemoteCommandsBody extends StatefulWidget {
  const _RemoteCommandsBody({required this.deviceId});

  final String deviceId;

  @override
  State<_RemoteCommandsBody> createState() => _RemoteCommandsBodyState();
}

class _RemoteCommandsBodyState extends State<_RemoteCommandsBody> {
  ApiClient get _api => ParentState.instance.api;
  final _message = TextEditingController();
  String? _status;

  Future<List<RemoteCommand>> _load() async {
    final data = await _api.get('/api/remotecommands?deviceId=${widget.deviceId}');
    return (data['commands'] as List? ?? [])
        .map((c) => RemoteCommand.fromMap(c as Map))
        .toList();
  }

  Future<void> _create(
      String type, VoidCallback reload, [Map<String, dynamic> payload = const {}]) async {
    try {
      await _api.post('/api/remotecommands', {
        'deviceId': widget.deviceId,
        'type': type,
        'payload': payload,
      });
      if (!mounted) return;
      setState(() => _status = 'Command sent — the child app polls for it.');
      reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Could not send command: ${e.message}');
    }
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remote Commands')),
      // ApiView (Phase 5): loading spinner, error + retry, and
      // pull-to-refresh — previously silent load, inline error line only,
      // and no empty state at all (an empty list showed a blank screen).
      body: ApiView<List<RemoteCommand>>(
        load: _load,
        builder: (context, commands, reload) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                  onPressed: () => _create('lock_now', reload),
                  child: const Text('Lock now'),
                ),
                OutlinedButton(
                  onPressed: () => _create('unlock', reload),
                  child: const Text('Unlock'),
                ),
                OutlinedButton(
                  onPressed: () => _create('send_message', reload, {'text': _message.text}),
                  child: const Text('Send message'),
                ),
                OutlinedButton(
                  onPressed: () => _create('request_screenshot', reload),
                  child: const Text('Request screenshot'),
                ),
                OutlinedButton(
                  onPressed: () => _create('request_audio', reload, {'source': 'parent_request'}),
                  child: const Text('Request short audio (30s max)'),
                ),
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
            if (commands.isEmpty)
              const EmptyHint('No commands sent yet.'),
            for (final c in commands)
              ListTile(
                leading: Icon(c.isPending ? Icons.hourglass_top : Icons.check_circle_outline),
                title: Text('${c.type} — ${c.status}'),
                subtitle: Text(c.createdAt ?? ''),
              ),
          ],
        ),
      ),
    );
  }
}
