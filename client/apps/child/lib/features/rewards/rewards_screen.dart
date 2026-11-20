import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Child side of the reward system: points and badges for healthy habits
/// (for example staying inside the screen-time limit). Read-only — points
/// are awarded by the parent or by the automatic screen-time rule.
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key, required this.childId});

  /// Until child accounts land, the registered deviceId is used as the
  /// child id (same stand-in as the other child screens).
  final String childId;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  ApiClient get _api => AuthService.instance.api;
  RewardSummary? _summary;
  String? _status;
  bool _loading = true;

  Future<void> _load() async {
    if (widget.childId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await _api.get('/api/rewards/${widget.childId}');
      setState(() {
        _summary = RewardSummary.fromMap(data as Map);
        _status = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _status = 'Could not load rewards: ${e.message}';
        _loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rewards')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.childId.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('This device is not registered yet.'),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_status != null) Text(_status!),
                      if (_summary != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_summary!.totalPoints} points',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_summary!.badges.isEmpty)
                                  const Text('No badges yet.')
                                else
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('History',
                            style: Theme.of(context).textTheme.titleMedium),
                        for (final event in _summary!.events)
                          ListTile(
                            leading: const Icon(Icons.star_outline),
                            title: Text(event.reason),
                            subtitle: Text(event.at ?? ''),
                            trailing: Text('+${event.points}'),
                          ),
                        if (_summary!.events.isEmpty)
                          const ListTile(
                            title: Text('No rewards yet.'),
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
