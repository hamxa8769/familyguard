import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the on-device consent notice has been accepted.
/// The child app checks this before starting any collection.
///
/// Consent is versioned: v2 (0.7.1) adds remote commands, on-request
/// screenshots and SOS-only short audio. A device that consented under v1
/// must see the new notice and re-confirm before any new feature runs —
/// the old key is deliberately not reused.
class ConsentService {
  /// Current consent version. Bump this whenever the consent text gains a
  /// new data collection (and update the server-side consentVersion too).
  static const currentVersion = '2';

  static const _key = 'consent_accepted_at_v2';

  Future<bool> hasConsented() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) != null;
  }

  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DateTime.now().toIso8601String());
    // In the full app, also POST to /api/consent for a server-side record,
    // with consentVersion: ConsentService.currentVersion.
  }
}
