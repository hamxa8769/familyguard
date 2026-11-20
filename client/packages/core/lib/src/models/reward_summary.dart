/// Reward system: points and badges for healthy habits (e.g. staying
/// inside the screen-time limit). Points are only ever added by the parent
/// or by the one automatic rule (screen-time bonus); the child can only
/// view them.
class RewardEvent {
  const RewardEvent({
    required this.id,
    required this.points,
    required this.reason,
    this.badge,
    this.at,
  });

  final String id;
  final int points;
  final String reason;
  final String? badge;
  final String? at;

  factory RewardEvent.fromMap(Map<dynamic, dynamic> map) => RewardEvent(
        id: map['id'].toString(),
        points: (map['points'] as num? ?? 0).toInt(),
        reason: (map['reason'] ?? '').toString(),
        badge: map['badge']?.toString(),
        at: map['at']?.toString(),
      );
}

class RewardSummary {
  const RewardSummary({
    required this.totalPoints,
    required this.badges,
    required this.events,
  });

  final int totalPoints;
  final List<String> badges;
  final List<RewardEvent> events;

  factory RewardSummary.fromMap(Map<dynamic, dynamic> map) => RewardSummary(
        totalPoints: (map['totalPoints'] as num? ?? 0).toInt(),
        badges: (map['badges'] as List? ?? []).map((b) => b.toString()).toList(),
        events: (map['events'] as List? ?? [])
            .map((e) => RewardEvent.fromMap(e as Map))
            .toList(),
      );
}
