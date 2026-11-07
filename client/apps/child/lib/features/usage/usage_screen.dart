import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'usage_collector.dart';

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});
  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
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
    if (!await _collector.hasPermission()) {
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
        title: const Text('My App Usage'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_needsPermission) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_clock, size: 56),
            const SizedBox(height: 16),
            const Text('Usage Access needed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'To show app usage, grant FamilyGuard "Usage Access" in system '
              'settings. You can turn it off any time.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _collector.openSettings(),
              child: const Text('Open settings'),
            ),
            TextButton(
                onPressed: _load, child: const Text('I\'ve granted it')),
          ],
        ),
      );
    }
    if (_entries.isEmpty) {
      return Center(
        child: Text(Platform.isIOS
            ? 'Usage data is not available on iOS.'
            : 'No usage recorded yet today.'),
      );
    }
    return ListView(
      children: [
        for (final e in _entries)
          ListTile(
            title: Text(_prettyName(e.appName)),
            subtitle: Text(e.appName),
            trailing: Text('${e.minutes} min'),
          ),
      ],
    );
  }

  String _prettyName(String pkg) {
    final parts = pkg.split('.');
    return parts.isEmpty ? pkg : parts.last;
  }
}
