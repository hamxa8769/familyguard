import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../services/native_collectors.dart';

/// Child side of the installed-apps inventory: shows what the parent can
/// see (app names + versions) and syncs the on-device list on demand.
/// Collection is disclosed in consent + transparency; there is no hidden
/// scan — the child taps "Sync" and sees the same list.
class InstalledAppsScreen extends StatefulWidget {
  const InstalledAppsScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<InstalledAppsScreen> createState() => _InstalledAppsScreenState();
}

class _InstalledAppsScreenState extends State<InstalledAppsScreen> {
  final _api = ApiClient();
  List<InstalledApp> _apps = [];
  String? _status;
  bool _loading = false;

  Future<void> _load() async {
    if (widget.deviceId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/apps/${widget.deviceId}');
      setState(() {
        _apps = (data['apps'] as List? ?? [])
            .map((a) => InstalledApp.fromMap(a as Map))
            .toList();
        _status = null;
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Could not load apps: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _loading = true);
    try {
      final local = await NativeCollectors.getInstalledApps();
      await _api.post('/api/apps/${widget.deviceId}/sync', {
        'apps': local
            .map((a) => {
                  'packageName': a.packageName,
                  'label': a.label,
                  'versionName': a.versionName,
                  'installedAt': a.installedAt,
                  'systemApp': a.systemApp,
                })
            .toList(),
      });
      await _load();
      setState(() => _status = 'Synced ${local.length} apps.');
    } on ApiException catch (e) {
      setState(() => _status = 'Sync failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Installed Apps')),
      body: widget.deviceId.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('This device is not registered yet.'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Your parent can see which apps are installed on this '
                    'device. This list is collected by the app itself — '
                    'nothing is read in secret.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loading ? null : _sync,
                    child: const Text('Sync installed apps now'),
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 8),
                    Text(_status!),
                  ],
                  if (_loading) const LinearProgressIndicator(),
                  for (final app in _apps)
                    ListTile(
                      leading: Icon(
                        app.systemApp ? Icons.android : Icons.apps,
                      ),
                      title: Text(app.label),
                      subtitle: Text(
                        '${app.packageName}${app.versionName.isNotEmpty ? ' • v${app.versionName}' : ''}',
                      ),
                    ),
                  if (_apps.isEmpty && !_loading)
                    const ListTile(title: Text('No apps synced yet.')),
                ],
              ),
            ),
    );
  }
}
