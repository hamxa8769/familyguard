import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../build_flavor.dart';

/// Unique feature: the child sees EXACTLY what the parent sees.
/// Loads GET /api/transparency/:deviceId — the same report the parent gets.
class TransparencyScreen extends StatefulWidget {
  const TransparencyScreen({super.key});

  @override
  State<TransparencyScreen> createState() => _TransparencyScreenState();
}

class _TransparencyScreenState extends State<TransparencyScreen> {
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async {
    final auth = AuthService.instance;
    final res = await auth.api.get('/api/transparency/${auth.deviceId}');
    return Map<String, dynamic>.from(res as Map);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('What My Parent Sees'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _future = _load()),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load: ${snap.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return _Body(data: snap.data!);
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final collected = List<String>.from(data['collected'] as List? ?? const [])
        // The lite build never reads SMS, contacts or calls.
        .where((s) =>
            !kLiteBuild || !RegExp(r'SMS|contacts|call history').hasMatch(s))
        .toList();
    final report = Map<String, dynamic>.from(data['report'] as Map? ?? {});
    final screen = report['screenTime'] as Map?;
    final usage = (report['usage']?['apps'] as List? ?? const [])
        .map((e) => UsageEntry.fromMap(e as Map))
        .toList();
    final loc = LocationPoint.fromServer(report['lastLocation'] as Map?);
    final bedtime = report['bedtime'] as Map?;
    final blocked = List<String>.from(report['blockedApps'] as List? ?? const []);
    final title = Theme.of(context).textTheme.titleMedium;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(data['notice']?.toString() ??
                'This is exactly what your parent can see.'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Your parent\'s current report', style: title),
        ListTile(
          dense: true,
          leading: const Icon(Icons.timelapse),
          title: Text('Screen time: ${screen?['consumedMinutes'] ?? 0} min'
              '${screen?['dailyMinutes'] != null ? ' of ${screen!['dailyMinutes']} min' : ''}'),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.location_on),
          title: Text(loc == null
              ? 'Location: not shared yet'
              : 'Last location: ${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)}'),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.bedtime),
          title: Text(bedtime == null
              ? 'Bedtime: not set'
              : 'Bedtime: ${bedtime['startHour']}:00 → ${bedtime['endHour']}:00'),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.block),
          title: Text(blocked.isEmpty
              ? 'Blocked apps: none'
              : 'Blocked apps: ${blocked.join(', ')}'),
        ),
        if (usage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('App usage your parent sees', style: title),
          for (final u in usage.take(10))
            ListTile(
              dense: true,
              title: Text(u.appName),
              trailing: Text('${u.minutes} min'),
            ),
        ],
        const SizedBox(height: 16),
        Text('Information collected', style: title),
        for (final item in collected)
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(item),
            dense: true,
          ),
        const SizedBox(height: 8),
        Text('Not collected', style: title),
        const ListTile(
          leading: Icon(Icons.not_interested),
          title: Text('Live camera or microphone capture'),
          dense: true,
        ),
      ],
    );
  }
}
