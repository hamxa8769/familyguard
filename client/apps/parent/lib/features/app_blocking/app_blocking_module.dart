import 'package:flutter/material.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

class AppBlockingModule implements FeatureModule {
  @override
  String get id => 'app_blocking';
  @override
  FeatureSection get section => FeatureSection.rules;
  @override
  String get title => 'App Blocking';
  @override
  String get description => 'Choose which apps to block';
  @override
  IconData get icon => Icons.block;
  @override
  Widget buildScreen(BuildContext context) => const AppBlockingScreen();
}

class AppBlockingScreen extends StatelessWidget {
  const AppBlockingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'App Blocking',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('App Blocking')),
        body: ApiView<(List<String>, Set<String>)>(
          load: () async {
            final api = ParentState.instance.api;
            // Apps the device has reported, plus anything already blocked.
            final usage = await api.get('/api/usage/$deviceId');
            final blocked = await api.get('/api/appblocking/$deviceId');
            final seen = [
              for (final a in usage['apps'] as List) a['appName'].toString(),
            ];
            return (seen, {...List<String>.from(blocked['apps'] as List)});
          },
          builder: (context, data, _) => _BlockList(
              deviceId: deviceId, seenApps: data.$1, blocked: data.$2),
        ),
      ),
    );
  }
}

class _BlockList extends StatefulWidget {
  const _BlockList(
      {required this.deviceId, required this.seenApps, required this.blocked});
  final String deviceId;
  final List<String> seenApps;
  final Set<String> blocked;

  @override
  State<_BlockList> createState() => _BlockListState();
}

class _BlockListState extends State<_BlockList> {
  late final Set<String> _blocked = {...widget.blocked};
  late final List<String> _apps = {...widget.seenApps, ...widget.blocked}
      .toList()
    ..sort();
  final _add = TextEditingController();

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  void _addApp() {
    final name = _add.text.trim();
    if (name.isEmpty) return;
    setState(() {
      if (!_apps.contains(name)) _apps.add(name);
      _blocked.add(name);
      _add.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _add,
                  decoration: const InputDecoration(
                    labelText: 'Add app (package name)',
                    hintText: 'com.example.game',
                  ),
                  onSubmitted: (_) => _addApp(),
                ),
              ),
              IconButton(icon: const Icon(Icons.add), onPressed: _addApp),
            ],
          ),
        ),
        if (_apps.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No apps reported by the device yet. Apps appear here '
                'once the child app has shared usage.'),
          ),
        for (final app in _apps)
          SwitchListTile(
            title: Text(app, overflow: TextOverflow.ellipsis),
            subtitle: Text(_blocked.contains(app) ? 'Blocked' : 'Allowed'),
            value: _blocked.contains(app),
            onChanged: (v) =>
                setState(() => v ? _blocked.add(app) : _blocked.remove(app)),
          ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => saveWithFeedback(
              context,
              () => ParentState.instance.api.put(
                  '/api/appblocking/${widget.deviceId}',
                  {'apps': _blocked.toList()}),
              'Block list saved (${_blocked.length} apps)',
            ),
            child: const Text('Save block list'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'The list is saved and shown to the child. Blocking the apps on '
            'the device itself is not enforced yet.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
