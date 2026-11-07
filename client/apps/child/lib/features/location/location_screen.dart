import 'package:flutter/material.dart';

/// Child-side view: shows that location is being shared and the last point.
/// Real GPS reporting will use geolocator + a background reporter (TODO native).
class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Sharing')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Your location is shared with your parent/guardian while '
                'FamilyGuard is active. You can see here what is shared.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ListTile(
            leading: Icon(Icons.my_location),
            title: Text('Sharing status'),
            trailing: Text('ON'),
          ),
          const ListTile(
            leading: Icon(Icons.place_outlined),
            title: Text('Last shared location'),
            subtitle: Text('Home • 31.5204, 74.3587'),
          ),
        ],
      ),
    );
  }
}
