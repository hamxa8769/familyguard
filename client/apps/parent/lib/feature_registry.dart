import 'feature_module.dart';
import 'features/dashboard/dashboard_module.dart';
import 'features/children/children_module.dart';
import 'features/location/location_module.dart';
import 'features/screen_time/screen_time_module.dart';
import 'features/app_blocking/app_blocking_module.dart';
import 'features/web_filter/web_filter_module.dart';
import 'features/geofencing/geofencing_module.dart';
import 'features/bedtime/bedtime_module.dart';
import 'features/messages/messages_module.dart';
import 'features/call_log/call_log_module.dart';
import 'features/gallery/gallery_module.dart';
import 'features/alerts/alerts_module.dart';
import 'features/remote_commands/remote_commands_module.dart';
import 'features/media/media_module.dart';
import 'features/apps/apps_module.dart';
import 'features/browsing/browsing_module.dart';
import 'features/agreement/agreement_module.dart';
import 'features/rewards/rewards_module.dart';
import 'features/keywords/keywords_module.dart';

/// The single list of parent-side features. Add a new feature here (with its
/// [FeatureSection]) and it appears in the right tab automatically.
class FeatureRegistry {
  static final List<FeatureModule> all = [
    DashboardModule(),
    LocationModule(),
    MessagesModule(),
    CallLogModule(),
    GalleryModule(),
    ScreenTimeModule(),
    AppBlockingModule(),
    WebFilterModule(),
    BedtimeModule(),
    GeofencingModule(),
    ChildrenModule(),
    AlertsModule(),
    RemoteCommandsModule(),
    MediaModule(),
    AppsModule(),
    BrowsingModule(),
    AgreementModule(),
    RewardsModule(),
    KeywordsModule(),
  ];

  static FeatureModule? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
