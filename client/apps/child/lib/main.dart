import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:familyguard_core/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'consent/consent_screen.dart';
import 'home/child_home.dart';
import 'pairing/pair_screen.dart';
import 'permissions/permissions_screen.dart';
import 'services/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Push (FCM) is best-effort and inert without a Firebase project: if no
  // google-services.json is configured, FcmService.init() just leaves push
  // off and the app keeps working via polling.
  await FcmService.instance.init();
  runApp(const ChildApp());
}

class ChildApp extends StatelessWidget {
  const ChildApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyGuard (Child)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const StartupGate(),
    );
  }
}

/// Onboarding: 1 connect (pair) → 2 agree (consent) → 3 permissions → home.
/// Nothing is collected or sent until consent is accepted.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});
  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  static const _setupKey = 'permissions_setup_done';

  final _auth = AuthService.instance;
  bool _loading = true;
  bool _consented = false;
  bool _setupDone = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _auth.load();
    // Already paired: (re-)register the FCM token, if push is configured.
    // No-op when Firebase is not set up yet.
    unawaited(FcmService.instance.registerPushToken());
    final consented = await ConsentService().hasConsented();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _consented = consented;
      // Only Android asks for runtime permissions.
      _setupDone = !Platform.isAndroid || (prefs.getBool(_setupKey) ?? false);
      _loading = false;
    });
  }

  Future<void> _finishSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupKey, true);
    setState(() => _setupDone = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget page;
    if (_loading) {
      page = const Scaffold(
          key: ValueKey('loading'),
          body: Center(child: CircularProgressIndicator()));
    } else if (_auth.deviceId == null) {
      page = PairScreen(
          key: const ValueKey('pair'),
          onPaired: () {
            // Just paired: register the FCM token for this device now.
            unawaited(FcmService.instance.registerPushToken());
            setState(() {});
          });
    } else if (!_consented) {
      page = ConsentScreen(
        key: const ValueKey('consent'),
        onAccepted: () => setState(() => _consented = true),
      );
    } else if (!_setupDone) {
      page = PermissionsScreen(
          key: const ValueKey('perms'), onDone: _finishSetup);
    } else {
      page = const ChildHome(key: ValueKey('home'));
    }
    // Smooth cross-fade between onboarding steps.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: page,
    );
  }
}
