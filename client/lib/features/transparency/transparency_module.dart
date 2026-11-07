import 'package:flutter/material.dart';
import '../feature_module.dart';

/// Unique feature: the child opens this to see EXACTLY what the parent sees.
/// Mirrors GET /api/transparency/:deviceId.
class TransparencyModule implements FeatureModule {
  @override
  String get id => 'transparency';
  @override
  String get title => 'What My Parent Sees';
  @override
  String get description => 'Full transparency for the child';
  @override
  IconData get icon => Icons.visibility;
  @override
  Widget buildScreen(BuildContext context) => const TransparencyScreen();
}

class TransparencyScreen extends StatelessWidget {
  const TransparencyScreen({super.key});

  static const _collected = [
    'Which apps are used and for how long',
    'This device\'s location and location history',
    'Screen-time usage against the daily limit',
    'Geofence enter/exit events',
    'SOS alerts you trigger',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('What My Parent Sees')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This is exactly what your parent or guardian can see about this '
                'device. Nothing is hidden from you.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Information collected',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in _collected)
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: Text(item),
              dense: true,
            ),
          const SizedBox(height: 8),
          Text('Not collected',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.not_interested),
            title: Text('Message or photo content'),
            dense: true,
          ),
        ],
      ),
    );
  }
}
