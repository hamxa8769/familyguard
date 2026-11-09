import 'package:flutter/material.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../messages/messages_module.dart';

class CallLogModule implements FeatureModule {
  @override
  String get id => 'call_log';
  @override
  String get title => 'Call Log';
  @override
  String get description => 'View the child\'s call history';
  @override
  IconData get icon => Icons.call;
  @override
  Widget buildScreen(BuildContext context) => const CallLogViewScreen();
}

class CallLogViewScreen extends StatelessWidget {
  const CallLogViewScreen({super.key});

  IconData _icon(int type) => switch (type) {
        2 => Icons.call_made,
        3 => Icons.call_missed,
        _ => Icons.call_received,
      };

  String _duration(int seconds) {
    if (seconds <= 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Call Log',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Call Log')),
        body: ApiView<CommsData>(
          load: () => CommsData.load(deviceId),
          builder: (context, data, _) => data.calls.isEmpty
              ? const EmptyHint('No call history shared yet (Android only, '
                  'after the child allows call-log access).')
              : ListView(
                  children: [
                    for (final c in data.calls)
                      ListTile(
                        leading: Icon(_icon(c.type),
                            color: c.type == 3 ? Colors.red : null),
                        title: Text(c.number),
                        subtitle: Text('${c.typeLabel} • ${timeAgo(c.date)}'),
                        trailing: Text(_duration(c.durationSeconds)),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
