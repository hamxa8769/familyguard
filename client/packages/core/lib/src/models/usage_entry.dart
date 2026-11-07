/// One app's foreground time for a period.
class UsageEntry {
  const UsageEntry(this.appName, this.durationSeconds);

  final String appName;
  final int durationSeconds;

  int get minutes => (durationSeconds / 60).round();

  factory UsageEntry.fromMap(Map<dynamic, dynamic> map) => UsageEntry(
        (map['appName'] ?? 'Unknown').toString(),
        (map['durationSeconds'] ?? 0) as int,
      );
}
