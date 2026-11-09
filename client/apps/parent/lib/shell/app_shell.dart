import 'dart:async';
import 'package:flutter/material.dart';
import '../feature_module.dart';
import '../feature_registry.dart';
import '../features/alerts/alerts_module.dart';
import '../features/children/children_module.dart';
import '../home/home_screen.dart';
import '../state/app_controller.dart';
import '../state/parent_state.dart';
import '../theme/app_theme.dart';
import '../ui/fg_widgets.dart';
import 'settings_screen.dart';

/// Opens a feature screen and refreshes shared data when the parent returns
/// (a device may have paired or synced meanwhile).
Future<void> openFeature(BuildContext context, String id) async {
  final module = FeatureRegistry.byId(id);
  if (module == null) return;
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => module.buildScreen(context)));
  final state = ParentState.instance;
  await state.refresh();
  final device = state.selectedDeviceId;
  if (device != null) unawaited(state.loadReport(device));
}

/// Bottom navigation: Home · Activity · Rules · Alerts · Family.
/// IndexedStack keeps each tab alive so switching is instant.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _state = ParentState.instance;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _state.addListener(_onState);
    _state.refresh();
  }

  @override
  void dispose() {
    _state.removeListener(_onState);
    super.dispose();
  }

  // Saved token rejected → back to sign in.
  void _onState() {
    if (_state.unauthorized) {
      _state.unauthorized = false;
      AppController.instance.signOut();
    }
  }

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onGoToTab: _goTo),
          const SectionHub(
            title: 'Activity',
            subtitle: 'What happened on the device',
            section: FeatureSection.activity,
          ),
          const SectionHub(
            title: 'Rules',
            subtitle: 'Limits, blocks and safe zones',
            section: FeatureSection.rules,
          ),
          const AlertsScreen(),
          const ChildrenScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Activity'),
          NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded),
              label: 'Rules'),
          NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'Family'),
        ],
      ),
    );
  }
}

/// A tab that lists every feature of one [FeatureSection] from the registry,
/// so new features appear automatically.
class SectionHub extends StatelessWidget {
  const SectionHub({
    super.key,
    required this.title,
    required this.subtitle,
    required this.section,
  });

  final String title;
  final String subtitle;
  final FeatureSection section;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final modules =
        FeatureRegistry.all.where((m) => m.section == section).toList();
    final state = ParentState.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [SettingsButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            FgSpace.lg, 0, FgSpace.lg, FgSpace.xl),
        children: [
          ListenableBuilder(
            listenable: state,
            builder: (context, _) {
              final sel = state.selected;
              return Text(
                sel == null
                    ? subtitle
                    : '$subtitle · ${sel.$1.displayName}',
                style: TextStyle(color: c.textMuted),
              );
            },
          ),
          const SizedBox(height: FgSpace.md),
          for (final m in modules) ...[
            FeatureTile(
              icon: m.icon,
              title: m.title,
              subtitle: m.description,
              onTap: () => openFeature(context, m.id),
            ),
            const SizedBox(height: FgSpace.sm),
          ],
        ],
      ),
    );
  }
}
