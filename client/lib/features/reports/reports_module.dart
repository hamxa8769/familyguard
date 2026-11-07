import 'package:flutter/material.dart';
import '../feature_module.dart';

class ReportsModule implements FeatureModule {
  @override
  String get id => 'reports';
  @override
  String get title => 'Dashboard';
  @override
  String get description => 'Daily summary for your child';
  @override
  IconData get icon => Icons.dashboard;
  @override
  Widget buildScreen(BuildContext context) => const ReportsScreen();
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample summary; real data from GET /api/reports/:deviceId
    final apps = const [
      ('Browser', 60),
      ('Games', 30),
      ('Messaging', 20),
      ('Education', 15),
    ];
    final maxMin = apps.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: const [
              _StatCard(label: 'Screen time', value: '2h 5m'),
              SizedBox(width: 12),
              _StatCard(label: 'Alerts', value: '1'),
            ],
          ),
          const SizedBox(height: 24),
          Text('App usage today', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final (name, minutes) in apps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(name), Text('$minutes min')],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: minutes / maxMin),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
