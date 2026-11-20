import 'package:flutter/material.dart';

/// Unique feature: the child sees EXACTLY what the parent sees.
/// Mirrors GET /api/transparency/:deviceId.
class TransparencyScreen extends StatelessWidget {
  const TransparencyScreen({super.key});

  static const _collected = [
    'Which apps are used and for how long',
    'This device\'s location and location history',
    'Screen-time usage against the daily limit',
    'Geofence enter/exit events',
    'SOS alerts you trigger',
    'Your SMS messages (sender, text, and time)',
    'Your contacts (names and numbers)',
    'Your call history (number, type, time, duration)',
    'Your photos and files (name, size, date)',
    'Remote commands from your parent (lock now, unlock, messages)',
    'Screenshots taken only after a notification and countdown on this device',
    'Short audio clips (max 30 seconds) only when you press SOS or after a visible request',
    'Which apps are installed on this device',
    'Browser sessions: which browser was open, when, and for how long (never the pages or URLs)',
    'Bedtime and app-blocking rules your parent set, and when they block an app',
    'The family agreement you signed (or declined)',
    'Reward points and badges you earned',
  ];

  static const _notCollected = [
    'Live camera capture',
    'Continuous or ambient microphone listening',
    'Secret screenshots (every screenshot is announced first)',
    'The web pages or URLs you visit',
    'The content of apps other than SMS, call log, contacts and gallery (as listed above)',
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
          Text('Not collected', style: Theme.of(context).textTheme.titleMedium),
          for (final item in _notCollected)
            ListTile(
              leading: const Icon(Icons.not_interested),
              title: Text(item),
              dense: true,
            ),
        ],
      ),
    );
  }
}
