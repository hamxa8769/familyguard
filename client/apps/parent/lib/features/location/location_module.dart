import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';
import '../../theme/app_theme.dart';
import '../../ui/fg_map.dart';
import '../../ui/fg_widgets.dart';

class LocationModule implements FeatureModule {
  @override
  String get id => 'location';
  @override
  FeatureSection get section => FeatureSection.activity;
  @override
  String get title => 'Location';
  @override
  String get description => 'Live position, trail and safe zones';
  @override
  IconData get icon => Icons.location_on_outlined;
  @override
  Widget buildScreen(BuildContext context) => const LocationViewScreen();
}

class _LocData {
  _LocData(this.points, this.zones);
  final List<LocationPoint> points; // newest first
  final List<Map> zones;
}

class LocationViewScreen extends StatelessWidget {
  const LocationViewScreen({super.key});

  Future<_LocData> _load(String deviceId) async {
    final api = ParentState.instance.api;
    final r = await Future.wait([
      api.get('/api/location/$deviceId'),
      api.get('/api/geofencing/$deviceId'),
    ]);
    final points = (r[0]['history'] as List)
        .map((p) => LocationPoint.fromServer(p as Map))
        .whereType<LocationPoint>()
        .toList()
        .reversed
        .toList();
    return _LocData(points, List<Map>.from(r[1]['zones'] as List));
  }

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Location',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Location')),
        body: ApiView<_LocData>(
          load: () => _load(deviceId),
          builder: (context, data, _) => _LocationView(data: data),
        ),
      ),
    );
  }
}

class _LocationView extends StatelessWidget {
  const _LocationView({required this.data});
  final _LocData data;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    if (data.points.isEmpty) {
      return const EmptyHint(
          'No location shared yet. It is sent when the child app is open and '
          'location permission is allowed.');
    }
    final current = data.points.first;
    final here = LatLng(current.lat, current.lng);
    final trail = [for (final p in data.points) LatLng(p.lat, p.lng)];

    return ListView(
      padding: const EdgeInsets.all(FgSpace.lg),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(FgSpace.radius),
          child: SizedBox(
            height: 320,
            child: FgMap(
              center: here,
              fitPoints: trail.length > 1 ? trail : null,
              layers: [
                CircleLayer(circles: [
                  for (final z in data.zones)
                    CircleMarker(
                      point: LatLng((z['lat'] as num).toDouble(),
                          (z['lng'] as num).toDouble()),
                      radius: (z['radiusM'] as num).toDouble(),
                      useRadiusInMeter: true,
                      color: c.safe.withValues(alpha: 0.15),
                      borderColor: c.safe,
                      borderStrokeWidth: 1.5,
                    ),
                ]),
                if (trail.length > 1)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: trail,
                      strokeWidth: 3,
                      color: c.accent.withValues(alpha: 0.6),
                    ),
                  ]),
                MarkerLayer(markers: [
                  for (final p in data.points.skip(1).take(20))
                    Marker(
                      point: LatLng(p.lat, p.lng),
                      width: 8,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.accent.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  Marker(
                    point: here,
                    width: 40,
                    height: 40,
                    child: const ChildPin(),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: FgSpace.md),
        FgCard(
          child: Row(
            children: [
              const IconWell(Icons.my_location_rounded),
              const SizedBox(width: FgSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current position',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${current.lat.toStringAsFixed(5)}, ${current.lng.toStringAsFixed(5)}',
                      style: fgNumber(context, 13,
                          weight: FontWeight.w400, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Text(timeAgo(current.time),
                  style: TextStyle(color: c.textMuted, fontSize: 13)),
            ],
          ),
        ),
        if (data.points.length > 1) ...[
          const SectionLabel('Recent trail'),
          FgCard(
            padding: const EdgeInsets.symmetric(vertical: FgSpace.xs),
            child: Column(
              children: [
                for (final p in data.points.skip(1).take(15))
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.circle, size: 10, color: c.accent),
                    title: Text(
                      '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}',
                      style: fgNumber(context, 13, weight: FontWeight.w400),
                    ),
                    trailing: Text(timeAgo(p.time),
                        style: TextStyle(color: c.textMuted, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
