import 'package:flutter/material.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

class ScreenTimeModule implements FeatureModule {
  @override
  String get id => 'screen_time';
  @override
  FeatureSection get section => FeatureSection.rules;
  @override
  String get title => 'Screen Time';
  @override
  String get description => 'Set a daily usage limit';
  @override
  IconData get icon => Icons.timelapse;
  @override
  Widget buildScreen(BuildContext context) => const ScreenTimeScreen();
}

class ScreenTimeScreen extends StatelessWidget {
  const ScreenTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Screen Time',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Screen Time')),
        body: ApiView<Map>(
          load: () async => await ParentState.instance.api
              .get('/api/screentime/$deviceId') as Map,
          builder: (context, data, reload) =>
              _LimitEditor(deviceId: deviceId, data: data, onSaved: reload),
        ),
      ),
    );
  }
}

class _LimitEditor extends StatefulWidget {
  const _LimitEditor(
      {required this.deviceId, required this.data, required this.onSaved});
  final String deviceId;
  final Map data;
  final VoidCallback onSaved;

  @override
  State<_LimitEditor> createState() => _LimitEditorState();
}

class _LimitEditorState extends State<_LimitEditor> {
  late double _limit =
      ((widget.data['dailyMinutes'] as num?)?.toDouble() ?? 120)
          .clamp(30, 480)
          .toDouble();
  late final int _consumed =
      (widget.data['consumedMinutes'] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final hasLimit = widget.data['dailyMinutes'] != null;
    final remaining = (_limit - _consumed).clamp(0, _limit).round();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Daily limit: ${formatMinutes(_limit.round())}',
            style: Theme.of(context).textTheme.titleLarge),
        if (!hasLimit) const Text('No limit saved yet.'),
        Slider(
          value: _limit,
          min: 30,
          max: 480,
          divisions: 15,
          label: formatMinutes(_limit.round()),
          onChanged: (v) => setState(() => _limit = v),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: (_consumed / _limit).clamp(0, 1)),
        const SizedBox(height: 8),
        Text('Used today: ${formatMinutes(_consumed)}  •  '
            'Remaining: ${formatMinutes(remaining)}'),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () async {
            final ok = await saveWithFeedback(
              context,
              () => ParentState.instance.api.put(
                  '/api/screentime/${widget.deviceId}',
                  {'dailyMinutes': _limit.round()}),
              'Limit saved: ${formatMinutes(_limit.round())}',
            );
            if (ok) widget.onSaved();
          },
          child: const Text('Save limit'),
        ),
        const SizedBox(height: 12),
        const Text(
          'The limit is shown on the child\'s device. Locking the device when '
          'it is reached is not enforced yet.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
