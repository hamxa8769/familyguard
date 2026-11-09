import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';
import '../../theme/app_theme.dart';
import '../../ui/fg_widgets.dart';

class DashboardModule implements FeatureModule {
  @override
  String get id => 'dashboard';
  @override
  FeatureSection get section => FeatureSection.activity;
  @override
  String get title => 'App usage';
  @override
  String get description => 'This week and today, per app';
  @override
  IconData get icon => Icons.bar_chart_rounded;
  @override
  Widget buildScreen(BuildContext context) => const DashboardScreen();
}

class _UsageData {
  _UsageData(this.days, this.today, this.limitMinutes);
  final List<(DateTime, int)> days; // (day, seconds), oldest first
  final List<UsageEntry> today;
  final int? limitMinutes;
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<_UsageData> _load(String deviceId) async {
    final api = ParentState.instance.api;
    final results = await Future.wait([
      api.get('/api/usage/$deviceId/daily?days=7'),
      api.get('/api/reports/$deviceId'),
    ]);
    final days = [
      for (final d in results[0]['days'] as List)
        (
          DateTime.parse('${d['date']}').toLocal(),
          (d['totalSeconds'] as num).toInt(),
        ),
    ];
    final report = results[1] as Map;
    final today = (report['usage']?['apps'] as List? ?? const [])
        .map((e) => UsageEntry.fromMap(e as Map))
        .toList();
    final limit = (report['screenTime']?['dailyMinutes'] as num?)?.toInt();
    return _UsageData(days, today, limit);
  }

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'App usage',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(
            title: Text(ParentState.instance.labelFor(deviceId))),
        body: ApiView<_UsageData>(
          load: () => _load(deviceId),
          builder: (context, data, _) => _UsageView(data: data),
        ),
      ),
    );
  }
}

class _UsageView extends StatelessWidget {
  const _UsageView({required this.data});
  final _UsageData data;

  static String appLabel(String pkg) {
    if (!pkg.contains('.')) return pkg;
    final last = pkg.split('.').last;
    return last.isEmpty ? pkg : last[0].toUpperCase() + last.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final weekTotal = data.days.fold<int>(0, (s, d) => s + d.$2);
    final activeDays = data.days.where((d) => d.$2 > 0).length;
    final avgMin = activeDays == 0 ? 0 : weekTotal ~/ 60 ~/ activeDays;
    final todayMin = data.days.isEmpty ? 0 : data.days.last.$2 ~/ 60;
    final maxSec =
        data.today.isEmpty ? 1 : data.today.first.durationSeconds;

    return ListView(
      padding: const EdgeInsets.all(FgSpace.lg),
      children: [
        Row(
          children: [
            Expanded(
                child: _Stat(label: 'Today', value: formatMinutes(todayMin))),
            const SizedBox(width: FgSpace.sm),
            Expanded(
                child: _Stat(label: 'Avg / day', value: formatMinutes(avgMin))),
            const SizedBox(width: FgSpace.sm),
            Expanded(
                child: _Stat(
                    label: 'Limit',
                    value: data.limitMinutes == null
                        ? 'None'
                        : formatMinutes(data.limitMinutes!))),
          ],
        ),
        const SectionLabel('Last 7 days'),
        FgCard(
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
          child: SizedBox(
            height: 200,
            child: _WeekChart(days: data.days, limitMinutes: data.limitMinutes),
          ),
        ),
        const SectionLabel('Today by app'),
        if (data.today.isEmpty)
          FgCard(
            child: Text('No app usage shared today yet.',
                style: TextStyle(color: c.textMuted)),
          )
        else
          FgCard(
            padding: const EdgeInsets.symmetric(vertical: FgSpace.sm),
            child: Column(
              children: [
                for (final a in data.today.take(30))
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: FgSpace.lg, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(appLabel(a.appName),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(a.appName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 11, color: c.textMuted)),
                                ],
                              ),
                            ),
                            Text(formatMinutes(a.minutes),
                                style: fgNumber(context, 14)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FgBar(value: a.durationSeconds / maxSec),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return FgCard(
      padding: const EdgeInsets.all(FgSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: fgNumber(context, 18)),
          ),
        ],
      ),
    );
  }
}

/// Minutes per day; bars over the limit are red, today is accent.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days, required this.limitMinutes});
  final List<(DateTime, int)> days;
  final int? limitMinutes;

  static const _weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final mins = [for (final d in days) d.$2 / 60];
    final top = [
      ...mins,
      if (limitMinutes != null) limitMinutes!.toDouble(),
      30.0,
    ].reduce((a, b) => a > b ? a : b);
    // Whole-hour gridlines: 1h steps up to 4h, then 2h steps.
    final maxY = (top * 1.15 / 60).ceil() * 60.0;
    final step = maxY <= 240 ? 60.0 : 120.0;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.border, strokeWidth: 1),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (limitMinutes != null)
            HorizontalLine(
              y: limitMinutes!.toDouble(),
              color: c.warn,
              strokeWidth: 1.5,
              dashArray: [6, 4],
            ),
        ]),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: step,
              getTitlesWidget: (v, meta) => Text(
                v == 0 ? '0' : '${(v / 60).round()}h',
                style: TextStyle(color: c.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                final isToday = i == days.length - 1;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    isToday ? 'Today' : _weekday[days[i].$1.weekday - 1],
                    style: TextStyle(
                      color: isToday ? c.text : c.textMuted,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => c.surfaceHigh,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              formatMinutes(rod.toY.round()),
              TextStyle(color: c.text, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < mins.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: mins[i],
                width: 18,
                borderRadius: BorderRadius.circular(6),
                color: limitMinutes != null && mins[i] > limitMinutes!
                    ? c.danger
                    : i == mins.length - 1
                        ? c.accent
                        : c.accent.withValues(alpha: 0.45),
              ),
            ]),
        ],
      ),
      duration: const Duration(milliseconds: 400),
    );
  }
}
