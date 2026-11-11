import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// What the phone can currently enforce (from the native side).
class EnforcementStatus {
  const EnforcementStatus(this.raw);
  final Map raw;

  bool get usageAccess => raw['usageAccess'] == true;
  bool get overlay => raw['overlay'] == true;
  bool get vpnApproved => raw['vpnApproved'] == true;
  bool get notifications => raw['notifications'] == true;
  bool get appRulesActive => raw['appRulesActive'] == true;
  bool get webFilterActive => raw['webFilterActive'] == true;
  bool get hasAppRules => raw['hasAppRules'] == true;
  bool get hasWebRules => raw['hasWebRules'] == true;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}

/// Applies the parent's rules on this phone (Android): blocked apps, bedtime,
/// daily limit (+ approved extra time) and blocked websites.
///
/// Rules are fetched from the server on every sync and handed to the native
/// enforcement service, which keeps them on the phone so they also work
/// offline and after a restart.
class Enforcement {
  static const _ch = MethodChannel('familyguard/enforce');

  static bool get supported => Platform.isAndroid;

  /// Fetches the current rules and applies them. Returns the resulting status.
  static Future<EnforcementStatus?> fetchAndApply(
      ApiClient api, String deviceId) async {
    if (!supported) return null;
    final r = await Future.wait([
      api.get('/api/screentime/$deviceId'),
      api.get('/api/bedtime/$deviceId'),
      api.get('/api/appblocking/$deviceId'),
      api.get('/api/webfilter/$deviceId'),
    ]);
    final schedule = r[1]['schedule'] as Map?;
    final rules = {
      'blockedApps': r[2]['apps'] ?? const [],
      // Already includes extra time the parent approved today.
      'limitMinutes': r[0]['dailyMinutes'],
      'bedtimeStart': schedule?['startHour'],
      'bedtimeEnd': schedule?['endHour'],
      'blockedDomains': r[3]['blockedDomains'] ?? const [],
    };
    final res = await _ch.invokeMethod<Map>('setRules', {
      'json': jsonEncode(rules),
    });
    return res == null ? null : EnforcementStatus(res);
  }

  static Future<EnforcementStatus?> status() async {
    if (!supported) return null;
    try {
      final res = await _ch.invokeMethod<Map>('status');
      return res == null ? null : EnforcementStatus(res);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Re-applies saved rules (e.g. after a permission was granted).
  static Future<void> apply() async {
    if (!supported) return;
    try {
      await _ch.invokeMethod('apply');
    } on PlatformException {
      // best effort
    }
  }

  static Future<void> requestOverlay() => _call('requestOverlay');
  static Future<void> requestVpn() => _call('requestVpn');
  static Future<void> requestNotifications() => _call('requestNotifications');

  static Future<void> _call(String method) async {
    if (!supported) return;
    try {
      await _ch.invokeMethod(method);
    } on PlatformException {
      // best effort
    }
  }
}
