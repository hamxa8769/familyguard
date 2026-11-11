import 'package:flutter/material.dart';
import 'package:familyguard_core/ui.dart';
import '../pairing/pair_screen.dart' show OnboardingSteps;
import '../enforcement/enforcement.dart';
import 'permissions.dart';

/// Step 3 of onboarding (and later: Home → Permissions).
/// Each permission is asked one at a time with its reason; the child may skip
/// any of them. Status re-checks when the child returns from Android Settings.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, this.onDone});

  /// Set during onboarding; null when opened from Home.
  final VoidCallback? onDone;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final _items = permissionItems();
  final Map<String, bool> _granted = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await Enforcement.apply();
    for (final p in _items) {
      _granted[p.id] = await p.check();
    }
    if (mounted) setState(() {});
  }

  Future<void> _ask(PermissionItem p) async {
    await p.request();
    // Dialog-based permissions answer quickly; Settings ones on resume.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final onboarding = widget.onDone != null;
    final done = _granted.values.where((v) => v).length;
    final total = _items.length;

    final list = ListView(
      padding: const EdgeInsets.all(FgSpace.xl),
      children: [
        if (onboarding) ...[
          const OnboardingSteps(current: 2),
          const SizedBox(height: FgSpace.xl),
          Text('Allow access',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: FgSpace.sm),
          Text(
            'Android asks you for each one. You can skip any of them and turn '
            'them on later from the home screen.',
            style: TextStyle(color: c.textMuted),
          ),
          const SizedBox(height: FgSpace.lg),
        ],
        FgCard(
          child: Row(
            children: [
              StatRing(
                value: total == 0 ? 1 : done / total,
                size: 56,
                stroke: 6,
                color: done == total ? c.safe : c.accent,
                center: Text('$done/$total', style: fgNumber(context, 14)),
              ),
              const SizedBox(width: FgSpace.lg),
              Expanded(
                child: Text(
                  total == 0
                      ? 'Nothing to allow on this device.'
                      : done == total
                          ? 'All set — everything is allowed.'
                          : '${total - done} still off',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: FgSpace.md),
        for (final p in _items) ...[
          _PermissionCard(
            item: p,
            granted: _granted[p.id],
            onAllow: () => _ask(p),
          ),
          const SizedBox(height: FgSpace.sm),
        ],
      ],
    );

    if (!onboarding) {
      return Scaffold(
        appBar: AppBar(title: const Text('Permissions')),
        body: RefreshIndicator(onRefresh: _refresh, child: list),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: list),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  FgSpace.xl, 0, FgSpace.xl, FgSpace.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.onDone,
                  child: Text(done == total ? 'Finish' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.item,
    required this.granted,
    required this.onAllow,
  });

  final PermissionItem item;
  final bool? granted;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final on = granted == true;
    return FgCard(
      padding: const EdgeInsets.all(FgSpace.md),
      borderColor: on ? c.tint(c.safe) : null,
      child: Row(
        children: [
          IconWell(item.icon, color: on ? c.safe : c.accent),
          const SizedBox(width: FgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.why,
                    style: TextStyle(color: c.textMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: FgSpace.sm),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: granted == null
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : on
                    ? Icon(Icons.check_circle_rounded,
                        key: const ValueKey('on'), color: c.safe)
                    : TextButton(
                        key: const ValueKey('off'),
                        onPressed: onAllow,
                        child: Text(item.opensSettings ? 'Open' : 'Allow'),
                      ),
          ),
        ],
      ),
    );
  }
}
