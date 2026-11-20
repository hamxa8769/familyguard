import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

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

class BrowsingScreen extends StatelessWidget {
  const BrowsingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Browsing History',
      builder: (context, deviceId) => _BrowsingBody(deviceId: deviceId),
    );
  }
}

class _BrowsingBody extends StatelessWidget {
  const _BrowsingBody({required this.deviceId});

  final String deviceId;

  String _time(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browsing History')),
      // ApiView (Phase 5): loading spinner, error + retry, and
      // pull-to-refresh — previously silent load, inline error line only.
      body: ApiView<List<BrowsingSession>>(
        load: () async {
          final data = await ParentState.instance.api.get('/api/browsing/$deviceId');
          return (data['sessions'] as List? ?? [])
              .map((s) => BrowsingSession.fromMap(s as Map))
              .toList();
        },
        builder: (context, sessions, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Browser sessions only: which browser was open, when, and for '
              'how long. The pages and URLs visited are NOT collected.',
            ),
            const SizedBox(height: 8),
            for (final s in sessions)
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(s.browserLabel),
                subtitle: Text(
                  '${_time(s.startedAt)} – ${_time(s.endedAt)} • '
                  '${s.durationSeconds ~/ 60} min ${s.durationSeconds % 60} s',
                ),
              ),
            if (sessions.isEmpty)
              const EmptyHint('No browser sessions yet.'),
          ],
        ),
      ),
    );
  }
}
