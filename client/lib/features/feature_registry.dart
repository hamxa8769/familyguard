import 'feature_module.dart';
import 'usage_tracker/usage_tracker_module.dart';
import 'screen_time/screen_time_module.dart';
import 'app_blocking/app_blocking_module.dart';
import 'location/location_module.dart';
import 'geofencing/geofencing_module.dart';
import 'sos/sos_module.dart';
import 'web_filter/web_filter_module.dart';
import 'bedtime/bedtime_module.dart';
import 'reports/reports_module.dart';
import 'children/children_module.dart';
import 'transparency/transparency_module.dart';

/// The single list of active features. Add a new feature here and it appears
/// in the dashboard automatically — nothing else changes.
class FeatureRegistry {
  static final List<FeatureModule> all = [
    ReportsModule(),
    ChildrenModule(),
    UsageTrackerModule(),
    ScreenTimeModule(),
    AppBlockingModule(),
    LocationModule(),
    GeofencingModule(),
    BedtimeModule(),
    WebFilterModule(),
    SosModule(),
    TransparencyModule(),
  ];
}
