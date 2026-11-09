import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

class LocationModule implements FeatureModule {
  @override
  String get id => 'location';
  @override
  String get title => 'Location';
  @override
  String get description => 'Current location and recent history';
  @override
  IconData get icon => Icons.location_on;
  @override
  Widget buildScreen(BuildContext context) => const LocationViewScreen();
}

class LocationViewScreen extends StatelessWidget {
  const LocationViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Location',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Location')),
        body: ApiView<List<LocationPoint>>(
          load: () async {
            final res = await ParentState.instance.api
                .get('/api/location/$deviceId');
            return (res['history'] as List)
                .map((p) => LocationPoint.fromServer(p as Map))
                .whereType<LocationPoint>()
                .toList()
                .reversed
                .toList();
          },
          builder: (context, points, _) {
            if (points.isEmpty) {
              return const EmptyHint(
                  'No location shared yet. It is sent when the child app is '
                  'open and location permission is allowed.');
            }
            final current = points.first;
            return ListView(
              children: [
                Card(
                  margin: const EdgeInsets.all(16),
                  child: ListTile(
                    leading: const Icon(Icons.my_location, size: 36),
                    title: Text(
                        '${current.lat.toStringAsFixed(5)}, ${current.lng.toStringAsFixed(5)}'),
                    subtitle: Text('Current • ${timeAgo(current.time)}'),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Recent history',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final p in points.skip(1))
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(
                        '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}'),
                    trailing: Text(timeAgo(p.time)),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
