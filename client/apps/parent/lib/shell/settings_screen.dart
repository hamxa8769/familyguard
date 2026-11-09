import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../ui/fg_widgets.dart';

/// App-bar shortcut to Settings, shared by every tab.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen())),
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppController.instance;
    final auth = AuthService.instance;
    final c = FgColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(FgSpace.lg),
        children: [
          FgCard(
            child: Row(
              children: [
                const IconWell(Icons.person_outline_rounded),
                const SizedBox(width: FgSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.displayName ?? 'Parent',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(auth.api.baseUrl,
                          style: TextStyle(color: c.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionLabel('Appearance'),
          ListenableBuilder(
            listenable: app,
            builder: (context, _) => SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark')),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light')),
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('Auto')),
              ],
              selected: {app.themeMode},
              onSelectionChanged: (s) => app.setThemeMode(s.first),
            ),
          ),
          const SectionLabel('Account'),
          FgCard(
            padding: EdgeInsets.zero,
            borderColor: c.tint(c.danger),
            onTap: () async {
              Navigator.of(context).popUntil((r) => r.isFirst);
              await app.signOut();
            },
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: c.danger),
              title: Text('Sign out', style: TextStyle(color: c.danger)),
            ),
          ),
        ],
      ),
    );
  }
}
