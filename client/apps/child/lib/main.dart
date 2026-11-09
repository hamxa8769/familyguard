import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'consent/consent_screen.dart';
import 'pairing/pair_screen.dart';
import 'sync/sync_service.dart';
import 'features/usage/usage_screen.dart';
import 'features/location/location_screen.dart';
import 'features/sos/sos_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/call_log/call_log_screen.dart';
import 'features/gallery/gallery_screen.dart';
import 'features/transparency/transparency_screen.dart';

void main() => runApp(const ChildApp());

class ChildApp extends StatelessWidget {
  const ChildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyGuard (Child)',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const StartupGate(),
    );
  }
}

/// Order: pair with the parent → accept the consent notice → home.
/// Nothing is collected or sent until consent is accepted.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});
  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  final _auth = AuthService.instance;
  final _consent = ConsentService();
  bool _loading = true;
  bool _consented = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _auth.load();
    final consented = await _consent.hasConsented();
    setState(() {
      _consented = consented;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_auth.deviceId == null) {
      return PairScreen(onPaired: () => setState(() {}));
    }
    if (!_consented) {
      return ConsentScreen(onAccepted: () => setState(() => _consented = true));
    }
    return const ChildHome();
  }
}

class ChildHome extends StatefulWidget {
  const ChildHome({super.key});

  @override
  State<ChildHome> createState() => _ChildHomeState();
}

class _ChildHomeState extends State<ChildHome> {
  final _sync = SyncService.instance;

  @override
  void initState() {
    super.initState();
    _sync.start();
  }

  @override
  void dispose() {
    _sync.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Icons.bar_chart, 'My App Usage', 'See your own screen time',
          const UsageScreen()),
      (Icons.location_on, 'Location Sharing', 'What location is shared',
          const LocationScreen()),
      (Icons.sos, 'SOS', 'Send an emergency alert', const SosScreen()),
      (Icons.sms, 'Messages & Contacts', 'What SMS/contacts are shared',
          const MessagesScreen()),
      (Icons.call, 'Call Log', 'What call history is shared',
          const CallLogScreen()),
      (Icons.photo_library, 'Gallery & Files', 'What photos/files are shared',
          const GalleryScreen()),
      (Icons.visibility, 'What My Parent Sees', 'Full transparency',
          const TransparencyScreen()),
    ];
    final name = AuthService.instance.childName;
    return Scaffold(
      appBar: AppBar(
        title: Text(name == null ? 'FamilyGuard' : 'FamilyGuard — $name'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: _sync.syncNow,
          ),
        ],
      ),
      body: ListView(
        children: [
          ValueListenableBuilder<SyncStatus>(
            valueListenable: _sync.status,
            builder: (context, s, _) => _SyncBanner(status: s),
          ),
          for (final (icon, title, subtitle, screen) in tiles)
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => screen),
              ),
            ),
        ],
      ),
    );
  }
}

/// Visible status: monitoring is on and when data was last shared.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String text;
    if (status.running) {
      text = 'Sharing with your parent…';
    } else if (status.at == null) {
      text = 'Monitoring is ON. Not shared yet.';
    } else {
      final t = TimeOfDay.fromDateTime(status.at!).format(context);
      final what = status.sent.isEmpty ? 'nothing new' : status.sent.join(', ');
      text = 'Monitoring is ON. Last shared at $t: $what.';
    }
    return Card(
      margin: const EdgeInsets.all(12),
      color: status.error != null
          ? scheme.errorContainer
          : scheme.secondaryContainer,
      child: ListTile(
        leading: Icon(status.error != null ? Icons.cloud_off : Icons.cloud_done),
        title: Text(text),
        subtitle: status.error != null ? Text(status.error!) : null,
      ),
    );
  }
}
