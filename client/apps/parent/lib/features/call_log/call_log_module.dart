import 'package:flutter/material.dart';
import '../../feature_module.dart';

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

  @override
  Widget build(BuildContext context) {
    // Sample data; real data from GET /api/comms/:deviceId (synced from child).
    const calls = [
      ('+92 300 1234567', 'Incoming', '14:05', '1m 35s', Icons.call_received),
      ('+92 301 7654321', 'Outgoing', '12:40', '—', Icons.call_made),
      ('+92 42 111222333', 'Missed', 'Yesterday', '—', Icons.call_missed),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Call Log')),
      body: ListView(
        children: [
          for (final (number, type, time, duration, icon) in calls)
            ListTile(
              leading: Icon(icon,
                  color: type == 'Missed' ? Colors.red : null),
              title: Text(number),
              subtitle: Text('$type • $time'),
              trailing: Text(duration),
            ),
        ],
      ),
    );
  }
}
