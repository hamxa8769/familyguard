import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

class DashboardModule implements FeatureModule {
  @override
  String get id => 'dashboard';
  @override
  String get title => 'Dashboard';
  @override
  String get description => 'Daily summary for your child';
  @override
  IconData get icon => Icons.dashboard;
  @override
  Widget buildScreen(BuildContext context) => const DashboardScreen();
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Dashboard',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(
            title: Text(ParentState.instance.labelFor(deviceId))),
        body: ApiView<Map>(
          load: () async =>
              await ParentState.instance.api.get('/api/reports/$deviceId')
                  as Map,
          builder: (context, report, _) => _Report(report: report),
        ),
      ),
    );
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report});
  final Map report;

  @override
  Widget build(BuildContext context) {
    final apps = (report['usage']?['apps'] as List? ?? const [])
        .map((e) => UsageEntry.fromMap(e as Map))
        .toList();
    final screen = report['screenTime'] as Map? ?? const {};
    final consumed = (screen['consumedMinutes'] as num?)?.toInt() ?? 0;
    final limit = (screen['dailyMinutes'] as num?)?.toInt();
    final sos = (report['activeSosAlerts'] as List? ?? const []).length;
    final loc = LocationPoint.fromServer(report['lastLocation'] as Map?);
    final maxSec = apps.isEmpty
        ? 1
        : apps.map((e) => e.durationSeconds).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _StatCard(
              label: limit == null
                  ? 'Screen time'
                  : 'of ${formatMinutes(limit)} limit',
              value: formatMinutes(consumed),
            ),
            const SizedBox(width: 12),
            _StatCard(
              label: 'Open SOS',
              value: '$sos',
              alert: sos > 0,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.location_on),
          title: Text(loc == null
              ? 'No location shared yet'
              : '${loc.lat.toStringAsFixed(5)}, ${loc.lng.toStringAsFixed(5)}'),
          subtitle: loc == null ? null : Text('Updated ${timeAgo(loc.time)}'),
        ),
        const SizedBox(height: 12),
        Text('App usage today', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (apps.isEmpty)
          const Text('No usage reported yet. The child app sends it when open '
              'and Usage Access is allowed.'),
        for (final app in apps.take(15))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(app.appName,
                            overflow: TextOverflow.ellipsis)),
                    Text(formatMinutes(app.minutes)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: app.durationSeconds / maxSec),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.alert = false});
  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: alert ? Theme.of(context).colorScheme.errorContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
