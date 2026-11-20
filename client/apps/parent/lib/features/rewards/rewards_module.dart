import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../feature_module.dart';

/// Parent side of the reward system: award points (optionally with a
/// badge) and see the child's total, badges and history. Points are never
/// taken away from this screen, and the automatic screen-time bonus is
/// idempotent — the same day can never be awarded twice.
class RewardsModule implements FeatureModule {
  @override
  String get id => 'rewards';
  @override
  String get title => 'Rewards';
  @override
  String get description => 'Points and badges for healthy habits';
  @override
  IconData get icon => Icons.emoji_events;
  @override
  FeatureSection get section => FeatureSection.family;
  @override
  Widget buildScreen(BuildContext context) => const RewardsScreen();
}

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final _api = ApiClient();
  final _childId = TextEditingController();
  final _points = TextEditingController();
  final _reason = TextEditingController();
  final _badge = TextEditingController();
  RewardSummary? _summary;
  String? _status;

  Future<void> _load() async {
    if (_childId.text.isEmpty) {
      setState(() => _status = 'Enter a child ID first.');
      return;
    }
    try {
      final data = await _api.get('/api/rewards/${_childId.text}');
      setState(() {
        _summary = RewardSummary.fromMap(data as Map);
        _status = null;
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Could not load rewards: ${e.message}');
    }
  }

  Future<void> _award() async {
    if (_childId.text.isEmpty) {
      setState(() => _status = 'Enter a child ID first.');
      return;
    }
    final points = int.tryParse(_points.text);
    if (points == null || points <= 0 || _reason.text.isEmpty) {
      setState(() => _status = 'Enter points (a positive number) and a reason.');
      return;
    }
    try {
      await _api.post('/api/rewards/${_childId.text}/award', {
        'points': points,
        'reason': _reason.text,
        if (_badge.text.isNotEmpty) 'badge': _badge.text,
      });
      _points.clear();
      _reason.clear();
      _badge.clear();
      setState(() => _status = 'Points awarded.');
      await _load();
    } on ApiException catch (e) {
      setState(() => _status = 'Could not award points: ${e.message}');
    }
  }

  @override
  void dispose() {
    _childId.dispose();
    _points.dispose();
    _reason.dispose();
    _badge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _childId,
            decoration: const InputDecoration(labelText: 'Child ID'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _load, child: const Text('Load rewards')),
          const SizedBox(height: 16),
          Text('Award points', style: Theme.of(context).textTheme.titleMedium),
          TextField(
            controller: _points,
            decoration: const InputDecoration(labelText: 'Points'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          TextField(
            controller: _badge,
            decoration: const InputDecoration(labelText: 'Badge (optional)'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _award, child: const Text('Award points')),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!),
          ],
          const SizedBox(height: 16),
          if (_summary != null) ...[
            Text(
              '${_summary!.totalPoints} points',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final badge in _summary!.badges)
                  Chip(
                    label: Text(badge),
                    avatar: const Icon(Icons.emoji_events),
                  ),
              ],
            ),
            for (final event in _summary!.events)
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: Text(event.reason),
                subtitle: Text(event.at ?? ''),
                trailing: Text('+${event.points}'),
              ),
            if (_summary!.events.isEmpty)
              const ListTile(title: Text('No rewards yet.')),
          ],
        ],
      ),
    );
  }
}
