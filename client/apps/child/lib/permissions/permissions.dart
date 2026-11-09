import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../build_flavor.dart';
import '../enforcement/enforcement.dart';
import '../features/gallery/gallery_collector.dart';
import '../features/location/location_collector.dart';
import '../features/messages/comms_collector.dart';
import '../features/usage/usage_collector.dart';

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
  });

  final String id;
  final IconData icon;
  final String title;
  final String why;
  final Future<bool> Function() check;
  final Future<void> Function() request;

  /// True when Android sends the child to a Settings page instead of a dialog.
  final bool opensSettings;
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
    ),
    if (!kLiteBuild)
      PermissionItem(
        id: 'comms',
        icon: Icons.sms_outlined,
        title: 'Messages, contacts and calls',
        why: 'Shares SMS, contacts and call history with your parent.',
        check: comms.hasPermission,
        request: comms.requestPermission,
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
    ),
    PermissionItem(
      id: 'photos',
      icon: Icons.photo_library_outlined,
      title: 'Photos',
      why: 'Shares the names and dates of photos (not the pictures).',
      check: gallery.hasPermission,
      request: gallery.requestPermission,
    ),
  ];
}
