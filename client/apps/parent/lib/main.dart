import 'package:flutter/material.dart';
import 'auth/login_screen.dart';
import 'shell/app_shell.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppController.instance.load();
  runApp(const ParentApp());
}

class ParentApp extends StatelessWidget {
  const ParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppController.instance;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'FamilyGuard (Parent)',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: app.themeMode,
        home: !app.ready
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : app.signedIn
                ? const AppShell()
                : LoginScreen(onSignedIn: app.signedInChanged),
      ),
    );
  }
}
