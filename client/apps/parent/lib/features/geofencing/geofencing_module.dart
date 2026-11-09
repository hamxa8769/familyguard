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

class GeofencingModule implements FeatureModule {
  @override
  String get id => 'geofencing';
  @override
  FeatureSection get section => FeatureSection.rules;
  @override
  String get title => 'Safe zones';
  @override
  String get description => 'Get alerted on arrive / leave';
  @override
  IconData get icon => Icons.shield_moon_outlined;
  @override
  Widget buildScreen(BuildContext context) => const GeofencingScreen();
}

class _ZonesData {
  _ZonesData(this.zones, this.events, this.lastLocation);
  final List<Map> zones;
  final List<Map> events;
  final LocationPoint? lastLocation;
}

class GeofencingScreen extends StatelessWidget {
  const GeofencingScreen({super.key});

  Future<_ZonesData> _load(String deviceId) async {
    final api = ParentState.instance.api;
    final r = await Future.wait([
      api.get('/api/geofencing/$deviceId'),
      api.get('/api/geofencing/$deviceId/events'),
      api.get('/api/location/$deviceId'),
    ]);
    return _ZonesData(
      List<Map>.from(r[0]['zones'] as List),
      List<Map>.from(r[1]['events'] as List),
      LocationPoint.fromServer(r[2]['current'] as Map?),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Safe zones',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Safe zones')),
        body: ApiView<_ZonesData>(
          load: () => _load(deviceId),
          builder: (context, data, reload) =>
              _ZonesEditor(deviceId: deviceId, data: data, reload: reload),
        ),
      ),
    );
  }
}

/// Tap the map to drop a zone, size it with the slider, name it, save.
class _ZonesEditor extends StatefulWidget {
  const _ZonesEditor(
      {required this.deviceId, required this.data, required this.reload});
  final String deviceId;
  final _ZonesData data;
  final VoidCallback reload;

  @override
  State<_ZonesEditor> createState() => _ZonesEditorState();
}

class _ZonesEditorState extends State<_ZonesEditor> {
  final _map = MapController();
  final _name = TextEditingController();
  LatLng? _draft;
  double _radius = 150;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  LatLng _zonePoint(Map z) =>
      LatLng((z['lat'] as num).toDouble(), (z['lng'] as num).toDouble());

  String _status(Map zone) {
    Map? last;
    for (final e in widget.data.events) {
      if (e['geofenceId'] == zone['id']) last = e;
    }
    if (last == null) return 'No visits yet';
    final at = DateTime.tryParse('${last['at']}');
    final when = at == null ? '' : ' · ${timeAgo(at)}';
    return last['type'] == 'enter' ? 'Inside now$when' : 'Left$when';
  }

  Future<void> _save() async {
    final p = _draft;
    if (p == null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give the zone a name, like Home')));
      return;
    }
    setState(() => _saving = true);
    final ok = await saveWithFeedback(
      context,
      () => ParentState.instance.api.post('/api/geofencing', {
        'deviceId': widget.deviceId,
        'name': name,
        'lat': p.latitude,
        'lng': p.longitude,
        'radiusM': _radius.round(),
      }),
      'Safe zone "$name" added',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _draft = null;
        _name.clear();
      }
    });
    if (ok) widget.reload();
  }

  Future<void> _delete(Map zone) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${zone['name']}?'),
        content: const Text('You won\'t get arrive/leave alerts for it anymore.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await saveWithFeedback(
      context,
      () => ParentState.instance.api.delete('/api/geofencing/zone/${zone['id']}'),
      '${zone['name']} removed',
    );
    if (ok) widget.reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final loc = widget.data.lastLocation;
    final child = loc == null ? null : LatLng(loc.lat, loc.lng);
    final zones = widget.data.zones;

    return ListView(
      padding: const EdgeInsets.all(FgSpace.lg),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(FgSpace.radius),
          child: SizedBox(
            height: 300,
            child: Stack(
              children: [
                FgMap(
                  controller: _map,
                  center: child ??
                      (zones.isEmpty ? null : _zonePoint(zones.first)),
                  onTap: (p) => setState(() => _draft = p),
                  layers: [
                    CircleLayer(circles: [
                      for (final z in zones)
                        CircleMarker(
                          point: _zonePoint(z),
                          radius: (z['radiusM'] as num).toDouble(),
                          useRadiusInMeter: true,
                          color: c.safe.withValues(alpha: 0.15),
                          borderColor: c.safe,
                          borderStrokeWidth: 1.5,
                        ),
                      if (_draft != null)
                        CircleMarker(
                          point: _draft!,
                          radius: _radius,
                          useRadiusInMeter: true,
                          color: c.accent.withValues(alpha: 0.18),
                          borderColor: c.accent,
                          borderStrokeWidth: 2,
                        ),
                    ]),
                    MarkerLayer(markers: [
                      if (child != null)
                        Marker(
                            point: child,
                            width: 36,
                            height: 36,
                            child: const ChildPin()),
                      if (_draft != null)
                        Marker(
                          point: _draft!,
                          width: 32,
                          height: 32,
                          alignment: Alignment.topCenter,
                          child: Icon(Icons.location_on_rounded,
                              color: c.accent, size: 32),
                        ),
                    ]),
                  ],
                ),
                if (_draft == null)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: const Text('Tap the map to place a new zone',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ),
                if (child != null)
                  Positioned(
                    right: 12,
                    bottom: 28,
                    child: FloatingActionButton.small(
                      heroTag: 'zones-center',
                      tooltip: 'Use child\'s location',
                      onPressed: () {
                        _map.move(child, 16);
                        setState(() => _draft = child);
                      },
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: _draft == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: FgSpace.md),
                  child: FgCard(
                    borderColor: c.accent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('New safe zone',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: FgSpace.md),
                        TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                              labelText: 'Name', hintText: 'Home, School…'),
                        ),
                        const SizedBox(height: FgSpace.sm),
                        Row(
                          children: [
                            Text('Radius',
                                style: TextStyle(color: c.textMuted)),
                            Expanded(
                              child: Slider(
                                value: _radius,
                                min: 50,
                                max: 1000,
                                divisions: 19,
                                label: '${_radius.round()} m',
                                onChanged: (v) => setState(() => _radius = v),
                              ),
                            ),
                            SizedBox(
                              width: 56,
                              child: Text('${_radius.round()} m',
                                  textAlign: TextAlign.end,
                                  style: fgNumber(context, 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: FgSpace.sm),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => setState(() => _draft = null),
                              child: const Text('Cancel'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              child: Text(_saving ? 'Saving…' : 'Save zone'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SectionLabel('Your zones'),
        if (zones.isEmpty)
          FgCard(
            child: Text(
                'No safe zones yet. Add Home or School to get an alert when '
                'your child arrives or leaves.',
                style: TextStyle(color: c.textMuted)),
          ),
        for (final z in zones) ...[
          FgCard(
            padding: const EdgeInsets.all(FgSpace.md),
            onTap: () => _map.move(_zonePoint(z), 16),
            child: Row(
              children: [
                IconWell(Icons.shield_moon_outlined, color: c.safe),
                const SizedBox(width: FgSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${z['name']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${z['radiusM']} m · ${_status(z)}',
                          style: TextStyle(color: c.textMuted, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove zone',
                  icon: Icon(Icons.delete_outline_rounded, color: c.textMuted),
                  onPressed: () => _delete(z),
                ),
              ],
            ),
          ),
          const SizedBox(height: FgSpace.sm),
        ],
      ],
    );
  }
}
