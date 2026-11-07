import 'package:flutter/material.dart';
import '../feature_module.dart';
import 'usage_collector.dart';

/// Example feature. Copy this folder as a template for new features.
class UsageTrackerModule implements FeatureModule {
  @override
  String get id => 'usage_tracker';

  @override
  String get title => 'App Usage';

  @override
  String get description => 'Which apps are used and for how long';

  @override
  IconData get icon => Icons.bar_chart;

  @override
  Widget buildScreen(BuildContext context) => const UsageTrackerScreen();
}

class UsageTrackerScreen extends StatefulWidget {
  const UsageTrackerScreen({super.key});

  @override
  State<UsageTrackerScreen> createState() => _UsageTrackerScreenState();
}

class _UsageTrackerScreenState extends State<UsageTrackerScreen> {
  final _collector = UsageCollector();
  List<UsageEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _collector.collect().then((data) {
      setState(() {
        _entries = data;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('App Usage')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('Usage data is limited on this platform.'))
              : ListView(
                  children: [
                    for (final e in _entries)
                      ListTile(
                        title: Text(e.appName),
                        trailing: Text('${(e.durationSeconds / 60).round()} min'),
                      ),
                  ],
                ),
    );
  }
}
