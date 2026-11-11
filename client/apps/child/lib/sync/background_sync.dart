import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;
import 'package:flutter/widgets.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:workmanager/workmanager.dart';
import 'sync_service.dart';

/// Runs in a background isolate started by Android WorkManager — also when
/// the app is closed. Shares the same data as "Sync now", and only after the
/// device is paired and the child has accepted the (current) consent notice.
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      await AuthService.instance.load();
      if (AuthService.instance.deviceId == null) return true;
      if (!await ConsentService().hasConsented()) return true;
      await SyncService.instance.syncNow();
      // false → WorkManager retries later with back-off.
      return SyncService.instance.status.value.error == null;
    } catch (_) {
      return false;
    }
  });
}

class BackgroundSync {
  static const _task = 'familyguard.periodic-sync';

  /// Android's minimum period; the OS may run it later (Doze, battery saver).
  static const interval = Duration(minutes: 15);

  static bool get supported => Platform.isAndroid;

  /// Schedules periodic sync (idempotent — keeps an existing schedule).
  static Future<void> enable() async {
    if (!supported) return;
    await Workmanager().initialize(backgroundSyncDispatcher);
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      frequency: interval,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  /// Stops background sync (e.g. when the device is unpaired).
  static Future<void> disable() async {
    if (!supported) return;
    await Workmanager().cancelByUniqueName(_task);
  }
}
