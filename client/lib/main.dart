import 'package:flutter/material.dart';
import 'core/consent/consent_service.dart';
import 'core/consent/consent_screen.dart';
import 'features/feature_registry.dart';

void main() {
  runApp(const FamilyGuardApp());
}

class FamilyGuardApp extends StatelessWidget {
  const FamilyGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyGuard',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const HomeGate(),
    );
  }
}

/// Decides the first screen. On a child device, monitoring features are hidden
/// behind the consent gate — they never run until consent is recorded.
class HomeGate extends StatefulWidget {
  const HomeGate({super.key});

  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
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
      return ConsentScreen(
        onAccepted: () => setState(() => _consented = true),
      );
    }
    return const DashboardScreen();
  }
}

/// Builds itself from the feature registry, so new features appear automatically.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final features = FeatureRegistry.all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyGuard'),
        // Persistent, visible indicator — the app never hides that it is active.
        actions: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text('Monitoring: ON')),
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final f in features)
            ListTile(
              leading: Icon(f.icon),
              title: Text(f.title),
              subtitle: Text(f.description),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => f.buildScreen(context)),
              ),
            ),
        ],
      ),
    );
  }
}
