import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../common/widgets.dart' show formatMinutes, timeAgo;
import '../shell/app_shell.dart' show openFeature;
import '../shell/settings_screen.dart';
import '../state/parent_state.dart';
import '../theme/app_theme.dart';
import '../ui/fg_widgets.dart';

/// Parent "cockpit": one glance tells whether the selected child is OK.
/// Shows the cached report instantly, refreshes in the background, and
/// re-polls every minute while visible.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onGoToTab});

  /// Switches the bottom-navigation tab (3 = Alerts, 4 = Family).
  final ValueChanged<int> onGoToTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _state = ParentState.instance;
  String? _lastDevice;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _state.addListener(_maybeLoad);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoad());
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _reload());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _state.removeListener(_maybeLoad);
    super.dispose();
  }

  // Load the report whenever the selected device changes.
  void _maybeLoad() {
    final id = _state.selectedDeviceId;
    if (id != null && id != _lastDevice) {
      _lastDevice = id;
      _state.loadReport(id);
    }
  }

  Future<void> _reload() async {
    await _state.refresh();
    final id = _state.selectedDeviceId;
    if (id != null) await _state.loadReport(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListenableBuilder(
            listenable: _state,
            builder: (context, _) => _body(context),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final sel = _state.selected;
    final children = <Widget>[
      const _Header(),
      const SizedBox(height: FgSpace.md),
      if (_state.devices.isNotEmpty) _DeviceChips(state: _state),
    ];

    if (sel == null) {
      children.add(_state.loading && _state.children.isEmpty
          ? const _HomeSkeleton()
          : _PairFirst(onTap: () => widget.onGoToTab(4)));
    } else {
      final (child, device) = sel;
      final report = _state.reportFor(device.id);
      final error = _state.reportError(device.id);
      children.addAll([
        const SizedBox(height: FgSpace.md),
        _DeviceStatus(device: device, loading: _state.reportLoading(device.id)),
        if (error != null && report == null)
          Padding(
            padding: const EdgeInsets.only(top: FgSpace.md),
            child: FgCard(child: Text('Couldn\'t load the report. $error')),
          ),
        if (report == null && error == null) const _HomeSkeleton(),
        if (report != null)
          ..._reportCards(context, child.displayName, report),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          FgSpace.lg, FgSpace.md, FgSpace.lg, FgSpace.xl),
      children: children,
    );
  }

  List<Widget> _reportCards(BuildContext context, String name, Map report) {
    final sos = (report['activeSosAlerts'] as List? ?? const []);
    return [
      if (sos.isNotEmpty) ...[
        const SizedBox(height: FgSpace.md),
        _SosBanner(
          name: name,
          alert: SosAlert.fromMap(sos.last as Map),
          count: sos.length,
          onTap: () => widget.onGoToTab(3),
        ),
      ],
      const SizedBox(height: FgSpace.md),
      _ScreenTimeCard(report: report),
      const SizedBox(height: FgSpace.md),
      _LocationCard(report: report),
      const SectionLabel('Quick actions'),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: FgSpace.sm,
        crossAxisSpacing: FgSpace.sm,
        childAspectRatio: 0.7,
        children: [
          QuickAction(
              icon: Icons.timelapse_rounded,
              label: 'Limit',
              onTap: () => openFeature(context, 'screen_time')),
          QuickAction(
              icon: Icons.bedtime_outlined,
              label: 'Bedtime',
              onTap: () => openFeature(context, 'bedtime')),
          QuickAction(
              icon: Icons.block_rounded,
              label: 'Block',
              onTap: () => openFeature(context, 'app_blocking')),
          QuickAction(
              icon: Icons.shield_moon_outlined,
              label: 'Zones',
              color: FgColors.of(context).safe,
              onTap: () => openFeature(context, 'geofencing')),
        ],
      ),
      const SectionLabel('Rules in effect'),
      _RulesSummary(report: report),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final name = AuthService.instance.displayName;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name == null ? _greeting() : '${_greeting()}, $name',
                  style: TextStyle(color: c.textMuted, fontSize: 14)),
              const SizedBox(height: 2),
              Text('Family overview',
                  style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        const SettingsButton(),
      ],
    );
  }
}

class _DeviceChips extends StatelessWidget {
  const _DeviceChips({required this.state});
  final ParentState state;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.devices.length,
        separatorBuilder: (_, __) => const SizedBox(width: FgSpace.sm),
        itemBuilder: (context, i) {
          final (child, device) = state.devices[i];
          final selected = device.id == state.selectedDeviceId;
          final multi = state.children
                  .firstWhere((x) => x.id == child.id)
                  .devices
                  .length >
              1;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? c.tint(c.accent) : c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? c.accent : c.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => state.select(device.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: selected ? c.accent : c.surfaceHigh,
                      child: Text(
                        child.displayName.isEmpty
                            ? '?'
                            : child.displayName[0].toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.white : c.text,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      multi
                          ? '${child.displayName} · ${device.deviceName}'
                          : child.displayName,
                      style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Online · synced 2 min ago" — from the device heartbeat.
class _DeviceStatus extends StatelessWidget {
  const _DeviceStatus({required this.device, required this.loading});
  final DeviceInfo device;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final seen = device.lastSeenAt;
    final age = seen == null ? null : DateTime.now().difference(seen);
    final Color color;
    final String label;
    if (age == null) {
      color = c.textMuted;
      label = 'Not synced yet';
    } else if (age.inMinutes < 20) {
      color = c.safe;
      label = 'Active · synced ${timeAgo(seen!)}';
    } else if (age.inHours < 6) {
      color = c.warn;
      label = 'Last synced ${timeAgo(seen!)}';
    } else {
      color = c.danger;
      label = 'Offline · last seen ${timeAgo(seen!)}';
    }
    return Row(
      children: [
        StatusDot(color: color, pulse: age != null && age.inMinutes < 20),
        const SizedBox(width: 6),
        Expanded(
          child: Text('${device.deviceName} · $label',
              style: TextStyle(color: c.textMuted, fontSize: 13)),
        ),
        AnimatedOpacity(
          opacity: loading ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ],
    );
  }
}

class _SosBanner extends StatelessWidget {
  const _SosBanner({
    required this.name,
    required this.alert,
    required this.count,
    required this.onTap,
  });

  final String name;
  final SosAlert alert;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final at = DateTime.tryParse(alert.at);
    return FgCard(
      onTap: onTap,
      color: c.tint(c.danger),
      borderColor: c.danger,
      child: Row(
        children: [
          IconWell(Icons.sos_rounded, color: c.danger),
          const SizedBox(width: FgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    count > 1
                        ? '$count open SOS alerts from $name'
                        : 'SOS from $name',
                    style: TextStyle(
                        color: c.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text(at == null ? alert.message : '${timeAgo(at)} · tap to respond',
                    style: TextStyle(color: c.danger, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.danger),
        ],
      ),
    );
  }
}

class _ScreenTimeCard extends StatelessWidget {
  const _ScreenTimeCard({required this.report});
  final Map report;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final screen = report['screenTime'] as Map? ?? const {};
    final used = (screen['consumedMinutes'] as num?)?.toInt() ?? 0;
    final limit = (screen['dailyMinutes'] as num?)?.toInt();
    final ratio = limit == null || limit == 0 ? 0.0 : used / limit;
    final ringColor = ratio >= 1
        ? c.danger
        : ratio >= 0.8
            ? c.warn
            : c.accent;
    final apps = (report['usage']?['apps'] as List? ?? const [])
        .map((e) => UsageEntry.fromMap(e as Map))
        .take(3)
        .toList();
    final maxSec = apps.isEmpty ? 1 : apps.first.durationSeconds;

    return FgCard(
      onTap: () => openFeature(context, 'dashboard'),
      child: Row(
        children: [
          StatRing(
            value: ratio,
            color: ringColor,
            size: 112,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatMinutes(used), style: fgNumber(context, 20)),
                Text(limit == null ? 'no limit' : 'of ${formatMinutes(limit)}',
                    style: TextStyle(color: c.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: FgSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Screen time today',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: FgSpace.sm),
                if (apps.isEmpty)
                  Text('No app usage shared yet.',
                      style: TextStyle(color: c.textMuted, fontSize: 13)),
                for (final a in apps) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(_shortName(a.appName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: c.textMuted, fontSize: 13)),
                      ),
                      Text(formatMinutes(a.minutes),
                          style: fgNumber(context, 13,
                              weight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FgBar(value: a.durationSeconds / maxSec),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "com.google.android.youtube" → "Youtube", "com.whatsapp" → "Whatsapp".
  static String _shortName(String pkg) {
    if (!pkg.contains('.')) return pkg;
    final last = pkg.split('.').last;
    if (last.isEmpty) return pkg;
    return last[0].toUpperCase() + last.substring(1);
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.report});
  final Map report;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final loc = LocationPoint.fromServer(report['lastLocation'] as Map?);
    final events = report['recentGeofenceEvents'] as List? ?? const [];
    final last = events.isEmpty ? null : events.last as Map;
    final inside = last != null && last['type'] == 'enter';
    final zoneText = last == null
        ? null
        : inside
            ? 'Inside ${last['zoneName']}'
            : 'Left ${last['zoneName']}';

    return FgCard(
      onTap: () => openFeature(context, 'location'),
      child: Row(
        children: [
          IconWell(Icons.location_on_outlined,
              color: inside ? c.safe : c.accent),
          const SizedBox(width: FgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zoneText ?? 'Location',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  loc == null
                      ? 'Not shared yet'
                      : '${loc.lat.toStringAsFixed(4)}, ${loc.lng.toStringAsFixed(4)} · ${timeAgo(loc.time)}',
                  style: fgNumber(context, 13,
                      weight: FontWeight.w400, color: c.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}

class _RulesSummary extends StatelessWidget {
  const _RulesSummary({required this.report});
  final Map report;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final bedtime = report['bedtime'] as Map?;
    final blocked = (report['blockedApps'] as List? ?? const []).length;
    final limit = (report['screenTime'] as Map?)?['dailyMinutes'];

    Widget chip(IconData icon, String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.tint(color),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(text,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        );

    return Wrap(
      spacing: FgSpace.sm,
      runSpacing: FgSpace.sm,
      children: [
        chip(
          Icons.timelapse_rounded,
          limit == null ? 'No daily limit' : 'Limit ${formatMinutes((limit as num).toInt())}',
          limit == null ? c.textMuted : c.accent,
        ),
        chip(
          Icons.bedtime_outlined,
          bedtime == null
              ? 'No bedtime'
              : bedtime['lockedNow'] == true
                  ? 'Bedtime now'
                  : 'Bedtime ${bedtime['startHour']}:00–${bedtime['endHour']}:00',
          bedtime == null ? c.textMuted : c.accent,
        ),
        chip(Icons.block_rounded,
            blocked == 0
                ? 'No blocked apps'
                : blocked == 1
                    ? '1 blocked app'
                    : '$blocked blocked apps',
            blocked == 0 ? c.textMuted : c.accent),
      ],
    );
  }
}

/// First-run state: no device yet.
class _PairFirst extends StatelessWidget {
  const _PairFirst({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: FgSpace.xl),
      child: FgCard(
        padding: const EdgeInsets.all(FgSpace.xl),
        child: Column(
          children: [
            const IconWell(Icons.phonelink_lock_rounded, size: 64),
            const SizedBox(height: FgSpace.lg),
            Text('Connect your child\'s device',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: FgSpace.sm),
            Text(
              'Add a child, then enter their pairing code in the FamilyGuard '
              'Child app. Their summary shows up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted),
            ),
            const SizedBox(height: FgSpace.lg),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add a child'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: FgSpace.md),
        child: Column(
          children: [
            Skeleton(height: 144, radius: FgSpace.radius),
            SizedBox(height: FgSpace.md),
            Skeleton(height: 72, radius: FgSpace.radius),
            SizedBox(height: FgSpace.md),
            Skeleton(height: 92, radius: FgSpace.radius),
          ],
        ),
      );
}
