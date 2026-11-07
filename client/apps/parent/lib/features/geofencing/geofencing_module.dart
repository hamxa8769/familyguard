import 'package:flutter/material.dart';
import '../../feature_module.dart';

class GeofencingModule implements FeatureModule {
  @override
  String get id => 'geofencing';
  @override
  String get title => 'Safe Zones';
  @override
  String get description => 'Alerts when entering/leaving a zone';
  @override
  IconData get icon => Icons.my_location;
  @override
  Widget buildScreen(BuildContext context) => const GeofencingScreen();
}

class GeofencingScreen extends StatelessWidget {
  const GeofencingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const zones = [
      ('Home', '150 m', 'Inside'),
      ('School', '200 m', 'Left 2h ago'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Safe Zones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: POST /api/geofencing { deviceId, name, lat, lng, radiusM }
        },
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Add zone'),
      ),
      body: ListView(
        children: [
          for (final (name, radius, status) in zones)
            ListTile(
              leading: const Icon(Icons.radio_button_checked),
              title: Text(name),
              subtitle: Text('Radius: $radius'),
              trailing: Text(status),
            ),
        ],
      ),
    );
  }
}
