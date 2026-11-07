import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'location_collector.dart';

/// Child-side view: shows the current location that is shared with the parent.
/// Location was always part of the consent notice and the transparency screen.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _collector = LocationCollector();
  LocationPoint? _point;
  bool _loading = true;
  bool _needsPermission = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (!await _collector.hasPermission()) {
      setState(() {
        _needsPermission = true;
        _loading = false;
      });
      return;
    }
    final point = await _collector.current();
    setState(() {
      _point = point;
      _needsPermission = false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Sharing'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _needsPermission
              ? _permissionPrompt()
              : _body(),
    );
  }

  Widget _permissionPrompt() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 56),
          const SizedBox(height: 16),
          const Text('Location access needed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Your parent/guardian can see this device\'s location through '
            'FamilyGuard. Grant access so this works. You can always review here '
            'what is shared.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _collector.requestPermission(),
            child: const Text('Grant access'),
          ),
          TextButton(onPressed: _load, child: const Text('I\'ve granted it')),
        ],
      ),
    );
  }

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Your location is shared with your parent/guardian while '
              'FamilyGuard is active.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        const ListTile(
          leading: Icon(Icons.my_location),
          title: Text('Sharing status'),
          trailing: Text('ON'),
        ),
        ListTile(
          leading: const Icon(Icons.place_outlined),
          title: const Text('Current location'),
          subtitle: Text(_point == null
              ? 'Not available yet'
              : '${_point!.lat.toStringAsFixed(5)}, ${_point!.lng.toStringAsFixed(5)}'),
          trailing: _point == null
              ? null
              : Text(
                  '${_point!.time.hour.toString().padLeft(2, '0')}:${_point!.time.minute.toString().padLeft(2, '0')}'),
        ),
      ],
    );
  }
}
