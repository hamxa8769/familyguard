import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

class AlertsModule implements FeatureModule {
  @override
  String get id => 'alerts';
  @override
  String get title => 'Alerts';
  @override
  String get description => 'SOS and safe-zone alerts';
  @override
  IconData get icon => Icons.notifications_active;
  @override
  Widget buildScreen(BuildContext context) => const AlertsScreen();
}

class _Alert {
  _Alert({
    required this.at,
    required this.title,
    required this.icon,
    this.sos,
  });
  final DateTime at;
  final String title;
  final IconData icon;
  final SosAlert? sos;
}

/// SOS alerts from all children + safe-zone events from every device.
/// (Pull to refresh — push notifications are not wired up yet.)
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  Future<List<_Alert>> _load() async {
    final state = ParentState.instance;
    final api = state.api;
    final out = <_Alert>[];

    final sos = await api.get('/api/sos');
    for (final a in (sos['alerts'] as List).map((e) => SosAlert.fromMap(e as Map))) {
      out.add(_Alert(
        at: DateTime.tryParse(a.at) ?? DateTime(2000),
        title: '${a.message} — ${state.labelFor(a.deviceId)}',
        icon: Icons.sos,
        sos: a,
      ));
    }
    for (final (child, device) in state.devices) {
      final ev = await api.get('/api/geofencing/${device.id}/events');
      for (final e in ev['events'] as List) {
        final verb = e['type'] == 'enter' ? 'arrived at' : 'left';
        out.add(_Alert(
          at: DateTime.tryParse('${e['at']}') ?? DateTime(2000),
          title: '${child.displayName} $verb ${e['zoneName']}',
          icon: Icons.my_location,
        ));
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: ApiView<List<_Alert>>(
        load: _load,
        builder: (context, alerts, reload) {
          if (alerts.isEmpty) return const EmptyHint('No alerts.');
          return ListView(
            children: [
              for (final a in alerts)
                ListTile(
                  leading: Icon(a.icon,
                      color: a.sos != null && !a.sos!.resolved
                          ? Colors.red
                          : null),
                  title: Text(a.title),
                  subtitle: Text(timeAgo(a.at.toLocal())),
                  trailing: a.sos == null
                      ? null
                      : a.sos!.resolved
                          ? const Icon(Icons.check, color: Colors.green)
                          : TextButton(
                              onPressed: () async {
                                final ok = await saveWithFeedback(
                                  context,
                                  () => ParentState.instance.api.post(
                                      '/api/sos/${a.sos!.id}/resolve', {}),
                                  'Marked as handled',
                                );
                                if (ok) reload();
                              },
                              child: const Text('Resolve'),
                            ),
                ),
            ],
          );
        },
      ),
    );
  }
}
