import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'consent/consent_screen.dart';
import 'features/usage/usage_screen.dart';
import 'features/location/location_screen.dart';
import 'features/sos/sos_screen.dart';
import 'features/transparency/transparency_screen.dart';

void main() => runApp(const ChildApp());

class ChildApp extends StatelessWidget {
  const ChildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyGuard (Child)',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const ConsentGate(),
    );
  }
}

/// Monitoring features stay behind the consent gate — nothing runs until the
/// child accepts the notice.
class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key});
  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  final _consent = ConsentService();
  bool? _consented;

  @override
  void initState() {
    super.initState();
    _consent.hasConsented().then((v) => setState(() => _consented = v));
  }

  @override
  Widget build(BuildContext context) {
    if (_consented == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_consented == false) {
      return ConsentScreen(onAccepted: () => setState(() => _consented = true));
    }
    return const ChildHome();
  }
}

class ChildHome extends StatelessWidget {
  const ChildHome({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Icons.bar_chart, 'My App Usage', 'See your own screen time',
          const UsageScreen()),
      (Icons.location_on, 'Location Sharing', 'What location is shared',
          const LocationScreen()),
      (Icons.sos, 'SOS', 'Send an emergency alert', const SosScreen()),
      (Icons.visibility, 'What My Parent Sees', 'Full transparency',
          const TransparencyScreen()),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyGuard'),
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text('Monitoring: ON')),
          ),
        ],
      ),
      body: ListView(
        children: [
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
