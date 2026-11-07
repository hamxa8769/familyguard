import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the on-device consent notice has been accepted.
/// Monitoring features must check this before starting any collection.
class ConsentService {
  static const _key = 'consent_accepted_at';

  Future<bool> hasConsented() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) != null;
  }

  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
    // In the full app, also POST to /api/consent so there is a server-side record.
  }
}
