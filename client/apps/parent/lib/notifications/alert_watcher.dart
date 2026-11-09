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
    _timer?.cancel();
    _timer = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sinceKey);
    if (FgNotify.supported) await Workmanager().cancelByUniqueName(_task);
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
