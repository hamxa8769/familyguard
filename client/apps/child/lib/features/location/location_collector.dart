import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Reads the device's last-known GPS location (Android only).
/// Requires ACCESS_FINE_LOCATION, granted in a visible system dialog.
class LocationCollector {
  static const _channel = MethodChannel('familyguard/location');

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  Future<LocationPoint?> current() async {
    if (!Platform.isAndroid) {
      // Sample point for desktop preview.
      return LocationPoint(
        lat: 31.5204,
        lng: 74.3587,
        timeMillis: DateTime.now().millisecondsSinceEpoch,
      );
    }
    try {
      final result = await _channel.invokeMethod('getLocation');
      return LocationPoint.fromMap(result as Map<dynamic, dynamic>?);
    } catch (_) {
      return null;
    }
  }
}
