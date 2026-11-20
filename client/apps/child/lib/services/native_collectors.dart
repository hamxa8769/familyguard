import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Dart side of the native Android channels (see MainActivity.kt).
///
/// On non-Android platforms every method degrades to a documented no-op:
/// Windows collection is a TODO (see docs/ARCHITECTURE.md §6) and the
/// methods return empty results instead of pretending to work.
class NativeCollectors {
  static const _apps = MethodChannel('familyguard/apps');
  static const _browsing = MethodChannel('familyguard/browsing');
  static const _lock = MethodChannel('familyguard/lock');
  static const _screen = MethodChannel('familyguard/screen');
  static const _audio = MethodChannel('familyguard/audio');
  static const _enforcement = MethodChannel('familyguard/enforcement');

  static bool get _isAndroid => Platform.isAndroid;

  // ---- Installed apps ----

  static Future<List<InstalledApp>> getInstalledApps() async {
    if (!_isAndroid) return [];
    final raw = await _apps.invokeMethod<List>('getInstalledApps');
    return (raw ?? [])
        .map((m) => InstalledApp.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  // ---- Browsing sessions (browser app, when, how long — NOT URLs) ----

  static Future<List<BrowsingSession>> getBrowserSessions() async {
    if (!_isAndroid) return [];
    final raw = await _browsing.invokeMethod<List>('getBrowserSessions');
    return (raw ?? [])
        .map((m) => BrowsingSession.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  // ---- Device-admin lock ----

  static Future<bool> isAdminActive() async {
    if (!_isAndroid) return false;
    return await _lock.invokeMethod<bool>('isAdminActive') ?? false;
  }

  static Future<void> requestAdmin() async {
    if (!_isAndroid) return;
    await _lock.invokeMethod('requestAdmin');
  }

  /// Locks the screen now. Throws a PlatformException when the device
  /// admin is not activated — the UI must then ask the user to activate it.
  static Future<void> lockNow() async {
    if (!_isAndroid) return;
    await _lock.invokeMethod('lockNow');
  }

  // ---- Screenshot (on-request, countdown + system approval) ----

  /// Starts the visible countdown, then Android's own screen-capture
  /// dialog. The result arrives via [getCaptureResult] — poll it.
  static Future<void> requestScreenshot({
    required String commandId,
    int countdownSeconds = 5,
  }) async {
    if (!_isAndroid) return;
    await _screen.invokeMethod('requestScreenshot', {
      'commandId': commandId,
      'countdownSeconds': countdownSeconds,
    });
  }

  // ---- SOS / parent-requested audio (max 30 s, indicator + beep) ----

  static Future<bool> hasAudioPermission() async {
    if (!_isAndroid) return false;
    return await _audio.invokeMethod<bool>('hasAudioPermission') ?? false;
  }

  static Future<void> requestAudioPermission() async {
    if (!_isAndroid) return;
    await _audio.invokeMethod('requestAudioPermission');
  }

  static Future<void> startSosAudio({required String commandId}) async {
    if (!_isAndroid) return;
    await _audio.invokeMethod('startSosAudio', {'commandId': commandId});
  }

  static Future<void> stopAudio() async {
    if (!_isAndroid) return;
    await _audio.invokeMethod('stopAudio');
  }

  /// Reads the capture result written by CaptureService and clears it.
  /// Returns null while the capture is still in progress.
  /// Shape: {type, commandId, path, error, at}.
  static Future<Map<String, dynamic>?> getCaptureResult() async {
    if (!_isAndroid) return null;
    final raw = await _screen.invokeMethod<Map>('getCaptureResult');
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  // ---- Enforcement (overlay permission for the block screen) ----
  // Rules themselves are fetched and applied by Enforcement.fetchAndApply
  // (System A); there is no second watcher anymore.

  static Future<bool> hasOverlayPermission() async {
    if (!_isAndroid) return false;
    return await _enforcement.invokeMethod<bool>('hasOverlayPermission') ?? false;
  }

  static Future<void> openOverlaySettings() async {
    if (!_isAndroid) return;
    await _enforcement.invokeMethod('openOverlaySettings');
  }

  // ---- Upload a capture file to the backend ----

  /// Reads [filePath] (PNG screenshot or 30 s audio clip) and uploads it
  /// as base64 to POST /api/media/:captureId/upload. Returns the updated
  /// capture map. Throws [ApiException] on failure.
  static Future<Map<String, dynamic>> uploadCapture({
    required ApiClient api,
    required String captureId,
    required String filePath,
    required String mimeType,
    int? durationSeconds,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final data = await api.post('/api/media/$captureId/upload', {
      'dataBase64': base64Encode(bytes),
      'mimeType': mimeType,
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    });
    return Map<String, dynamic>.from(data as Map);
  }
}
