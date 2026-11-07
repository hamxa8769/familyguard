import 'package:flutter/material.dart';
import '../../feature_module.dart';

class AppBlockingModule implements FeatureModule {
  @override
  String get id => 'app_blocking';
  @override
  String get title => 'App Blocking';
  @override
  String get description => 'Choose which apps to block';
  @override
  IconData get icon => Icons.block;
  @override
  Widget buildScreen(BuildContext context) => const AppBlockingScreen();
}

class AppBlockingScreen extends StatefulWidget {
  const AppBlockingScreen({super.key});
  @override
  State<AppBlockingScreen> createState() => _AppBlockingScreenState();
}

class _AppBlockingScreenState extends State<AppBlockingScreen> {
  final _apps = {
    'Games': true,
    'Social Media': true,
    'Browser': false,
    'Messaging': false,
    'Education': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Blocking')),
      body: ListView(
        children: [
          for (final entry in _apps.entries)
            SwitchListTile(
              title: Text(entry.key),
              subtitle: Text(entry.value ? 'Blocked' : 'Allowed'),
              value: entry.value,
              onChanged: (v) => setState(() => _apps[entry.key] = v),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () {
                // TODO: PUT /api/appblocking/:deviceId { apps: blockedList }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Block list saved')),
                );
              },
              child: const Text('Save block list'),
            ),
          ),
        ],
      ),
    );
  }
}
