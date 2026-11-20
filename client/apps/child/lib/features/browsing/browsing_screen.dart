import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../services/native_collectors.dart';

/// Child side of browsing history: browser-app sessions only.
/// The screen states the limit plainly — Android does not expose visited
/// URLs to third-party apps, so the parent sees which browser was open,
/// when, and for how long, never the pages visited.
class BrowsingScreen extends StatefulWidget {
  const BrowsingScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<BrowsingScreen> createState() => _BrowsingScreenState();
}

class _BrowsingScreenState extends State<BrowsingScreen> {
  ApiClient get _api => AuthService.instance.api;
  List<BrowsingSession> _sessions = [];
  String? _status;
  bool _loading = false;

  Future<void> _load() async {
    if (widget.deviceId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/browsing/${widget.deviceId}');
      setState(() {
        _sessions = (data['sessions'] as List? ?? [])
            .map((s) => BrowsingSession.fromMap(s as Map))
            .toList();
        _status = null;
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Could not load sessions: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _loading = true);
    try {
      final local = await NativeCollectors.getBrowserSessions();
      await _api.post('/api/browsing/${widget.deviceId}/sync', {
        'sessions': local
            .map((s) => {
                  'packageName': s.packageName,
                  'browserLabel': s.browserLabel,
                  'startedAt': s.startedAt,
                  'endedAt': s.endedAt,
                  'durationSeconds': s.durationSeconds,
                })
            .toList(),
      });
      await _load();
      setState(() => _status = 'Synced ${local.length} browser sessions.');
    } on ApiException catch (e) {
      setState(() => _status = 'Sync failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _time(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browsing History')),
      body: widget.deviceId.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('This device is not registered yet.'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Your parent can see which browser app was open, when, '
                    'and for how long. The actual pages and URLs you visit '
                    'are NOT collected — Android does not allow apps to read '
                    'them.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loading ? null : _sync,
                    child: const Text('Sync browsing sessions now'),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 8),
                    Text(_status!),
                  ],
                  if (_loading) const LinearProgressIndicator(),
                  for (final s in _sessions)
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(s.browserLabel),
                      subtitle: Text(
                        '${_time(s.startedAt)} – ${_time(s.endedAt)} • '
                        '${s.durationSeconds ~/ 60} min ${s.durationSeconds % 60} s',
                      ),
                    ),
                  if (_sessions.isEmpty && !_loading)
                    const ListTile(title: Text('No browser sessions yet.')),
                ],
              ),
            ),
    );
  }
}
