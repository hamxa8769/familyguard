import 'package:flutter/material.dart';
import 'package:familyguard_core/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pairing/pair_screen.dart' show OnboardingSteps;
import '../enforcement/enforcement.dart';
import 'permissions.dart';

/// Step 3 of onboarding (and later: Home → Permissions).
/// Each permission is asked one at a time with its reason; the child may skip
/// any of them. Status re-checks when the child returns from Android Settings.
///
/// "Allow all" walks the list in order: runtime-dialog items chain
/// immediately, one system dialog each, while Settings-page items
/// (usage, overlay, device admin) open their Settings page and pause the
/// chain — the child returns from Settings and taps "Allow all" again to
/// continue. A twice-denied item stops showing a dead Allow button and
/// offers the app Settings page instead.
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

  /// Items whose system dialog/Settings page was opened at least once.
  /// Persisted: Android cannot tell "never asked" apart from "don't ask
  /// again", so permanently-denied is only evaluated for these items.
  final Set<String> _requested = {};

  /// Items Android will no longer show a dialog for (from [PermissionItem.
  /// permanentlyDenied]); their card offers the app Settings page instead.
  final Map<String, bool> _permanentlyDenied = {};

  bool _allowAllRunning = false;

  static String _requestedKey(String id) => 'fg_perm_requested_$id';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    for (final p in _items) {
      if (prefs.getBool(_requestedKey(p.id)) ?? false) {
        _requested.add(p.id);
      }
    }
    await _refresh();
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
    // Only items already requested can be permanently denied; a fresh
    // item with no rationale yet must keep its normal Allow button.
    for (final p in _items) {
      if (_granted[p.id] == true ||
          !_requested.contains(p.id) ||
          p.permanentlyDenied == null) {
        _permanentlyDenied[p.id] = false;
      } else {
        _permanentlyDenied[p.id] = await p.permanentlyDenied!();
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _markRequested(PermissionItem p) async {
    if (_requested.add(p.id)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_requestedKey(p.id), true);
    }
  }

  Future<void> _ask(PermissionItem p) async {
    await _markRequested(p);
    await p.request();
    // Dialog-based permissions answer quickly; Settings ones on resume.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _refresh();
  }

  /// Walks the not-yet-granted items in order. Dialog items chain
  /// immediately; a Settings-page item pauses the chain (the child is now
  /// in Settings — re-check on resume, then "Allow all" again to continue).
  /// Permanently-denied items are skipped: their dialog would not show.
  Future<void> _allowAll() async {
    if (_allowAllRunning) return;
    setState(() => _allowAllRunning = true);
    try {
      for (final p in _items) {
        if (!mounted) return;
        await _refresh();
        if (!mounted) return;
        if (_granted[p.id] == true) continue;
        if (_permanentlyDenied[p.id] == true) continue;
        await _ask(p);
        if (!mounted) return;
        // The child is now in a Settings page; stop here. Returning
        // re-checks on resume and "Allow all" continues from the next item.
        if (p.opensSettings) return;
      }
    } finally {
      if (mounted) setState(() => _allowAllRunning = false);
    }
  }

  Future<void> _openAppSettings() async {
    await AppSettings.openAppSettings();
    // Returning from Settings re-checks on resume; refresh too, in case
    // the Settings page was opened without leaving the app.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final onboarding = widget.onDone != null;
    final done = _granted.values.where((v) => v).length;
    final total = _items.length;
    final allDone = total > 0 && done == total;

    final allowAllButton = SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(
        onPressed: _allowAllRunning || allDone ? null : _allowAll,
        child: Text(_allowAllRunning ? 'Allowing…' : 'Allow all'),
      ),
    );

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
            'Android asks you for each one. Tap "Allow all" to go through '
            'them one by one, or allow them one at a time below. You can '
            'skip any of them and turn them on later from the home screen.',
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
                color: allDone ? c.safe : c.accent,
                center: Text('$done/$total', style: fgNumber(context, 14)),
              ),
              const SizedBox(width: FgSpace.lg),
              Expanded(
                child: Text(
                  total == 0
                      ? 'Nothing to allow on this device.'
                      : allDone
                          ? 'All set — everything is allowed.'
                          : '${total - done} still off',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: FgSpace.md),
        if (!allDone) ...[
          allowAllButton,
          const SizedBox(height: FgSpace.md),
        ],
        for (final p in _items) ...[
          _PermissionCard(
            item: p,
            granted: _granted[p.id],
            permanentlyDenied: _permanentlyDenied[p.id] ?? false,
            onAllow: () => _ask(p),
            onOpenSettings: _openAppSettings,
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
                  child: Text(allDone ? 'Finish' : 'Continue'),
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
    required this.permanentlyDenied,
    required this.onAllow,
    required this.onOpenSettings,
  });

  final PermissionItem item;
  final bool? granted;
  final bool permanentlyDenied;
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

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
                if (!on && permanentlyDenied) ...[
                  const SizedBox(height: 2),
                  Text('Android will not show this request again — turn it '
                      'on in Settings.',
                      style: TextStyle(color: c.textMuted, fontSize: 13)),
                ],
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
                    : permanentlyDenied
                        ? TextButton(
                            key: const ValueKey('settings'),
                            onPressed: onOpenSettings,
                            child: const Text('Open Settings'),
                          )
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
