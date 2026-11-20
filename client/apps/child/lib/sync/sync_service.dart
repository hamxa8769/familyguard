import 'dart:async';
import 'dart:convert' show base64Encode;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../build_flavor.dart';
import '../consent/consent_screen.dart';
import '../enforcement/enforcement.dart';
import '../features/gallery/gallery_collector.dart';
import '../features/location/location_collector.dart';
import '../features/messages/comms_collector.dart';
import '../features/usage/usage_collector.dart';
import '../services/native_collectors.dart';

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
///
/// Rule changes also reach the phone faster than the 15-minute full sync: a
/// cheap `GET /api/devices/:id/rules-version` runs every 60 seconds while
/// the app is open, and the full rules are fetched only when the version
/// changed (Phase 3 rule-version fast path).
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

  /// 60-second rules-version poller (version check only — no rule fetch
  /// unless the version changed). Kept separate from the 15-minute full
  /// sync timer so the version check keeps its own cadence.
  Timer? _versionTimer;

  /// Last rules version seen for [_versionDeviceId], persisted so a restart
  /// does not re-fetch rules it already has. Null until the first full sync
  /// (or version check) has run.
  int? _lastRulesVersion;
  String? _versionDeviceId;

  static const _rulesVersionKey = 'fg_rules_version';
  static const _rulesVersionDeviceKey = 'fg_rules_version_device';

  void start() {
    _timer ??= Timer.periodic(const Duration(minutes: 15), (_) => syncNow());
    _versionTimer ??=
        Timer.periodic(const Duration(seconds: 60), (_) => _checkRulesVersion());
    syncNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _versionTimer?.cancel();
    _versionTimer = null;
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
      await _applyRules(api, deviceId);
      return null;
    });

    await step('Remote commands', () => _pollRemoteCommands(api, deviceId));

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
      // Each type syncs when its own permission is granted — granting only
      // READ_SMS still syncs SMS. Types that are not granted are left out
      // of the body entirely, so the server keeps what it already has.
      final perms = await _comms.hasPermissions();
      if (perms.values.every((granted) => !granted)) return null;
      final body = <String, dynamic>{};
      final labels = <String>[];
      if (perms['contacts'] == true) {
        final contacts = await _comms.contacts();
        body['contacts'] = [for (final c in contacts) c.toMap()];
        labels.add('${contacts.length} contacts');
      }
      List<SmsMessage> sms = const [];
      if (perms['sms'] == true) {
        sms = await _comms.sms();
        body['sms'] = [for (final s in sms) s.toMap()];
        labels.add('${sms.length} SMS');
      }
      if (perms['callLog'] == true) {
        final calls = await _comms.callLog();
        body['callLog'] = [for (final c in calls) c.toMap()];
        labels.add('${calls.length} calls');
      }
      if (body.isEmpty) return null;
      await api.post('/api/comms/$deviceId', body);
      return labels.join(', ');
    });

    await step('Files', () async {
      if (!(Platform.isAndroid || Platform.isWindows)) return null;
      if (!await _gallery.hasPermission()) return null;
      final files = await _gallery.images();
      final res = await api.post('/api/files/$deviceId', {
        // Metadata only, and no local file paths (they can include the
        // device's user name). Paths stay on the device for thumbnails.
        'items': [
          for (final f in files) {...f.toMap(), 'path': ''}
        ],
      });
      // Photo previews: only if the parent turned them on (and the child was
      // told in the consent notice). The server asks for the ones it lacks.
      // Thumbnails are the 1024 px tier (GalleryCollector default).
      final need = List<String>.from(res['needThumbs'] as List? ?? const []);
      var sent = 0;
      if (need.isNotEmpty) {
        final thumbs = <Map<String, String>>[];
        for (final key in need) {
          final bytes = await _gallery.thumbnail(key);
          if (bytes == null) continue;
          thumbs.add({
            'key': key,
            'mime': Platform.isAndroid ? 'image/jpeg' : 'image/png',
            'data': base64Encode(bytes),
          });
        }
        if (thumbs.isNotEmpty) {
          final up = await api.post('/api/files/$deviceId/thumbs', {'items': thumbs});
          sent = (up['saved'] as num?)?.toInt() ?? 0;
        }
      }
      // Full-res originals the parent requested: the child uploads each one
      // on its next sync (a parent request, never silent exfiltration).
      // Originals are only ever sent when previews are on (needOriginals
      // is empty otherwise) and are capped at 8 MB by the native side.
      final needOriginals =
          List<String>.from(res['needOriginals'] as List? ?? const []);
      var originalsSent = 0;
      for (final key in needOriginals) {
        MediaFile? file;
        for (final f in files) {
          if (f.key == key) {
            file = f;
            break;
          }
        }
        if (file == null) continue;
        final bytes = await _gallery.originalBytes(key);
        if (bytes == null) continue;
        try {
          await api.post('/api/files/$deviceId/original/${Uri.encodeComponent(key)}', {
            'mime': _originalMime(file),
            'data': base64Encode(bytes),
          });
          originalsSent++;
        } on ApiException {
          // Unknown key / too large / previews off: leave it for next sync.
          continue;
        }
      }
      final parts = <String>['${files.length} files'];
      if (sent > 0) parts.add('$sent previews');
      if (originalsSent > 0) parts.add('$originalsSent originals');
      return parts.join(', ');
    });

    status.value = SyncStatus(
      at: DateTime.now(),
      sent: sent,
      error: error,
    );
  }

  /// Fetches the full rules, applies them, and tells the parent whether
  /// they are actually enforced here (the status blob also carries the
  /// Private-DNS mode). Records the server's rules version afterwards, so
  /// the 60-second version check knows what "unchanged" looks like.
  Future<void> _applyRules(ApiClient api, String deviceId) async {
    final st = await Enforcement.fetchAndApply(api, deviceId);
    await api.put('/api/devices/$deviceId/status', {
      'enforcement': st?.toJson() ?? {'supported': false},
    });
    await _storeRulesVersion(api, deviceId);
  }

  /// Best-effort: remember the server's current rules version (in memory
  /// and in SharedPreferences). Never throws — a stale version only means
  /// the next check fetches the full rules.
  Future<void> _storeRulesVersion(ApiClient api, String deviceId) async {
    try {
      final v = await api.get('/api/devices/$deviceId/rules-version');
      final version = (v['rulesVersion'] as num?)?.toInt();
      if (version == null) return;
      _lastRulesVersion = version;
      _versionDeviceId = deviceId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_rulesVersionKey, version);
      await prefs.setString(_rulesVersionDeviceKey, deviceId);
    } catch (_) {}
  }

  /// The 60-second fast path: asks the server for the rules version only.
  /// Nothing is fetched when it is unchanged; when it changed (or was never
  /// seen for this device), the full rules are fetched and applied. Skipped
  /// while a full sync is running, and silent on network/server errors —
  /// the 15-minute full sync and the next minute's check try again.
  Future<void> _checkRulesVersion() async {
    final deviceId = _auth.deviceId;
    if (deviceId == null || status.value.running) return;
    try {
      if (_lastRulesVersion == null || _versionDeviceId != deviceId) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(_rulesVersionDeviceKey) == deviceId) {
          _lastRulesVersion = prefs.getInt(_rulesVersionKey);
          _versionDeviceId = deviceId;
        }
      }
      if (_lastRulesVersion == null) {
        // Never seen a version (first run, or the last full sync failed):
        // fetch the full rules instead of guessing.
        await _applyRules(_auth.api, deviceId);
        return;
      }
      final v = await _auth.api.get('/api/devices/$deviceId/rules-version');
      final version = (v['rulesVersion'] as num?)?.toInt();
      if (version == null || version == _lastRulesVersion) return;
      await _applyRules(_auth.api, deviceId);
    } on ApiException {
      // Offline / server error: keep the old version and retry next minute.
    } catch (_) {}
  }

  /// Fetches pending remote commands so they are picked up even when the
  /// child app is closed: the 15-minute WorkManager sync runs [syncNow]
  /// too, and commands now live for 60 minutes server-side.
  ///
  /// Only `lock_now` / `unlock` run here, without a tap (see
  /// [autoExecuteRemoteCommandInBackground]). Screenshot / audio requests
  /// and parent messages are NEVER executed here: they need the child's
  /// tap on the Remote Commands screen (and Android's capture dialog for
  /// screenshots) every time, so they stay pending until answered there.
  Future<String?> _pollRemoteCommands(ApiClient api, String deviceId) async {
    if (!Platform.isAndroid) return null;
    final data = await api.get(
      '/api/remotecommands?deviceId=$deviceId&status=pending',
    );
    final commands = (data['commands'] as List? ?? [])
        .map((c) => RemoteCommand.fromMap(c as Map))
        .toList();
    var executed = 0;
    final notes = <String>[];
    for (final command in commands) {
      if (!autoExecuteRemoteCommandInBackground(command)) continue;
      try {
        if (command.type == 'lock_now') {
          final note = await _executeLock(command, api);
          if (note == null) {
            executed++;
          } else {
            notes.add(note);
          }
        } else {
          // unlock: FamilyGuard holds no persistent device lock — the
          // screen lock is released by the child with their PIN/pattern —
          // so there is nothing to release locally. Record that plainly.
          await api.post('/api/remotecommands/${command.id}/ack', {
            'status': 'completed',
            'result': {
              'executedInBackground': true,
              'note':
                  'FamilyGuard holds no persistent device lock; the screen lock is released by the child with their PIN or pattern.',
            },
          });
          executed++;
        }
      } on ApiException catch (e) {
        notes.add('${command.type} (${command.id}): ${e.message}');
      }
    }
    if (executed == 0 && notes.isEmpty) return null;
    final parts = <String>[
      if (executed > 0) '$executed executed',
      ...notes,
    ];
    return '${commands.length} remote command(s): ${parts.join(', ')}';
  }

  /// Runs one `lock_now` command. Returns null when the device locked and
  /// the command was acknowledged, otherwise a human-readable reason the
  /// command was left pending: it retries on the next sync and expires
  /// after the server TTL. Never throws, never reports a false "completed".
  Future<String?> _executeLock(RemoteCommand command, ApiClient api) async {
    try {
      if (!await NativeCollectors.isAdminActive()) {
        return 'lock skipped: device admin is not activated';
      }
      await NativeCollectors.lockNow();
    } on MissingPluginException {
      // The lock channel is registered by FgNativePlugin in every engine,
      // including the background WorkManager isolate, so this should not
      // happen; if the plugin ever fails to register, leave the command
      // pending — the next sync (or the Remote Commands screen) retries it.
      return 'lock skipped: lock is only available while the app is open';
    } on PlatformException catch (e) {
      return 'lock failed: ${e.message ?? e.code}';
    }
    try {
      await api.post('/api/remotecommands/${command.id}/ack', {
        'status': 'completed',
        'result': {'executedInBackground': true},
      });
    } on ApiException {
      // The device did lock; only the acknowledgement failed. The command
      // stays pending and will be retried — locking again is harmless.
      return 'lock ran but could not be acknowledged';
    }
    return null;
  }
}

/// MIME for a full-res original upload, from the file name / kind.
String _originalMime(MediaFile file) {
  final lower = file.name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (!file.isImage) return 'video/mp4';
  return 'image/jpeg';
}

/// Which pending remote commands [SyncService] may execute in the
/// background without the child tapping anything.
///
/// Only `lock_now` and `unlock`: a screenshot or audio request must never
/// start silently (MediaProjection approval is required every time, and the
/// consent promise is that nothing is captured without the child
/// answering), and a parent message must be seen by the child before it is
/// acknowledged.
bool autoExecuteRemoteCommandInBackground(RemoteCommand command) =>
    command.type == 'lock_now' || command.type == 'unlock';
