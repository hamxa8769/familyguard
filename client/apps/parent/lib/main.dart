import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'auth/login_screen.dart';
import 'feature_registry.dart';
import 'state/parent_state.dart';

void main() => runApp(const ParentApp());

class ParentApp extends StatelessWidget {
  const ParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyGuard (Parent)',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

/// Restores the saved session, otherwise shows sign-in.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService.instance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _auth.load().then((_) => setState(() => _loading = false));
  }

  Future<void> _logout() async {
    await _auth.logout();
    ParentState.instance.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_auth.isSignedIn) {
      return LoginScreen(onSignedIn: () => setState(() {}));
    }
    return ParentHome(onLogout: _logout);
  }
}

/// Dashboard builds itself from the feature registry, so new features appear
/// automatically. The device picker at the top decides which child the
/// feature screens show.
class ParentHome extends StatefulWidget {
  const ParentHome({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<ParentHome> createState() => _ParentHomeState();
}

class _ParentHomeState extends State<ParentHome> {
  final _state = ParentState.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _state.refresh();
    // Saved token expired → back to sign in.
    if (_state.unauthorized) {
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = FeatureRegistry.all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyGuard — Parent'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            ListenableBuilder(
              listenable: _state,
              builder: (context, _) => _DevicePicker(state: _state),
            ),
            for (final f in features)
              ListTile(
                leading: Icon(f.icon),
                title: Text(f.title),
                subtitle: Text(f.description),
                // Refresh on return: a device may have paired meanwhile.
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => f.buildScreen(context)))
                    .then((_) => _state.refresh()),
              ),
          ],
        ),
      ),
    );
  }
}

class _DevicePicker extends StatelessWidget {
  const _DevicePicker({required this.state});
  final ParentState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget content;
    if (state.loading && state.children.isEmpty) {
      content = const LinearProgressIndicator();
    } else if (state.error != null) {
      content = Text('Could not load children: ${state.error}',
          style: TextStyle(color: scheme.error));
    } else if (state.devices.isEmpty) {
      content = const Text(
          'No child device paired yet — open "My Children" to get a pairing code.');
    } else {
      content = DropdownButton<String>(
        isExpanded: true,
        value: state.selectedDeviceId,
        underline: const SizedBox.shrink(),
        items: [
          for (final (c, d) in state.devices)
            DropdownMenuItem(
              value: d.id,
              child: Text('${c.displayName} — ${d.deviceName} (${d.platform})'),
            ),
        ],
        onChanged: (id) {
          if (id != null) state.select(id);
        },
      );
    }
    return Card(
      margin: const EdgeInsets.all(12),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.child_care),
            const SizedBox(width: 12),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
