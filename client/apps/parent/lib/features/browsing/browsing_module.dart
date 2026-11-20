import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../feature_module.dart';

/// Parent side of browsing history: browser-app sessions only.
/// The screen states the limit plainly — visited URLs are not collected,
/// because Android does not expose them to third-party apps.
class BrowsingModule implements FeatureModule {
  @override
  String get id => 'browsing';
  @override
  String get title => 'Browsing History';
  @override
  String get description => 'Browser sessions — which browser, when, how long (no URLs)';
  @override
  IconData get icon => Icons.language;
  @override
  FeatureSection get section => FeatureSection.activity;
  @override
  Widget buildScreen(BuildContext context) => const BrowsingScreen();
}

class BrowsingScreen extends StatefulWidget {
  const BrowsingScreen({super.key});

  @override
  State<BrowsingScreen> createState() => _BrowsingScreenState();
}

class _BrowsingScreenState extends State<BrowsingScreen> {
  final _api = ApiClient();
  final _deviceId = TextEditingController();
  List<BrowsingSession> _sessions = [];
  String? _status;

  Future<void> _load() async {
    if (_deviceId.text.isEmpty) {
      setState(() => _status = 'Enter a device ID first.');
      return;
    }
    try {
      final data = await _api.get('/api/browsing/${_deviceId.text}');
      setState(() {
        _sessions = (data['sessions'] as List? ?? [])
            .map((s) => BrowsingSession.fromMap(s as Map))
            .toList();
        _status = null;
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Could not load sessions: ${e.message}');
    }
  }

  String _time(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _deviceId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browsing History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _deviceId,
            decoration: const InputDecoration(labelText: 'Device ID'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('Load sessions')),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!),
          ],
          const SizedBox(height: 8),
          const Text(
            'Browser sessions only: which browser was open, when, and for '
            'how long. The pages and URLs visited are NOT collected.',
          ),
          for (final s in _sessions)
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(s.browserLabel),
              subtitle: Text(
                '${_time(s.startedAt)} – ${_time(s.endedAt)} • '
                '${s.durationSeconds ~/ 60} min ${s.durationSeconds % 60} s',
              ),
            ),
          if (_sessions.isEmpty)
            const ListTile(title: Text('No browser sessions yet.')),
        ],
      ),
    );
  }
}
