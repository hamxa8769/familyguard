import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:familyguard_core/ui.dart';
import '../build_flavor.dart';
import '../features/call_log/call_log_screen.dart';
import '../features/gallery/gallery_screen.dart';
import '../features/location/location_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/sos/sos_screen.dart';
import '../features/transparency/transparency_screen.dart';
import '../features/usage/usage_screen.dart';
import '../permissions/permissions.dart';
import '../permissions/permissions_screen.dart';
import '../sync/background_sync.dart';
import '../sync/sync_service.dart';
import 'more_time_sheet.dart';

String _mins(int m) {
  final h = m ~/ 60;
  final r = m % 60;
  return h > 0 ? '${h}h ${r}m' : '${r}m';
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// What the child sees every day: time left, bedtime, a big SOS button,
/// "ask for more time", and a clear view of what is shared.
class ChildHome extends StatefulWidget {
  const ChildHome({super.key});

  @override
  State<ChildHome> createState() => _ChildHomeState();
}

class _ChildHomeState extends State<ChildHome> with WidgetsBindingObserver {
  final _sync = SyncService.instance;
  final _api = AuthService.instance.api;
  Map? _screen;
  Map? _bedtime;
  Map? _request; // latest more-time request
  int _permOn = 0;
  int _permTotal = 0;
  Timer? _poll;

  String get _deviceId => AuthService.instance.deviceId!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync.start();
    // Keep sharing while the app is closed (Android WorkManager).
    BackgroundSync.enable().catchError((_) {});
    _sync.status.addListener(_onSynced);
    _load();
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sync.status.removeListener(_onSynced);
    _poll?.cancel();
    _sync.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sync.syncNow();
      _load();
    }
  }

  // After each sync the server knows the new usage → refresh the numbers.
  void _onSynced() {
    if (!_sync.status.value.running) _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        _api.get('/api/screentime/$_deviceId'),
        _api.get('/api/bedtime/$_deviceId'),
        _api.get('/api/requests'),
      ]);
      final requests = r[2]['requests'] as List;
      _screen = r[0] as Map;
      _bedtime = r[1] as Map;
      _request = requests.isEmpty ? null : requests.first as Map;
    } on ApiException {
      // Keep showing the last values; the sync banner shows connection errors.
    }
    final items = permissionItems();
    var on = 0;
    for (final p in items) {
      if (await p.check()) on++;
    }
    _permOn = on;
    _permTotal = items.length;
    if (mounted) setState(() {});
  }

  void _open(Widget screen) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => screen))
      .then((_) => _load());

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final name = AuthService.instance.childName;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _sync.syncNow();
            await _load();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                FgSpace.lg, FgSpace.md, FgSpace.lg, FgSpace.xl),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name == null ? 'Hi there' : 'Hi $name',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  IconButton(
                    tooltip: 'Share now',
                    icon: const Icon(Icons.sync_rounded),
                    onPressed: _sync.syncNow,
                  ),
                ],
              ),
              ValueListenableBuilder<SyncStatus>(
                valueListenable: _sync.status,
                builder: (context, s, _) => _SyncLine(status: s),
              ),
              const SizedBox(height: FgSpace.lg),
              _TimeCard(
                screen: _screen,
                bedtime: _bedtime,
                request: _request,
                onAsk: () async {
                  final sent = await showMoreTimeSheet(context);
                  if (sent) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Request sent to your parent')));
                    }
                    _load();
                  }
                },
              ),
              const SizedBox(height: FgSpace.xl),
              const Center(child: SosButton()),
              const SizedBox(height: FgSpace.sm),
              Center(
                child: Text('In danger? Hold SOS to alert your parent',
                    style: TextStyle(color: c.textMuted, fontSize: 13)),
              ),
              const SectionLabel('You are in control'),
              FeatureTile(
                icon: Icons.visibility_outlined,
                color: c.safe,
                title: 'What my parent sees',
                subtitle: 'The exact report your parent gets',
                onTap: () => _open(const TransparencyScreen()),
              ),
              const SizedBox(height: FgSpace.sm),
              if (_permTotal > 0) ...[
                FeatureTile(
                  icon: Icons.key_outlined,
                  color: _permOn == _permTotal ? c.safe : c.warn,
                  title: 'Permissions',
                  subtitle: '$_permOn of $_permTotal allowed',
                  onTap: () => _open(const PermissionsScreen()),
                ),
                const SizedBox(height: FgSpace.sm),
              ],
              const SectionLabel('What is shared'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: FgSpace.sm,
                crossAxisSpacing: FgSpace.sm,
                childAspectRatio: 0.95,
                children: [
                  QuickAction(
                      icon: Icons.bar_chart_rounded,
                      label: 'App usage',
                      onTap: () => _open(const UsageScreen())),
                  QuickAction(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      onTap: () => _open(const LocationScreen())),
                  if (!kLiteBuild)
                    QuickAction(
                        icon: Icons.sms_outlined,
                        label: 'Messages',
                        onTap: () => _open(const MessagesScreen())),
                  if (!kLiteBuild)
                    QuickAction(
                        icon: Icons.call_outlined,
                        label: 'Calls',
                        onTap: () => _open(const CallLogScreen())),
                  QuickAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Photos',
                      onTap: () => _open(const GalleryScreen())),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Monitoring is on · shared 2 min ago" — always visible, never hidden.
class _SyncLine extends StatelessWidget {
  const _SyncLine({required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final String text;
    final Color color;
    if (status.running) {
      text = 'Monitoring is on · sharing now…';
      color = c.accent;
    } else if (status.error != null) {
      text = 'Monitoring is on · couldn\'t share: ${status.error}';
      color = c.danger;
    } else if (status.at == null) {
      text = 'Monitoring is on · not shared yet';
      color = c.textMuted;
    } else {
      text = 'Monitoring is on · shared ${_ago(status.at!)}'
          '${BackgroundSync.supported ? ' · every 15 min in background' : ''}';
      color = c.safe;
    }
    return Row(
      children: [
        StatusDot(color: color, pulse: status.running),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.textMuted, fontSize: 13)),
        ),
      ],
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.screen,
    required this.bedtime,
    required this.request,
    required this.onAsk,
  });

  final Map? screen;
  final Map? bedtime;
  final Map? request;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    if (screen == null) {
      return const Skeleton(height: 160, radius: FgSpace.radius);
    }
    final limit = (screen!['dailyMinutes'] as num?)?.toInt();
    final used = (screen!['consumedMinutes'] as num?)?.toInt() ?? 0;
    final bonus = (screen!['bonusMinutes'] as num?)?.toInt() ?? 0;
    final left = limit == null ? null : (limit - used).clamp(0, limit);
    final ratio = limit == null || limit == 0 ? 0.0 : used / limit;
    final color = ratio >= 1
        ? c.danger
        : ratio >= 0.8
            ? c.warn
            : c.accent;

    final sched = bedtime?['schedule'] as Map?;
    final bedNow = bedtime?['lockedNow'] == true;
    final bedText = sched == null
        ? null
        : bedNow
            ? 'It\'s bedtime now'
            : 'Bedtime at ${TimeOfDay(hour: sched['startHour'] as int, minute: 0).format(context)}';

    final status = request?['status'];
    final pending = status == 'pending';
    final decidedToday = request?['decidedAt'] != null &&
        DateTime.now()
                .difference(DateTime.parse('${request!['decidedAt']}'))
                .inHours <
            12;

    return FgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StatRing(
                value: ratio,
                color: color,
                size: 108,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(left == null ? _mins(used) : _mins(left),
                        style: fgNumber(context, 20)),
                    Text(left == null ? 'used' : 'left',
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
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      limit == null
                          ? 'No daily limit'
                          : 'Used ${_mins(used)} of ${_mins(limit)}',
                      style: TextStyle(color: c.textMuted, fontSize: 13),
                    ),
                    if (bonus > 0)
                      Text('+${_mins(bonus)} extra today',
                          style: TextStyle(color: c.safe, fontSize: 13)),
                    if (bedText != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.bedtime_outlined,
                              size: 16, color: bedNow ? c.accent : c.textMuted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(bedText,
                                style: TextStyle(
                                    color: bedNow ? c.accent : c.textMuted,
                                    fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (limit != null) ...[
            const SizedBox(height: FgSpace.md),
            if (pending)
              _RequestNote(
                icon: Icons.hourglass_top_rounded,
                color: c.warn,
                text:
                    'Asked for +${request!['minutes']} min — waiting for your parent',
              )
            else ...[
              if (decidedToday)
                Padding(
                  padding: const EdgeInsets.only(bottom: FgSpace.sm),
                  child: _RequestNote(
                    icon: status == 'approved'
                        ? Icons.check_circle_outline_rounded
                        : Icons.do_not_disturb_on_outlined,
                    color: status == 'approved' ? c.safe : c.textMuted,
                    text: status == 'approved'
                        ? 'Your parent said yes to +${request!['minutes']} min'
                        : 'Your parent said no to +${request!['minutes']} min',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: onAsk,
                icon: const Icon(Icons.more_time_rounded),
                label: const Text('Ask for more time'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RequestNote extends StatelessWidget {
  const _RequestNote(
      {required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return Container(
      padding: const EdgeInsets.all(FgSpace.md),
      decoration: BoxDecoration(
        color: c.tint(color),
        borderRadius: BorderRadius.circular(FgSpace.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: FgSpace.sm),
          Expanded(
              child: Text(text, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}
