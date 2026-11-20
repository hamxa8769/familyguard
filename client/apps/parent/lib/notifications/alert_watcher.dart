import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;
import 'package:fg_notify/fg_notify.dart';
import 'package:flutter/widgets.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

/// Turns new SOS alerts, "more time" requests and safe-zone events into
/// phone notifications — without Firebase:
///   - while the app is open: checks the server every 30 seconds;
///   - while it is closed (Android): WorkManager checks about every 15 minutes.
/// Instant delivery to a closed app needs push (FCM) — see docs/ROADMAP.md.
class AlertWatcher {
  AlertWatcher._();
  static final AlertWatcher instance = AlertWatcher._();

  static const _sinceKey = 'feed_since';
  static const _badCyclesPrefix = 'enforcement_bad_cycles_';
  static const _task = 'familyguard.parent-alerts';
  static const foregroundInterval = Duration(seconds: 30);

  Timer? _timer;
  bool _checking = false;

  /// Called when the open app sees something new (to refresh the screens).
  VoidCallback? onNewItems;

  /// Starts foreground polling and schedules the background check.
  Future<void> start() async {
    _timer ??= Timer.periodic(foregroundInterval, (_) => checkNow());
    unawaited(checkNow());
    if (FgNotify.supported) {
      await FgNotify.requestPermission();
      await Workmanager().initialize(alertWatcherDispatcher);
      await Workmanager().registerPeriodicTask(
        _task,
        _task,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    }
  }

  /// Stops everything (sign-out).
  Future<void> stop() async {
    stopForeground();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sinceKey);
    for (final k in prefs.getKeys().where((k) => k.startsWith(_badCyclesPrefix))) {
      await prefs.remove(k);
    }
    if (FgNotify.supported) await Workmanager().cancelByUniqueName(_task);
  }

  /// Cancels only the foreground poller — no prefs / WorkManager work, so
  /// it is safe to call from widget disposal (the full stop() spawns a
  /// WorkManager process call, which never completes under fake async in
  /// widget tests and leaves a pending timer).
  void stopForeground() {
    _timer?.cancel();
    _timer = null;
  }

  /// Fetches new items since the last check and notifies about each one.
  /// Returns how many were new.
  Future<int> checkNow() async {
    if (_checking || !AuthService.instance.isSignedIn) return 0;
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Another isolate (background check) may have moved the cursor.
      await prefs.reload();
      final since = prefs.getString(_sinceKey);
      final res = await AuthService.instance.api
          .get('/api/feed?since=${Uri.encodeQueryComponent(since ?? '')}');
      final now = res['now'] as String;
      // Enforcement health rides on the same check: alert (not just
      // display) when a device reports rules that are not active.
      await _checkEnforcement();
      // First run: start from now instead of replaying old history.
      if (since == null) {
        await prefs.setString(_sinceKey, now);
        return 0;
      }
      final items = (res['items'] as List).cast<Map>();
      for (final item in items) {
        await FgNotify.show(
          id: _idFor(item),
          title: '${item['title']}',
          body: '${item['body']}',
          urgent: item['type'] == 'sos',
        );
      }
      await prefs.setString(_sinceKey, now);
      if (items.isNotEmpty) onNewItems?.call();
      return items.length;
    } on ApiException {
      return 0;
    } finally {
      _checking = false;
    }
  }

  /// Checks every device's last reported enforcement status and alerts
  /// the parent (same FgNotify pattern as the feed alerts above) when
  /// rules exist but are not active — app rules set but
  /// `appRulesActive` false, web rules set but `webFilterActive` false,
  /// or Private DNS set to a hostname (which bypasses the DNS web
  /// filter). A device only counts after more than one consecutive bad
  /// check, and each bad streak alerts exactly once (on the 2nd bad
  /// cycle); a recovered device resets, so a new streak alerts again.
  /// Best-effort: a failed check never breaks the feed alerts.
  Future<void> _checkEnforcement() async {
    try {
      final res = await AuthService.instance.api.get('/api/devices');
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final devices = (res['devices'] as List? ?? []).cast<Map>();
      for (final d in devices) {
        final deviceId = '${d['id']}';
        final e = d['enforcement'] as Map?;
        final problems = <String>[];
        if (e != null) {
          if (e['hasAppRules'] == true && e['appRulesActive'] != true) {
            problems.add(
                'app blocking, bedtime or screen-time rules are set but not active');
          }
          if (e['hasWebRules'] == true && e['webFilterActive'] != true) {
            problems.add('the web filter is set but not running');
          }
          if (e['hasWebRules'] == true && e['privateDnsMode'] == 'hostname') {
            problems.add(
                'Private DNS is set to a hostname, so blocked sites may still load');
          }
        }
        final key = '$_badCyclesPrefix$deviceId';
        if (problems.isEmpty) {
          if (prefs.getInt(key) != 0) await prefs.setInt(key, 0);
          continue;
        }
        final cycles = (prefs.getInt(key) ?? 0) + 1;
        await prefs.setInt(key, cycles);
        if (cycles != 2) continue; // alert once, on the 2nd bad cycle
        final name = '${d['deviceName'] ?? 'Device $deviceId'}';
        await FgNotify.show(
          id: 'enforcement-$deviceId'.hashCode & 0x7fffffff,
          title: 'Enforcement not active on $name',
          body: '${problems.join('; ')}.',
        );
      }
    } on ApiException {
      // Best effort: a failed check must not break the feed alerts.
    }
  }

  static int _idFor(Map item) =>
      '${item['type']}-${item['id']}'.hashCode & 0x7fffffff;
}

/// Background entry point (Android WorkManager), also runs when the app is closed.
@pragma('vm:entry-point')
void alertWatcherDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await AuthService.instance.load();
      await AlertWatcher.instance.checkNow();
      return true;
    } catch (_) {
      return false;
    }
  });
}
