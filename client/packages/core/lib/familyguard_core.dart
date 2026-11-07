/// FamilyGuard shared core — used by both the parent and child apps.
///
/// Keeping models, networking, auth and consent here means the two apps stay
/// small and consistent: they share one API client and one data contract.
library familyguard_core;

export 'src/config/app_config.dart';
export 'src/network/api_client.dart';
export 'src/auth/auth_service.dart';
export 'src/consent/consent_service.dart';
export 'src/models/usage_entry.dart';
export 'src/models/child_profile.dart';
export 'src/models/sos_alert.dart';
