import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

class GeofencingModule implements FeatureModule {
  @override
  String get id => 'geofencing';
  @override
  FeatureSection get section => FeatureSection.rules;
  @override
  String get title => 'Safe Zones';
  @override
  String get description => 'Alerts when entering/leaving a zone';
  @override
  IconData get icon => Icons.my_location;
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
    final zones = await api.get('/api/geofencing/$deviceId');
    final events = await api.get('/api/geofencing/$deviceId/events');
    final loc = await api.get('/api/location/$deviceId');
    return _ZonesData(
      List<Map>.from(zones['zones'] as List),
      List<Map>.from(events['events'] as List),
      LocationPoint.fromServer(loc['current'] as Map?),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Safe Zones',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Safe Zones')),
        body: ApiView<_ZonesData>(
          load: () => _load(deviceId),
          builder: (context, data, reload) =>
              _Zones(deviceId: deviceId, data: data, reload: reload),
        ),
      ),
    );
  }
}

class _Zones extends StatelessWidget {
  const _Zones(
      {required this.deviceId, required this.data, required this.reload});
  final String deviceId;
  final _ZonesData data;
  final VoidCallback reload;

  String _status(Map zone) {
    final last = data.events.lastWhere(
      (e) => e['geofenceId'] == zone['id'],
      orElse: () => const {},
    );
    if (last.isEmpty) return 'No events yet';
    final at = DateTime.tryParse('${last['at']}');
    final when = at == null ? '' : ' ${timeAgo(at)}';
    return last['type'] == 'enter' ? 'Entered$when' : 'Left$when';
  }

  Future<void> _addZone(BuildContext context) async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AddZoneDialog(current: data.lastLocation),
    );
    if (created == null || !context.mounted) return;
    final ok = await saveWithFeedback(
      context,
      () => ParentState.instance.api
          .post('/api/geofencing', {'deviceId': deviceId, ...created}),
      'Safe zone "${created['name']}" added',
    );
    if (ok) reload();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (data.zones.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No safe zones yet. Add Home or School to get an '
                    'alert when your child arrives or leaves.'),
              ),
            for (final z in data.zones)
              ListTile(
                leading: const Icon(Icons.radio_button_checked),
                title: Text('${z['name']}'),
                subtitle: Text('Radius: ${z['radiusM']} m'),
                trailing: Text(_status(z)),
              ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _addZone(context),
            icon: const Icon(Icons.add_location_alt),
            label: const Text('Add zone'),
          ),
        ),
      ],
    );
  }
}

class _AddZoneDialog extends StatefulWidget {
  const _AddZoneDialog({required this.current});
  final LocationPoint? current;

  @override
  State<_AddZoneDialog> createState() => _AddZoneDialogState();
}

class _AddZoneDialogState extends State<_AddZoneDialog> {
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _radius = TextEditingController(text: '150');
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _lat, _lng, _radius]) {
      c.dispose();
    }
    super.dispose();
  }

  void _useCurrent() {
    final p = widget.current;
    if (p == null) return;
    _lat.text = p.lat.toStringAsFixed(6);
    _lng.text = p.lng.toStringAsFixed(6);
  }

  void _submit() {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final radius = int.tryParse(_radius.text.trim()) ?? 150;
    if (_name.text.trim().isEmpty ||
        lat == null ||
        lng == null ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      setState(() => _error = 'Enter a name and valid coordinates');
      return;
    }
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'lat': lat,
      'lng': lng,
      'radiusM': radius.clamp(50, 5000),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add safe zone'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration:
                  const InputDecoration(labelText: 'Name (e.g. Home)'),
            ),
            TextField(
              controller: _lat,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Latitude'),
            ),
            TextField(
              controller: _lng,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Longitude'),
            ),
            TextField(
              controller: _radius,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Radius (m)'),
            ),
            if (widget.current != null)
              TextButton.icon(
                onPressed: _useCurrent,
                icon: const Icon(Icons.my_location),
                label: const Text('Use child\'s current location'),
              ),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
