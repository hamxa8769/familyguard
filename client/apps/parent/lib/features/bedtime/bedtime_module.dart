import 'package:flutter/material.dart';
import '../../feature_module.dart';

class BedtimeModule implements FeatureModule {
  @override
  String get id => 'bedtime';
  @override
  String get title => 'Bedtime';
  @override
  String get description => 'Lock the device at night';
  @override
  IconData get icon => Icons.bedtime;
  @override
  Widget buildScreen(BuildContext context) => const BedtimeScreen();
}

class BedtimeScreen extends StatefulWidget {
  const BedtimeScreen({super.key});
  @override
  State<BedtimeScreen> createState() => _BedtimeScreenState();
}

class _BedtimeScreenState extends State<BedtimeScreen> {
  TimeOfDay _start = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 6, minute: 0);

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bedtime')),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.nightlight),
            title: const Text('Lock from'),
            trailing: Text(_start.format(context)),
            onTap: () => _pick(true),
          ),
          ListTile(
            leading: const Icon(Icons.wb_sunny),
            title: const Text('Unlock at'),
            trailing: Text(_end.format(context)),
            onTap: () => _pick(false),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: () {
                // TODO: PUT /api/bedtime/:deviceId { startHour, endHour }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bedtime schedule saved')),
                );
              },
              child: const Text('Save schedule'),
            ),
          ),
        ],
      ),
    );
  }
}
