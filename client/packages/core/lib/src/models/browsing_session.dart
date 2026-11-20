/// One browser-app session: which browser was in the foreground, when,
/// and for how long.
///
/// Deliberate limit: this is NOT URL history. Android does not expose
/// visited URLs to third-party apps, and FamilyGuard does not run a VPN or
/// proxy to get them. The child is told exactly this in the consent notice.
class BrowsingSession {
  const BrowsingSession({
    required this.packageName,
    required this.browserLabel,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });

  final String packageName;
  final String browserLabel;
  final int startedAt;
  final int endedAt;
  final int durationSeconds;

  factory BrowsingSession.fromMap(Map<dynamic, dynamic> map) => BrowsingSession(
        packageName: (map['packageName'] ?? '').toString(),
        browserLabel: (map['browserLabel'] ?? map['packageName'] ?? '').toString(),
        startedAt: (map['startedAt'] as num? ?? 0).toInt(),
        endedAt: (map['endedAt'] as num? ?? 0).toInt(),
        durationSeconds: (map['durationSeconds'] as num? ?? 0).toInt(),
      );
}
