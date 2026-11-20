import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

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

class AppsScreen extends StatelessWidget {
  const AppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Installed Apps',
      builder: (context, deviceId) => _AppsBody(deviceId: deviceId),
    );
  }
}

class _AppsBody extends StatelessWidget {
  const _AppsBody({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Installed Apps')),
      // ApiView (Phase 5): loading spinner, error + retry, and
      // pull-to-refresh — previously this screen loaded silently with
      // only a "Refresh" button and an inline error line.
      body: ApiView<List<InstalledApp>>(
        load: () async {
          final data = await ParentState.instance.api.get('/api/apps/$deviceId');
          return (data['apps'] as List? ?? [])
              .map((a) => InstalledApp.fromMap(a as Map))
              .toList();
        },
        builder: (context, apps, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Synced by the child app itself. The child sees the same list '
              'in their app — nothing is scanned in secret.',
            ),
            const SizedBox(height: 8),
            for (final app in apps)
              ListTile(
                leading: Icon(app.systemApp ? Icons.android : Icons.apps),
                title: Text(app.label),
                subtitle: Text(
                  '${app.packageName}${app.versionName.isNotEmpty ? ' • v${app.versionName}' : ''}',
                ),
              ),
            if (apps.isEmpty)
              const EmptyHint('No apps synced yet.'),
          ],
        ),
      ),
    );
  }
}
