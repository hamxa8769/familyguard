import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../build_flavor.dart';
import '../consent/consent_screen.dart';
import '../enforcement/enforcement.dart';
import '../features/gallery/gallery_collector.dart';
import '../features/location/location_collector.dart';
import '../features/messages/comms_collector.dart';
import '../features/usage/usage_collector.dart';

/// Result of the last sync, shown on the child home screen.
class SyncStatus {
  const SyncStatus(
      {this.at, this.running = false, this.sent = const [], this.error});

  final DateTime? at;
  final bool running;

  /// Human-readable list of what was sent, e.g. "12 apps".
  final List<String> sent;
  final String? error;
}

/// Sends what the collectors read on this device to the server, so the parent
/// app shows real data. Runs while the app is open (on start, every 15 minutes
/// and on "Sync now"). Only real device data is sent — the desktop preview
/// samples in the collectors are never uploaded.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final status = ValueNotifier<SyncStatus>(const SyncStatus());

  final _auth = AuthService.instance;
  final _usage = UsageCollector();
  final _location = LocationCollector();
  final _comms = CommsCollector();
  final _gallery = GalleryCollector();
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(const Duration(minutes: 15), (_) => syncNow());
    syncNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> syncNow() async {
    final deviceId = _auth.deviceId;
    if (deviceId == null || status.value.running) return;
    status.value = SyncStatus(at: status.value.at, running: true);

    final api = _auth.api;
    final sent = <String>[];
    String? error;

    Future<void> step(String name, Future<String?> Function() run) async {
      try {
        final label = await run();
        if (label != null) sent.add(label);
      } on ApiException catch (e) {
        error ??= '$name: ${e.message}';
      } catch (e) {
        error ??= '$name: $e';
      }
    }

    await step('Consent', () async {
      await ConsentService()
          .syncToServer(api, deviceId, ConsentScreen.consentText);
      return null;
    });

    await step('Rules', () async {
      final st = await Enforcement.fetchAndApply(api, deviceId);
      // Tell the parent whether the rules are actually enforced here.
      await api.put('/api/devices/$deviceId/status', {
        'enforcement': st?.toJson() ?? {'supported': false},
      });
      return null;
    });

    await step('Usage', () async {
      if (!Platform.isAndroid || !await _usage.hasPermission()) return null;
      final entries = await _usage.collect();
      final startOfDay = DateTime.now();
      final since = DateTime(startOfDay.year, startOfDay.month, startOfDay.day)
          .toIso8601String();
      await api.post('/api/usage', {
        'deviceId': deviceId,
        'snapshot': true,
        'events': [
          for (final e in entries)
            {
              'appName': e.appName,
              'startedAt': since,
              'durationSeconds': e.durationSeconds,
            },
        ],
      });
      return '${entries.length} apps';
    });

    await step('Location', () async {
      if (!Platform.isAndroid || !await _location.hasPermission()) return null;
      final point = await _location.current();
      if (point == null) return null;
      await api.post('/api/location', {
        'deviceId': deviceId,
        'lat': point.lat,
        'lng': point.lng,
      });
      return 'location';
    });

    await step('Messages', () async {
      if (kLiteBuild) return null; // not in the lite build
      if (!await _comms.hasPermission()) return null; // Android only
      final contacts = await _comms.contacts();
      final sms = await _comms.sms();
      final calls = await _comms.callLog();
      await api.post('/api/comms/$deviceId', {
        'contacts': [for (final c in contacts) c.toMap()],
        'sms': [for (final s in sms) s.toMap()],
        'callLog': [for (final c in calls) c.toMap()],
      });
      return '${sms.length} SMS, ${contacts.length} contacts, ${calls.length} calls';
    });

    await step('Files', () async {
      if (!(Platform.isAndroid || Platform.isWindows)) return null;
      if (!await _gallery.hasPermission()) return null;
      final files = await _gallery.images();
      await api.post('/api/files/$deviceId', {
        // Metadata only, and no local file paths (they can include the
        // device's user name). Paths stay on the device for thumbnails.
        'items': [
          for (final f in files) {...f.toMap(), 'path': ''}
        ],
      });
      return '${files.length} files';
    });

    status.value = SyncStatus(
      at: DateTime.now(),
      sent: sent,
      error: error,
    );
  }
}
