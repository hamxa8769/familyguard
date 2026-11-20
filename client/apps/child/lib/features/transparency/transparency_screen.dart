import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../build_flavor.dart';

/// Unique feature: the child sees EXACTLY what the parent sees.
/// Loads GET /api/transparency/:deviceId — the same report the parent gets.
class TransparencyScreen extends StatefulWidget {
  const TransparencyScreen({super.key});

  static const _collected = [
    'Which apps are used and for how long',
    'This device\'s location and location history',
    'Screen-time usage against the daily limit',
    'Geofence enter/exit events',
    'SOS alerts you trigger',
    'Your SMS messages (sender, text, and time)',
    'Your contacts (names and numbers)',
    'Your call history (number, type, time, duration)',
    'Your photos and files (name, size, date)',
    'Remote commands from your parent (lock now, unlock, messages)',
    'Screenshots taken only after a notification and countdown on this device',
    'Short audio clips (max 30 seconds) only when you press SOS or after a visible request',
    'Which apps are installed on this device',
    'Browser sessions: which browser was open, when, and for how long (never the pages or URLs)',
    'Bedtime and app-blocking rules your parent set, and when they block an app',
    'The family agreement you signed (or declined)',
    'Reward points and badges you earned',
  ];

  static const _notCollected = [
    'Live camera capture',
    'Continuous or ambient microphone listening',
    'Secret screenshots (every screenshot is announced first)',
    'The web pages or URLs you visit',
    'The content of apps other than SMS, call log, contacts and gallery (as listed above)',
  ];
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
          // The collected / not-collected lists are static and known locally,
          // so they render immediately (and offline) from the empty-data
          // fallback; the live report fills in when the server answers.
          return _Body(data: snap.data ?? const {});
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
    // The server's list is authoritative; fall back to the static list
    // (same wording as the consent notice) when it comes back empty.
    final serverCollected =
        List<String>.from(data['collected'] as List? ?? const []);
    final collected = (serverCollected.isEmpty
            ? TransparencyScreen._collected
            : serverCollected)
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
    final audit = List<Map<String, dynamic>>.from(
      (report['auditLog'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
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
        // The audit log: every remote command and capture, newest first.
        // The server includes it in the report (and at
        // GET /api/transparency/:deviceId/audit), so the promise above —
        // "every command is listed in the audit log below" — is true.
        Text('Audit log — every command and capture', style: title),
        if (audit.isEmpty)
          const ListTile(
            dense: true,
            leading: Icon(Icons.history),
            title: Text('No commands or captures recorded yet.'),
          ),
        for (final e in audit.take(20))
          ListTile(
            dense: true,
            leading: const Icon(Icons.history),
            title: Text(e['action']?.toString() ?? ''),
            subtitle: Text(e['at']?.toString() ?? ''),
          ),
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
        for (final item in TransparencyScreen._notCollected)
          ListTile(
            leading: const Icon(Icons.not_interested),
            title: Text(item),
            dense: true,
          ),
      ],
    );
  }
}
