import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/share_file.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';
import '../messages/messages_module.dart';

class CallLogModule implements FeatureModule {
  @override
  String get id => 'call_log';
  @override
  FeatureSection get section => FeatureSection.activity;
  @override
  String get title => 'Call Log';
  @override
  String get description => 'View the child\'s call history';
  @override
  IconData get icon => Icons.call;
  @override
  Widget buildScreen(BuildContext context) => const CallLogViewScreen();
}

class CallLogViewScreen extends StatefulWidget {
  const CallLogViewScreen({super.key});

  @override
  State<CallLogViewScreen> createState() => _CallLogViewScreenState();
}

class _CallLogViewScreenState extends State<CallLogViewScreen> {
  String _query = '';
  final int _limit = 200;
  CommsData? _lastData;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  IconData _icon(int type) => switch (type) {
        2 => Icons.call_made,
        3 => Icons.call_missed,
        _ => Icons.call_received,
      };

  String _duration(int seconds) {
    if (seconds <= 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  Future<void> _export(String deviceId, String type, String format) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ParentState.instance.api.getBytes(
        '/api/comms/$deviceId/export?format=$format&type=$type',
      );
      if (!mounted) return;
      final data = _lastData;
      final counts = data == null
          ? ''
          : ' (${data.calls.length} calls retained on the server)';
      await saveAndShareBytes(
        context,
        bytes,
        'familyguard-comms-$deviceId-$type.$format',
        mimeType: format == 'csv' ? 'text/csv' : 'application/json',
      );
      messenger.showSnackBar(SnackBar(content: Text('Exported$counts')));
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Call Log',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(
          title: const Text('Call Log'),
          actions: [
            PopupMenuButton<(String, String)>(
              icon: const Icon(Icons.download),
              tooltip: 'Export',
              onSelected: (choice) => _export(deviceId, choice.$1, choice.$2),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: ('calls', 'csv'), child: Text('Calls (CSV)')),
                PopupMenuItem(
                    value: ('all', 'json'),
                    child: Text('Everything (JSON)')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: 'Search by number…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: ApiView<CommsData>(
                key: ValueKey('$_query|$_limit'),
                load: () => CommsData.load(
                  deviceId,
                  q: _query.isEmpty ? null : _query,
                  limit: _limit,
                ),
                builder: (context, data, _) {
                  _lastData = data;
                  if (data.calls.isEmpty) {
                    return const EmptyHint('No call history shared yet (Android only, '
                        'after the child allows call-log access).');
                  }
                  return ListView(
                    children: [
                      for (final c in data.calls)
                        ListTile(
                          leading: Icon(_icon(c.type),
                              color: c.type == 3 ? Colors.red : null),
                          title: Text(
                            data.contactNameFor(c.number) ?? c.number,
                          ),
                          subtitle: Text(
                            '${c.typeLabel} • ${timeAgo(c.date)}'
                            '${data.contactNameFor(c.number) != null ? '\n${c.number}' : ''}',
                          ),
                          trailing: Text(_duration(c.durationSeconds)),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '${data.calls.length} calls retained on the server',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
