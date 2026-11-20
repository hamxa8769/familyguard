import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/share_file.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

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

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Screenshots & Audio',
      builder: (context, deviceId) => _MediaBody(deviceId: deviceId),
    );
  }
}

class _MediaBody extends StatefulWidget {
  const _MediaBody({required this.deviceId});

  final String deviceId;

  @override
  State<_MediaBody> createState() => _MediaBodyState();
}

class _MediaBodyState extends State<_MediaBody> {
  ApiClient get _api => ParentState.instance.api;
  String? _status;

  Future<List<MediaCapture>> _load() async {
    final data = await _api.get('/api/media?deviceId=${widget.deviceId}');
    return (data['captures'] as List? ?? [])
        .map((c) => MediaCapture.fromMap(c as Map))
        .toList();
  }

  Future<void> _delete(MediaCapture capture, VoidCallback reload) async {
    try {
      await _api.post('/api/media/${capture.id}/delete', {});
      reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Could not delete: ${e.message}');
    }
  }

  Future<void> _download(MediaCapture capture) async {
    if (!mounted) return;
    setState(() => _status = 'Downloading…');
    try {
      final bytes = await _api.getBytes('/api/media/${capture.id}/file');
      if (!mounted) return;
      final name = (capture.storageRef?.split('/').last ?? '').isNotEmpty
          ? capture.storageRef!.split('/').last
          : '${capture.kind}-${capture.id}';
      final ok = await saveAndShareBytes(
        context,
        bytes,
        name,
        mimeType: capture.isScreenshot ? 'image/png' : 'audio/mp4',
      );
      if (mounted) setState(() => _status = ok ? 'Shared — pick where to save it.' : null);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Could not download: ${e.message}');
    }
  }

  Future<void> _requestScreenshot(VoidCallback reload) async {
    try {
      await _api.post('/api/media/screenshot-request', {
        'deviceId': widget.deviceId,
      });
      if (!mounted) return;
      setState(() => _status = 'Screenshot requested — the child sees a countdown first.');
      reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Could not request: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Screenshots & Audio')),
      // ApiView (Phase 5): loading spinner, error + retry, and
      // pull-to-refresh — previously silent load, inline error line only.
      body: ApiView<List<MediaCapture>>(
        load: _load,
        builder: (context, captures, reload) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => _requestScreenshot(reload),
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
            if (captures.isEmpty)
              const EmptyHint('No captures yet'),
            for (final capture in captures)
              ListTile(
                leading: Icon(capture.isScreenshot ? Icons.image : Icons.mic),
                title: Text('${capture.kind} — ${capture.status}'),
                subtitle: Text(
                  'Source: ${capture.source}'
                  '${capture.durationSeconds != null ? ' • ${capture.durationSeconds}s' : ''}'
                  '${capture.expiresAt != null ? '\nExpires: ${capture.expiresAt}' : ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Download is only possible once the file is on the server.
                    IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: 'Download',
                      onPressed: capture.status == 'captured' &&
                              capture.storageRef != null
                          ? () => _download(capture)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete now',
                      onPressed: () => _delete(capture, reload),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
