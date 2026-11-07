import 'dart:io' show Platform;

class UsageEntry {
  UsageEntry(this.appName, this.durationSeconds);
  final String appName;
  final int durationSeconds;
}

/// Collects app-usage data. The real implementation is platform-specific and
/// lives behind a MethodChannel:
///   - Android: UsageStatsManager (needs PACKAGE_USAGE_STATS permission)
///   - Windows: foreground-window sampling
///   - iOS: not available to third-party apps — returns empty (handled in UI)
///
/// This stub returns sample data so the UI runs before native code is wired up.
class UsageCollector {
  Future<List<UsageEntry>> collect() async {
    // TODO: replace with MethodChannel('familyguard/usage').invokeMethod(...)
    if (Platform.isIOS) {
      return []; // iOS restricts third-party usage access.
    }
    return [
      UsageEntry('Browser', 3600),
      UsageEntry('Games', 1800),
      UsageEntry('Messaging', 1200),
      UsageEntry('Education', 900),
    ];
  }
}
