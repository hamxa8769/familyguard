import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../feature_module.dart';

/// Parent viewer for screenshots and SOS-audio captures.
///
/// Shows only metadata in Phase 1 (the file bytes are uploaded by the
/// Phase 2 native capture). Every capture lists its source, status and
/// expiry — captures auto-expire after 7 days — and the same list is
/// visible to the child in "What My Parent Sees".
class MediaModule implements FeatureModule {
  @override
  String get id => 'media';
  @override
  String get title => 'Screenshots & Audio';
  @override
  String get description => 'On-request screenshots and SOS-only short audio clips';
  @override
  IconData get icon => Icons.photo_library;
  @override
  FeatureSection get section => FeatureSection.activity;
  @override
  Widget buildScreen(BuildContext context) => const MediaScreen();
}

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  final _api = ApiClient();
  final _deviceId = TextEditingController();
  List<MediaCapture> _captures = [];
  String? _status;

  Future<void> _load() async {
    if (_deviceId.text.isEmpty) return;
    try {
      final data = await _api.get('/api/media?deviceId=${_deviceId.text}');
      setState(() {
        _captures = (data['captures'] as List? ?? [])
            .map((c) => MediaCapture.fromMap(c as Map))
            .toList();
        _status = null;
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Could not load captures: ${e.message}');
    }
  }

  Future<void> _delete(MediaCapture capture) async {
    try {
      await _api.post('/api/media/${capture.id}/delete', {});
      await _load();
    } on ApiException catch (e) {
      setState(() => _status = 'Could not delete: ${e.message}');
    }
  }

  @override
  void dispose() {
    _deviceId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Screenshots & Audio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _deviceId,
            decoration: const InputDecoration(labelText: 'Child device ID'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(onPressed: _load, child: const Text('Load captures')),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  if (_deviceId.text.isEmpty) return;
                  try {
                    await _api.post('/api/media/screenshot-request', {
                      'deviceId': _deviceId.text,
                    });
                    setState(() => _status = 'Screenshot requested — the child sees a countdown first.');
                    await _load();
                  } on ApiException catch (e) {
                    setState(() => _status = 'Could not request: ${e.message}');
                  }
                },
                child: const Text('Request screenshot'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Captures auto-expire after 7 days. The child can see this same '
            'list, including when each capture was requested.',
          ),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!),
          ],
          const SizedBox(height: 8),
          if (_captures.isEmpty)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No captures yet'),
            ),
          for (final capture in _captures)
            ListTile(
              leading: Icon(capture.isScreenshot ? Icons.image : Icons.mic),
              title: Text('${capture.kind} — ${capture.status}'),
              subtitle: Text(
                'Source: ${capture.source}'
                '${capture.durationSeconds != null ? ' • ${capture.durationSeconds}s' : ''}'
                '${capture.expiresAt != null ? '\nExpires: ${capture.expiresAt}' : ''}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete now',
                onPressed: () => _delete(capture),
              ),
            ),
        ],
      ),
    );
  }
}
