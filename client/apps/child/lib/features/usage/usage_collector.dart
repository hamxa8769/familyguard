import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Collects app-usage data on the child device.
///   - Android: real data via UsageStatsManager (native MethodChannel).
///   - Windows: sample data until the native collector is added.
///   - iOS: not available to third-party apps — returns empty.
class UsageCollector {
  static const _channel = MethodChannel('familyguard/usage');

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

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
            .map((e) => UsageEntry.fromMap(e as Map<dynamic, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
    if (Platform.isIOS) return [];
    return const [
      UsageEntry('Browser', 3600),
      UsageEntry('Games', 1800),
      UsageEntry('Messaging', 1200),
      UsageEntry('Education', 900),
    ];
  }
}
