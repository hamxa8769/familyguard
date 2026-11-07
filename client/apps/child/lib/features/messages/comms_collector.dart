import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Reads contacts and SMS on the child device (Android only).
/// Requires the READ_CONTACTS + READ_SMS runtime permissions, which the user
/// grants in a visible system dialog. Disclosed in the transparency screen.
class CommsCollector {
  static const _channel = MethodChannel('familyguard/comms');

  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
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

  Future<List<ContactEntry>> contacts() async {
    if (!Platform.isAndroid) return _sampleContacts;
    try {
      final List<dynamic> data =
          await _channel.invokeMethod('getContacts') ?? <dynamic>[];
      return data
          .map((e) => ContactEntry.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<SmsMessage>> sms() async {
    if (!Platform.isAndroid) return _sampleSms;
    try {
      final List<dynamic> data =
          await _channel.invokeMethod('getSms') ?? <dynamic>[];
      return data
          .map((e) => SmsMessage.fromMap(e as Map<dynamic, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Sample data for non-Android (Windows/desktop preview).
  static const _sampleContacts = [
    ContactEntry('Ammi', '+92 300 1234567'),
    ContactEntry('School', '+92 42 111222333'),
    ContactEntry('Best Friend', '+92 301 7654321'),
  ];

  static final _sampleSms = [
    SmsMessage(address: '+92 300 1234567', body: 'Beta ghar kab aao ge?', dateMillis: DateTime.now().millisecondsSinceEpoch - 600000, type: 1),
    SmsMessage(address: '+92 301 7654321', body: 'Kal milte hain', dateMillis: DateTime.now().millisecondsSinceEpoch - 3600000, type: 2),
  ];
}
