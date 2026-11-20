/// System notifications for the FamilyGuard parent app (Android only;
/// a no-op elsewhere, including web and Windows).
library fg_notify;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FgNotify {
  static const _channel = MethodChannel('familyguard/notify');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Asks for the Android 13+ notification permission (no-op if granted).
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> isAllowed() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('isAllowed') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Shows a notification. [urgent] uses the high-importance SOS channel.
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    bool urgent = false,
  }) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('show', {
        'id': id,
        'title': title,
        'body': body,
        'urgent': urgent,
      });
    } on PlatformException {
      // Notifications are best-effort; the Alerts tab always has the item.
    }
  }
}
