import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../feature_module.dart';

/// Parent side of the installed-apps inventory: what is installed on the
/// child's device, synced by the child app itself. Read-only here — the
/// parent cannot install or remove apps from this screen.
class AppsModule implements FeatureModule {
  @override
  String get id => 'apps';
  @override
  String get title => 'Installed Apps';
  @override
  String get description => 'Apps installed on the child device';
  @override
  IconData get icon => Icons.apps;
  @override
  FeatureSection get section => FeatureSection.activity;
  @override
  Widget buildScreen(BuildContext context) => const AppsScreen();
}

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  final _api = ApiClient();
  final _deviceId = TextEditingController();
  List<InstalledApp> _apps = [];
  String? _status;

  Future<void> _load() async {
    if (_deviceId.text.isEmpty) {
      setState(() => _status = 'Enter a device ID first.');
      return;
    }
    try {
      final data = await _api.get('/api/apps/${_deviceId.text}');
      setState(() {
        _apps = (data['apps'] as List? ?? [])
            .map((a) => InstalledApp.fromMap(a as Map))
            .toList();
        _status = null;
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Could not load apps: ${e.message}');
    }
  }

  @override
  void dispose() {
    _deviceId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Installed Apps')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _deviceId,
            decoration: const InputDecoration(labelText: 'Device ID'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('Load apps')),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!),
          ],
          const SizedBox(height: 8),
          const Text(
            'Synced by the child app itself. The child sees the same list '
            'in their app — nothing is scanned in secret.',
          ),
          for (final app in _apps)
            ListTile(
              leading: Icon(app.systemApp ? Icons.android : Icons.apps),
              title: Text(app.label),
              subtitle: Text(
                '${app.packageName}${app.versionName.isNotEmpty ? ' • v${app.versionName}' : ''}',
              ),
            ),
          if (_apps.isEmpty)
            const ListTile(title: Text('No apps synced yet.')),
        ],
      ),
    );
  }
}
