import 'package:flutter/material.dart';
import '../../common/enforcement_note.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';
import '../../theme/app_theme.dart';
import '../../ui/fg_widgets.dart';

class ScreenTimeModule implements FeatureModule {
  @override
  String get id => 'screen_time';
  @override
  FeatureSection get section => FeatureSection.rules;
  @override
  String get title => 'Screen time';
  @override
  String get description => 'Daily usage limit';
  @override
  IconData get icon => Icons.timelapse_rounded;
  @override
  Widget buildScreen(BuildContext context) => const ScreenTimeScreen();
}

class ScreenTimeScreen extends StatelessWidget {
  const ScreenTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Screen time',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Screen time')),
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
  static const _presets = [60, 90, 120, 180, 240];

  late double _limit =
      ((widget.data['dailyMinutes'] as num?)?.toDouble() ?? 120)
          .clamp(30, 480)
          .toDouble();
  int get _consumed => (widget.data['consumedMinutes'] as num?)?.toInt() ?? 0;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await saveWithFeedback(
      context,
      () => ParentState.instance.api.put(
          '/api/screentime/${widget.deviceId}',
          {'dailyMinutes': _limit.round()}),
      'Limit saved: ${formatMinutes(_limit.round())} a day',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final limit = _limit.round();
    final ratio = _consumed / limit;
    final remaining = (limit - _consumed).clamp(0, limit);
    final color = ratio >= 1
        ? c.danger
        : ratio >= 0.8
            ? c.warn
            : c.accent;
    final saved = (widget.data['dailyMinutes'] as num?)?.toInt();

    return ListView(
      padding: const EdgeInsets.all(FgSpace.lg),
      children: [
        FgCard(
          padding: const EdgeInsets.all(FgSpace.xl),
          child: Column(
            children: [
              StatRing(
                value: ratio,
                color: color,
                size: 180,
                stroke: 14,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatMinutes(remaining), style: fgNumber(context, 30)),
                    Text('left today',
                        style: TextStyle(color: c.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: FgSpace.lg),
              Text('Used ${formatMinutes(_consumed)} of ${formatMinutes(limit)}',
                  style: TextStyle(color: c.textMuted)),
            ],
          ),
        ),
        const SectionLabel('Daily limit'),
        FgCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(formatMinutes(limit), style: fgNumber(context, 26)),
                  const SizedBox(width: FgSpace.sm),
                  Text('per day', style: TextStyle(color: c.textMuted)),
                  const Spacer(),
                  if (saved != null && saved != limit)
                    Text('unsaved',
                        style: TextStyle(color: c.warn, fontSize: 12)),
                ],
              ),
              Slider(
                value: _limit,
                min: 30,
                max: 480,
                divisions: 30,
                label: formatMinutes(limit),
                onChanged: (v) => setState(() => _limit = v),
              ),
              Wrap(
                spacing: FgSpace.sm,
                runSpacing: FgSpace.sm,
                children: [
                  for (final p in _presets)
                    ChoiceChip(
                      label: Text(formatMinutes(p)),
                      selected: limit == p,
                      onSelected: (_) =>
                          setState(() => _limit = p.toDouble()),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: FgSpace.lg),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save limit'),
        ),
        const SizedBox(height: FgSpace.md),
        const EnforcementNote(),
        const SizedBox(height: FgSpace.sm),
        Text(
          'When the time is used up, apps are paused until tomorrow. Your '
          'child can ask for more time; calls always work.',
          style: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ],
    );
  }
}
