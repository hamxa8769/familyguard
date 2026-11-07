import 'feature_module.dart';
import 'features/dashboard/dashboard_module.dart';
import 'features/children/children_module.dart';
import 'features/screen_time/screen_time_module.dart';
import 'features/app_blocking/app_blocking_module.dart';
import 'features/web_filter/web_filter_module.dart';
import 'features/geofencing/geofencing_module.dart';
import 'features/bedtime/bedtime_module.dart';
import 'features/messages/messages_module.dart';
import 'features/call_log/call_log_module.dart';
import 'features/alerts/alerts_module.dart';

/// The single list of parent-side features. Add a new feature here and it
/// appears in the dashboard automatically — nothing else changes.
class FeatureRegistry {
  static final List<FeatureModule> all = [
    DashboardModule(),
    ChildrenModule(),
    ScreenTimeModule(),
    AppBlockingModule(),
    WebFilterModule(),
    GeofencingModule(),
    BedtimeModule(),
    MessagesModule(),
    CallLogModule(),
    AlertsModule(),
  ];
}
