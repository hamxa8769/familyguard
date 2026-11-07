import 'dart:io' show Platform;
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
  bool _needsPermission = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final granted = await _collector.hasPermission();
    if (!granted) {
      setState(() {
        _needsPermission = true;
        _loading = false;
      });
      return;
    }
    final data = await _collector.collect();
    setState(() {
      _entries = data;
      _needsPermission = false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Usage'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsPermission) {
      return _PermissionPrompt(
        onGrant: () async {
          await _collector.openSettings();
          // User returns from settings; let them refresh.
        },
        onRefresh: _load,
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          Platform.isIOS
              ? 'Usage data is not available on iOS.'
              : 'No usage recorded yet today.',
        ),
      );
    }
    return ListView(
      children: [
        for (final e in _entries)
          ListTile(
            title: Text(_prettyName(e.appName)),
            subtitle: Text(e.appName),
            trailing: Text('${(e.durationSeconds / 60).round()} min'),
          ),
      ],
    );
  }

  // Package names like com.whatsapp -> "whatsapp" for a friendlier label.
  String _prettyName(String pkg) {
    final parts = pkg.split('.');
    return parts.isEmpty ? pkg : parts.last;
  }
}

class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({required this.onGrant, required this.onRefresh});
  final VoidCallback onGrant;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_clock, size: 56),
          const SizedBox(height: 16),
          const Text(
            'Usage Access needed',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'To show app usage, grant FamilyGuard "Usage Access" in system '
            'settings. You can turn it off any time.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onGrant, child: const Text('Open settings')),
          TextButton(onPressed: onRefresh, child: const Text('I\'ve granted it')),
        ],
      ),
    );
  }
}
