import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';

/// Tracks whether the on-device consent notice has been accepted.
/// The child app checks this before starting any collection, and the
/// acceptance is also recorded on the server so the parent side has a record.
///
/// The notice is versioned: when what FamilyGuard does changes (e.g. sharing
/// in the background), [currentVersion] goes up and the child is asked again.
class ConsentService {
  /// v1: initial notice. v2: adds background sharing while the app is closed.
  static const currentVersion = 2;

  static const _key = 'consent_accepted_at';
  static const _versionKey = 'consent_version';
  static const _syncedKey = 'consent_synced';

  Future<bool> hasConsented() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key) == null) return false;
    return (prefs.getInt(_versionKey) ?? 1) >= currentVersion;
  }

  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
    await prefs.setInt(_versionKey, currentVersion);
    await prefs.setBool(_syncedKey, false);
  }

  /// Sends the consent record to the server once (retried on later syncs).
  Future<void> syncToServer(
      ApiClient api, String deviceId, String acceptedText) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await hasConsented()) return;
    if (prefs.getBool(_syncedKey) == true) return;
    await api.post('/api/consent', {
      'deviceId': deviceId,
      'acceptedText': acceptedText,
    });
    await prefs.setBool(_syncedKey, true);
  }
}
