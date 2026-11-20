import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../shell/settings_screen.dart';
import '../../state/parent_state.dart';
import '../../theme/app_theme.dart';
import '../../ui/fg_widgets.dart';

class AlertsModule implements FeatureModule {
  @override
  String get id => 'alerts';
  @override
  FeatureSection get section => FeatureSection.alerts;
  @override
  String get title => 'Alerts';
  @override
  String get description => 'SOS and safe-zone alerts';
  @override
  IconData get icon => Icons.notifications_active;
  @override
  Widget buildScreen(BuildContext context) => const AlertsScreen();
}

enum _Kind { sos, zone, request }

class _Alert {
  _Alert({
    required this.kind,
    required this.at,
    required this.title,
    required this.subtitle,
    this.sos,
    this.request,
  });
  final _Kind kind;
  final DateTime at;
  final String title;
  final String subtitle;
  final SosAlert? sos;

  /// "More time" request from a child ({id, minutes, reason, status}).
  final Map? request;

  bool get open =>
      (sos != null && !sos!.resolved) || request?['status'] == 'pending';
}

/// SOS alerts from all children + safe-zone events from every device,
/// filterable and grouped by day. Pull to refresh (push comes later).
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  _Kind? _filter;

  Future<List<_Alert>> _load() async {
    final state = ParentState.instance;
    final api = state.api;
    final out = <_Alert>[];

    final sos = await api.get('/api/sos');
    for (final a
        in (sos['alerts'] as List).map((e) => SosAlert.fromMap(e as Map))) {
      out.add(_Alert(
        kind: _Kind.sos,
        at: (DateTime.tryParse(a.at) ?? DateTime(2000)).toLocal(),
        title: a.message,
        subtitle: state.labelFor(a.deviceId),
        sos: a,
      ));
    }
    final reqs = await api.get('/api/requests');
    for (final r in (reqs['requests'] as List).cast<Map>()) {
      final reason = '${r['reason'] ?? ''}'.trim();
      out.add(_Alert(
        kind: _Kind.request,
        at: (DateTime.tryParse('${r['at']}') ?? DateTime(2000)).toLocal(),
        title: '${state.labelFor('${r['deviceId']}').split(' (').first} asks for +${r['minutes']} min',
        subtitle: reason.isEmpty ? 'More screen time' : '"$reason"',
        request: r,
      ));
    }
    final devices = state.devices;
    final events = await Future.wait([
      for (final (_, d) in devices) api.get('/api/geofencing/${d.id}/events'),
    ]);
    for (var i = 0; i < devices.length; i++) {
      final child = devices[i].$1;
      for (final e in events[i]['events'] as List) {
        final arrived = e['type'] == 'enter';
        out.add(_Alert(
          kind: _Kind.zone,
          at: (DateTime.tryParse('${e['at']}') ?? DateTime(2000)).toLocal(),
          title:
              '${child.displayName} ${arrived ? 'arrived at' : 'left'} ${e['zoneName']}',
          subtitle: 'Safe zone',
        ));
      }
    }
    out.sort((a, b) => b.at.compareTo(a.at));
    return out;
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${day.day}/${day.month}/${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: const [SettingsButton()],
      ),
      body: ApiView<List<_Alert>>(
        load: _load,
        builder: (context, all, reload) {
          final c = FgColors.of(context);
          final alerts = _filter == null
              ? all
              : all.where((a) => a.kind == _filter).toList();
          final openCount =
              all.where((a) => a.kind == _Kind.sos && a.open).length;
          final pendingReq =
              all.where((a) => a.kind == _Kind.request && a.open).length;

          final rows = <Widget>[
            Wrap(
              spacing: FgSpace.sm,
              runSpacing: FgSpace.sm,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                _FilterChip(
                  label: openCount > 0 ? 'SOS · $openCount open' : 'SOS',
                  selected: _filter == _Kind.sos,
                  color: c.danger,
                  onTap: () => setState(() => _filter = _Kind.sos),
                ),
                _FilterChip(
                  label: pendingReq > 0 ? 'Requests · $pendingReq' : 'Requests',
                  selected: _filter == _Kind.request,
                  color: c.warn,
                  onTap: () => setState(() => _filter = _Kind.request),
                ),
                _FilterChip(
                  label: 'Safe zones',
                  selected: _filter == _Kind.zone,
                  color: c.safe,
                  onTap: () => setState(() => _filter = _Kind.zone),
                ),
              ],
            ),
          ];

          if (alerts.isEmpty) {
            rows.add(Padding(
              padding: const EdgeInsets.only(top: FgSpace.xl),
              child: Column(
                children: [
                  IconWell(Icons.notifications_off_outlined,
                      color: c.textMuted, size: 56),
                  const SizedBox(height: FgSpace.md),
                  Text('All quiet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('SOS and safe-zone alerts show up here.',
                      style: TextStyle(color: c.textMuted)),
                ],
              ),
            ));
          }

          String? lastDay;
          for (final a in alerts) {
            final day = _dayLabel(a.at);
            if (day != lastDay) {
              rows.add(SectionLabel(day));
              lastDay = day;
            }
            rows.add(Padding(
              padding: const EdgeInsets.only(bottom: FgSpace.sm),
              child: _AlertCard(alert: a, onResolved: reload),
            ));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
                FgSpace.lg, FgSpace.sm, FgSpace.lg, FgSpace.xl),
            children: rows,
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final col = color ?? c.accent;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.tint(col) : c.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? col : c.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? col : c.text,
            )),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onResolved});
  final _Alert alert;
  final VoidCallback onResolved;

  Future<void> _decide(BuildContext context, bool approve) async {
    final minutes = alert.request!['minutes'];
    final ok = await saveWithFeedback(
      context,
      () => ParentState.instance.api.post(
          '/api/requests/${alert.request!['id']}/decide', {'approve': approve}),
      approve ? '+$minutes min approved for today' : 'Request denied',
    );
    if (ok) onResolved();
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final isSos = alert.kind == _Kind.sos;
    final isReq = alert.kind == _Kind.request;
    final color = isSos
        ? (alert.open ? c.danger : c.textMuted)
        : isReq
            ? (alert.open ? c.warn : c.textMuted)
            : c.safe;
    final urgent = isSos && alert.open;
    final t = TimeOfDay.fromDateTime(alert.at).format(context);

    return FgCard(
      padding: const EdgeInsets.all(FgSpace.md),
      color: urgent ? c.tint(c.danger) : null,
      borderColor: urgent
          ? c.danger
          : (isReq && alert.open)
              ? c.warn
              : null,
      child: Row(
        children: [
          IconWell(
              isSos
                  ? Icons.sos_rounded
                  : isReq
                      ? Icons.more_time_rounded
                      : Icons.shield_moon_outlined,
              color: color),
          const SizedBox(width: FgSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: urgent ? c.danger : c.text)),
                const SizedBox(height: 2),
                Text('$t · ${alert.subtitle}',
                    style: TextStyle(color: c.textMuted, fontSize: 12)),
                if (isReq && !alert.open)
                  Text(
                      alert.request!['status'] == 'approved'
                          ? 'Approved'
                          : 'Denied',
                      style: TextStyle(
                          color: alert.request!['status'] == 'approved'
                              ? c.safe
                              : c.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                if (isReq && alert.open) ...[
                  const SizedBox(height: FgSpace.sm),
                  Row(
                    children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.safe,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _decide(context, true),
                        child: const Text('Approve'),
                      ),
                      const SizedBox(width: FgSpace.sm),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact),
                        onPressed: () => _decide(context, false),
                        child: const Text('Deny'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isSos)
            alert.open
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: c.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final ok = await saveWithFeedback(
                        context,
                        () => ParentState.instance.api
                            .post('/api/sos/${alert.sos!.id}/resolve', {}),
                        'Marked as handled',
                      );
                      if (ok) onResolved();
                    },
                    child: const Text('Resolve'),
                  )
                : Icon(Icons.check_circle_outline_rounded, color: c.safe),
        ],
      ),
    );
  }
}
