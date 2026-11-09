import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

/// Tracks whether the on-device consent notice has been accepted.
/// The child app checks this before starting any collection, and the
/// acceptance is also recorded on the server so the parent side has a record.
class ConsentService {
  static const _key = 'consent_accepted_at';
  static const _syncedKey = 'consent_synced';

  Future<bool> hasConsented() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) != null;
  }

  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
    await prefs.setBool(_syncedKey, false);
  }

  /// Sends the consent record to the server once (retried on later syncs).
  Future<void> syncToServer(
      ApiClient api, String deviceId, String acceptedText) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key) == null) return;
    if (prefs.getBool(_syncedKey) == true) return;
    await api.post('/api/consent', {
      'deviceId': deviceId,
      'acceptedText': acceptedText,
    });
    await prefs.setBool(_syncedKey, true);
  }
}
