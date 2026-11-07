import 'package:flutter/material.dart';
import '../feature_module.dart';

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
  Widget buildScreen(BuildContext context) => const LocationScreen();
}

class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data; real points come from POST /api/location on the child device.
    const history = [
      ('Now', 'Home', '31.5204, 74.3587'),
      ('1h ago', 'School', '31.5100, 74.3450'),
      ('3h ago', 'Park', '31.5300, 74.3700'),
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
