import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../build_flavor.dart';
import '../enforcement/enforcement.dart';
import '../features/gallery/gallery_collector.dart';
import '../features/location/location_collector.dart';
import '../features/messages/comms_collector.dart';
import '../features/usage/usage_collector.dart';
import '../services/native_collectors.dart';

/// One Android permission the child is asked for, with a plain reason.
class PermissionItem {
  const PermissionItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.why,
    required this.check,
    required this.request,
    this.opensSettings = false,
    this.permanentlyDenied,
  });

  final String id;
  final IconData icon;
  final String title;
  final String why;
  final Future<bool> Function() check;
  final Future<void> Function() request;

  /// True when Android sends the child to a Settings page instead of a dialog.
  final bool opensSettings;

  /// True when Android will no longer show the system dialog for this item
  /// (denied with "don't ask again"), so the card must offer the app
  /// Settings page instead of a dead Allow button. Null for items that
  /// never show a runtime dialog (Settings-page items).
  final Future<bool> Function()? permanentlyDenied;
}

/// Dart side of the `familyguard/permissions` channel (FgNativePlugin):
/// permanently-denied detection and the app-Settings fallback.
class AppSettings {
  static const _channel = MethodChannel('familyguard/permissions');

  /// True when the system will no longer show the runtime dialog for the
  /// given Android permission(s). With [requireAll], every listed
  /// permission must be in that state (location: either one grants the
  /// item); otherwise any one is enough (comms: all three are required).
  /// The `"gallery"` alias resolves to the OS-version gallery permission.
  /// Only call this for items already requested at least once — Android
  /// cannot tell "never asked" apart from "don't ask again", and both
  /// report no rationale.
  static Future<bool> isPermanentlyDenied(
    List<String> permissions, {
    bool requireAll = false,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isPermanentlyDenied', {
            'permissions': permissions,
            'requireAll': requireAll,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Opens this app's page in Android Settings
  /// (ACTION_APPLICATION_DETAILS_SETTINGS), where a permanently-denied
  /// permission can be turned back on by hand.
  static Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (_) {}
  }

  /// True when Android is already letting FamilyGuard run without battery
  /// optimisation (Doze / App Standby will not defer its background sync
  /// and enforcement restarts).
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system screen that asks the user to let FamilyGuard run
  /// without battery optimisation (ACTION_REQUEST_IGNORE_BATTERY_
  /// OPTIMIZATIONS). Android still shows its own dialog/page — this only
  /// opens it; the user decides.
  static Future<void> requestBatteryOptimisationExemption() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestBatteryOptimisationExemption');
    } catch (_) {}
  }
}

/// The permissions FamilyGuard uses. Only Android asks at runtime; on other
/// platforms the list is empty (nothing to grant).
List<PermissionItem> permissionItems() {
  if (!Platform.isAndroid) return const [];
  final usage = UsageCollector();
  final location = LocationCollector();
  final comms = CommsCollector();
  final gallery = GalleryCollector();
  return [
    PermissionItem(
      id: 'usage',
      icon: Icons.bar_chart_rounded,
      title: 'App usage',
      why: 'Shows you and your parent your screen time.',
      check: usage.hasPermission,
      request: usage.openSettings,
      opensSettings: true,
    ),
    PermissionItem(
      id: 'location',
      icon: Icons.location_on_outlined,
      title: 'Location',
      why: 'Lets your parent find you and use safe zones and SOS.',
      check: location.hasPermission,
      request: location.requestPermission,
      permanentlyDenied: () => AppSettings.isPermanentlyDenied(
        [
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.ACCESS_COARSE_LOCATION',
        ],
        requireAll: true,
      ),
    ),
    if (!kLiteBuild)
      PermissionItem(
        id: 'comms',
        icon: Icons.sms_outlined,
        title: 'Messages, contacts and calls',
        why: 'Shares SMS, contacts and call history with your parent.',
        check: comms.hasPermission,
        request: comms.requestPermission,
        permanentlyDenied: () => AppSettings.isPermanentlyDenied(
          [
            'android.permission.READ_CONTACTS',
            'android.permission.READ_SMS',
            'android.permission.READ_CALL_LOG',
          ],
        ),
      ),
    PermissionItem(
      id: 'overlay',
      icon: Icons.layers_outlined,
      title: 'Display over other apps',
      why: 'Lets FamilyGuard show the "paused" screen when one of your '
          'parent\'s rules applies (bedtime, time limit, blocked app).',
      check: () async => (await Enforcement.status())?.overlay ?? false,
      request: Enforcement.requestOverlay,
      opensSettings: true,
    ),
    PermissionItem(
      id: 'vpn',
      icon: Icons.vpn_lock_outlined,
      title: 'Web filter',
      why: 'Blocks websites your parent chose. Android shows a key icon '
          'while it runs. Only website names are checked, never pages.',
      check: () async => (await Enforcement.status())?.vpnApproved ?? false,
      request: Enforcement.requestVpn,
    ),
    PermissionItem(
      id: 'notifications',
      icon: Icons.notifications_outlined,
      title: 'Status notification',
      why: 'Shows "FamilyGuard is active" and how much time is left.',
      check: () async => (await Enforcement.status())?.notifications ?? false,
      request: Enforcement.requestNotifications,
      permanentlyDenied: () => AppSettings.isPermanentlyDenied(
        ['android.permission.POST_NOTIFICATIONS'],
      ),
    ),
    PermissionItem(
      id: 'photos',
      icon: Icons.photo_library_outlined,
      title: 'Photos',
      why: 'Shares the names and dates of photos (not the pictures).',
      check: gallery.hasPermission,
      request: gallery.requestPermission,
      permanentlyDenied: () =>
          AppSettings.isPermanentlyDenied(['gallery']),
    ),
    PermissionItem(
      id: 'audio',
      icon: Icons.mic_outlined,
      title: 'Microphone (SOS audio only)',
      why: 'Lets FamilyGuard record a short SOS audio clip (max 30 '
          'seconds) when you or your parent asks. It never listens '
          'continuously.',
      check: NativeCollectors.hasAudioPermission,
      request: NativeCollectors.requestAudioPermission,
      permanentlyDenied: () => AppSettings.isPermanentlyDenied(
        ['android.permission.RECORD_AUDIO'],
      ),
    ),
    PermissionItem(
      id: 'deviceAdmin',
      icon: Icons.lock_outlined,
      title: 'Device admin (Lock now)',
      why: 'Lets FamilyGuard lock this device when your parent sends a '
          '"Lock now" command. It cannot wipe the device, change '
          'passwords, or disable the camera or microphone.',
      check: NativeCollectors.isAdminActive,
      request: NativeCollectors.requestAdmin,
      opensSettings: true,
    ),
    PermissionItem(
      id: 'battery',
      icon: Icons.battery_charging_full_outlined,
      title: 'Run without battery optimisation',
      why: 'Lets FamilyGuard keep checking rules and restarting enforcement '
          'when the phone is idle. Without it Android may delay background '
          'syncs for hours (Doze / battery saver).',
      check: AppSettings.isIgnoringBatteryOptimizations,
      request: AppSettings.requestBatteryOptimisationExemption,
      opensSettings: true,
    ),
  ];
}
