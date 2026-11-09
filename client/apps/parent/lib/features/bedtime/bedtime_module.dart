import 'package:flutter/material.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';
import '../../theme/app_theme.dart';
import '../../ui/fg_widgets.dart';

class BedtimeModule implements FeatureModule {
  @override
  String get id => 'bedtime';
  @override
  FeatureSection get section => FeatureSection.rules;
  @override
  String get title => 'Bedtime';
  @override
  String get description => 'Nightly downtime window';
  @override
  IconData get icon => Icons.bedtime_outlined;
  @override
  Widget buildScreen(BuildContext context) => const BedtimeScreen();
}

class BedtimeScreen extends StatelessWidget {
  const BedtimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Bedtime',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Bedtime')),
        body: ApiView<Map>(
          load: () async =>
              await ParentState.instance.api.get('/api/bedtime/$deviceId')
                  as Map,
          builder: (context, data, reload) =>
              _Schedule(deviceId: deviceId, data: data, onSaved: reload),
        ),
      ),
    );
  }
}

class _Schedule extends StatefulWidget {
  const _Schedule(
      {required this.deviceId, required this.data, required this.onSaved});
  final String deviceId;
  final Map data;
  final VoidCallback onSaved;

  @override
  State<_Schedule> createState() => _ScheduleState();
}

class _ScheduleState extends State<_Schedule> {
  // The server stores whole hours.
  late int _start = (widget.data['schedule']?['startHour'] as int?) ?? 22;
  late int _end = (widget.data['schedule']?['endHour'] as int?) ?? 6;
  bool _saving = false;

  int get _hours => (_end - _start) % 24 == 0 ? 0 : (_end - _start) % 24;

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: isStart ? _start : _end, minute: 0),
      helpText: isStart ? 'Bedtime starts (whole hours)' : 'Wake up (whole hours)',
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked.hour : _end = picked.hour);
    }
  }

  String _label(int hour) => TimeOfDay(hour: hour, minute: 0).format(context);

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await saveWithFeedback(
      context,
      () => ParentState.instance.api.put('/api/bedtime/${widget.deviceId}',
          {'startHour': _start, 'endHour': _end}),
      'Bedtime saved: ${_label(_start)} – ${_label(_end)}',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final saved = widget.data['schedule'] != null;
    final lockedNow = widget.data['lockedNow'] == true;

    Widget timeTile(String label, int hour, IconData icon, bool isStart) =>
        Expanded(
          child: FgCard(
            onTap: () => _pick(isStart),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: c.accent),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(color: c.textMuted)),
                  ],
                ),
                const SizedBox(height: FgSpace.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(_label(hour), style: fgNumber(context, 24)),
                ),
                Text('Tap to change',
                    style: TextStyle(color: c.textMuted, fontSize: 11)),
              ],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(FgSpace.lg),
      children: [
        FgCard(
          color: lockedNow ? c.tint(c.accent) : null,
          borderColor: lockedNow ? c.accent : null,
          child: Row(
            children: [
              IconWell(lockedNow ? Icons.nights_stay_rounded : Icons.wb_twilight,
                  size: 48),
              const SizedBox(width: FgSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !saved
                          ? 'No bedtime set'
                          : lockedNow
                              ? 'Bedtime is on right now'
                              : 'Bedtime is off right now',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    Text('$_hours hours of downtime each night',
                        style: TextStyle(color: c.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('Schedule'),
        IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            timeTile('Starts', _start, Icons.nightlight_outlined, true),
            const SizedBox(width: FgSpace.sm),
            timeTile('Ends', _end, Icons.wb_sunny_outlined, false),
          ],
          ),
        ),
        const SizedBox(height: FgSpace.xl),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save schedule'),
        ),
        const SizedBox(height: FgSpace.md),
        Text(
          'The schedule is shown on your child\'s device. Locking the device '
          'during bedtime is coming in a later update.',
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}
