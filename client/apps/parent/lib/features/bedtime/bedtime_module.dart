import 'package:flutter/material.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

class BedtimeModule implements FeatureModule {
  @override
  String get id => 'bedtime';
  @override
  String get title => 'Bedtime';
  @override
  String get description => 'Lock the device at night';
  @override
  IconData get icon => Icons.bedtime;
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

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: isStart ? _start : _end, minute: 0),
      helpText: 'Whole hours only',
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked.hour : _end = picked.hour);
    }
  }

  String _label(int hour) =>
      TimeOfDay(hour: hour, minute: 0).format(context);

  @override
  Widget build(BuildContext context) {
    final saved = widget.data['schedule'] != null;
    final lockedNow = widget.data['lockedNow'] == true;
    return ListView(
      children: [
        if (saved)
          ListTile(
            leading: Icon(lockedNow ? Icons.lock : Icons.lock_open),
            title: Text(lockedNow
                ? 'Bedtime is active now'
                : 'Bedtime is not active now'),
          )
        else
          const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No bedtime saved yet')),
        ListTile(
          leading: const Icon(Icons.nightlight),
          title: const Text('Lock from'),
          trailing: Text(_label(_start)),
          onTap: () => _pick(true),
        ),
        ListTile(
          leading: const Icon(Icons.wb_sunny),
          title: const Text('Unlock at'),
          trailing: Text(_label(_end)),
          onTap: () => _pick(false),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () async {
              final ok = await saveWithFeedback(
                context,
                () => ParentState.instance.api.put(
                    '/api/bedtime/${widget.deviceId}',
                    {'startHour': _start, 'endHour': _end}),
                'Bedtime saved: ${_label(_start)} – ${_label(_end)}',
              );
              if (ok) widget.onSaved();
            },
            child: const Text('Save schedule'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'The schedule is saved and shown to the child. Locking the device '
            'itself is not enforced yet.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
