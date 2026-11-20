// Push (FCM) wiring — Phase 1 part C.
//
// What this does:
//  * Registers this device's FCM token with the server
//    (POST /api/devices/:id/push-token) so the server can *notify* the
//    device that rules/commands changed, instead of the child only learning
//    about them on its 15-minute poll.
//  * Runs a full sync when a push arrives — foreground and background — so
//    a pushed rule change is applied (Enforcement.fetchAndApply via
//    SyncService.syncNow) even with the app closed.
//
// What this deliberately does NOT do / require:
//  * There is NO Firebase project wired up yet: no google-services.json in
//    this repo and no FCM_SERVER_KEY on the server. Until the user provides
//    them (see the two steps at the bottom of this file), every Firebase
//    call below fails inside a try/catch, `available` stays false, and the
//    app behaves exactly as before — polling only. Nothing here may crash
//    the app or block startup when Firebase is unconfigured.
//  * The com.google.gms.google-services Gradle plugin is NOT applied (see
//    android/app/build.gradle.kts): applying it without google-services.json
//    fails the build. Do not apply it until google-services.json exists.
//
// USER-PROVIDED STEPS STILL NEEDED (until then, push stays off, polling
// keeps working):
//  1. Create a Firebase project, add the Android app, and put the
//     downloaded google-services.json in client/apps/child/android/app/
//     — then apply the com.google.gms.google-services plugin in
//     client/apps/child/android/app/build.gradle.kts.
//  2. Set FCM_SERVER_KEY in the backend .env (see backend/.env.example).
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../sync/sync_service.dart';

/// Background-message entry point (must be top-level).
///
/// Runs in a background isolate when a push arrives while the app is
/// closed. Same guards as the WorkManager sync: only for a paired device
/// whose consent is on record. Best-effort — a failure here just means the
/// next 15-minute poll picks the change up instead.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await AuthService.instance.load();
    if (AuthService.instance.deviceId == null) return;
    if (!await ConsentService().hasConsented()) return;
    await SyncService.instance.syncNow();
  } catch (_) {
    // Best effort only; polling is the fallback.
  }
}

/// Owns Firebase initialisation and FCM token registration for the child
/// app. Every Firebase call is guarded: without a Firebase project
/// configured this service is inert and the app keeps polling.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialised = false;

  /// True only once Firebase initialised successfully (i.e. a Firebase
  /// project is configured on this build). False = push unavailable.
  bool _available = false;
  bool get available => _available;

  /// Last token seen from Firebase, so registerPushToken() can re-send it
  /// without waiting for a fresh registration event.
  String? _latestToken;

  /// Last token sent to the server, so repeats/refreshes are not re-sent.
  String? _lastRegisteredToken;
  StreamSubscription<String>? _tokenSub;

  /// Registers the background handler and tries to initialise Firebase.
  /// Never throws. Call once from main() before runApp().
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    // Push is a mobile-only feature; the Windows build has no FCM.
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    try {
      FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
    } catch (_) {
      // Plugin unavailable (e.g. tests, unsupported platform) — push off.
    }
    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (_) {
      // No google-services.json / no Firebase project yet: push is simply
      // unavailable and the app keeps working via polling.
      _available = false;
      return;
    }
    try {
      // Foreground push: apply the new rules immediately.
      FirebaseMessaging.onMessage.listen((_) async {
        try {
          await SyncService.instance.syncNow();
        } catch (_) {
          // Best effort only; polling is the fallback.
        }
      });
      // Token stream first, then trigger registration: the token arrives
      // via onRegistered and is sent to the server from there.
      _tokenSub = FirebaseMessaging.instance.onRegistered.listen(
        (token) async {
          _latestToken = token;
          await _sendToken(token);
        },
      );
      await FirebaseMessaging.instance.register();
    } catch (_) {
      // Listening/registration failed — token registration below still
      // retries on start.
    }
  }

  /// Sends the FCM token (if Firebase is available and a token has been
  /// issued) to the server for this paired device. Best-effort, never
  /// throws. Call on app start (when already paired) and right after
  /// pairing.
  Future<void> registerPushToken() async {
    if (!_available) return;
    if (AuthService.instance.deviceId == null) return;
    try {
      final token = _latestToken;
      if (token != null && token.isNotEmpty) {
        await _sendToken(token);
        return;
      }
      // No token seen yet: (re-)trigger registration; the token arrives
      // via onRegistered and is sent to the server from there.
      await FirebaseMessaging.instance.register();
    } catch (_) {
      // Best effort only; polling is the fallback.
    }
  }

  /// Sends one token to the server using the shared authenticated client.
  /// Skips re-sending a token already registered for this device.
  Future<void> _sendToken(String token) async {
    final deviceId = AuthService.instance.deviceId;
    if (deviceId == null || token.isEmpty || token == _lastRegisteredToken) {
      return;
    }
    try {
      await AuthService.instance.api.post(
        '/api/devices/$deviceId/push-token',
        {'pushToken': token, 'pushPlatform': 'fcm'},
      );
      _lastRegisteredToken = token;
    } catch (_) {
      // Registration failed (offline, server down) — the next app start
      // retries; polling keeps working in the meantime.
    }
  }

  /// Test/support hook: forget the last sent token so the next
  /// registerPushToken() re-sends it.
  void forgetRegisteredToken() => _lastRegisteredToken = null;

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
  }
}
