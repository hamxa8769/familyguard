import 'package:flutter/material.dart';
import '../../feature_module.dart';

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

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample alerts; real data from GET /api/sos and geofence events.
    const alerts = [
      (Icons.sos, 'SOS from Ali', '2 min ago', true),
      (Icons.my_location, 'Sara left School', '1h ago', false),
      (Icons.sos, 'SOS from Sara', 'Yesterday', false),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: ListView(
        children: [
          for (final (icon, title, time, urgent) in alerts)
            ListTile(
              leading: Icon(icon, color: urgent ? Colors.red : null),
              title: Text(title),
              subtitle: Text(time),
              trailing: urgent
                  ? const Chip(label: Text('New'))
                  : const Icon(Icons.check, color: Colors.green),
            ),
        ],
      ),
    );
  }
}
