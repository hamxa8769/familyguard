import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class UsageEntry {
  UsageEntry(this.appName, this.durationSeconds);
  final String appName;
  final int durationSeconds;
}

/// Collects app-usage data.
///   - Android: real data via UsageStatsManager (native MethodChannel).
///   - Windows: sample data until the native collector is added.
///   - iOS: not available to third-party apps — returns empty.
class UsageCollector {
  static const _channel = MethodChannel('familyguard/usage');

  /// Android only: whether the user has granted Usage Access in Settings.
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system Usage Access settings page so the user can grant access.
  Future<void> openSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (_) {}
  }

  Future<List<UsageEntry>> collect() async {
    if (Platform.isAndroid) {
      try {
        final List<dynamic> data =
            await _channel.invokeMethod('getUsage') ?? <dynamic>[];
        return data
            .map((e) => UsageEntry(
                  (e['appName'] ?? 'Unknown').toString(),
                  (e['durationSeconds'] ?? 0) as int,
                ))
            .toList();
      } catch (_) {
        return [];
      }
    }
    if (Platform.isIOS) return []; // iOS restricts third-party usage access.

    // Windows (and others): sample data until native collector lands.
    return [
      UsageEntry('Browser', 3600),
      UsageEntry('Games', 1800),
      UsageEntry('Messaging', 1200),
      UsageEntry('Education', 900),
    ];
  }
}
