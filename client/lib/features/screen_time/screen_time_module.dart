import 'package:flutter/material.dart';
import '../feature_module.dart';

class ScreenTimeModule implements FeatureModule {
  @override
  String get id => 'screen_time';
  @override
  String get title => 'Screen Time';
  @override
  String get description => 'Set a daily usage limit';
  @override
  IconData get icon => Icons.timelapse;
  @override
  Widget buildScreen(BuildContext context) => const ScreenTimeScreen();
}

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});
  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  double _limit = 120; // minutes
  final int _consumed = 85; // sample consumed minutes

  @override
  Widget build(BuildContext context) {
    final remaining = (_limit - _consumed).clamp(0, _limit).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Screen Time')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Daily limit: ${_limit.round()} min',
                style: Theme.of(context).textTheme.titleLarge),
            Slider(
              value: _limit,
              min: 30,
              max: 480,
              divisions: 15,
              label: '${_limit.round()} min',
              onChanged: (v) => setState(() => _limit = v),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: (_consumed / _limit).clamp(0, 1)),
            const SizedBox(height: 8),
            Text('Used today: $_consumed min  •  Remaining: $remaining min'),
            const Spacer(),
            FilledButton(
              onPressed: () {
                // TODO: PUT /api/screentime/:deviceId { dailyMinutes: _limit }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Limit saved: ${_limit.round()} min')),
                );
              },
              child: const Text('Save limit'),
            ),
          ],
        ),
      ),
    );
  }
}
