import 'package:flutter/material.dart';
import '../../feature_module.dart';

class LocationModule implements FeatureModule {
  @override
  String get id => 'location';
  @override
  String get title => 'Location';
  @override
  String get description => 'Current location and recent history';
  @override
  IconData get icon => Icons.location_on;
  @override
  Widget buildScreen(BuildContext context) => const LocationViewScreen();
}

class LocationViewScreen extends StatelessWidget {
  const LocationViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data; real points from GET /api/location/:deviceId (synced from child).
    const history = [
      ('Now', 'Home', '31.52040, 74.35870'),
      ('1h ago', 'School', '31.51000, 74.34500'),
      ('3h ago', 'Park', '31.53000, 74.37000'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: Column(
        children: [
          Container(
            height: 180,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('Map placeholder\n(integrate google_maps_flutter)',
                  textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final (time, place, coords) in history)
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(place),
                    subtitle: Text(coords),
                    trailing: Text(time),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
