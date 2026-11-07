import 'package:flutter/material.dart';
import '../../feature_module.dart';

class MessagesModule implements FeatureModule {
  @override
  String get id => 'messages';
  @override
  String get title => 'Messages & Contacts';
  @override
  String get description => 'View the child\'s SMS and contacts';
  @override
  IconData get icon => Icons.sms;
  @override
  Widget buildScreen(BuildContext context) => const MessagesViewScreen();
}

class MessagesViewScreen extends StatelessWidget {
  const MessagesViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample data; real data from GET /api/comms/:deviceId (synced from child).
    const sms = [
      ('+92 300 1234567', 'Beta ghar kab aao ge?', '14:05', true),
      ('+92 301 7654321', 'Kal milte hain', '13:20', false),
      ('+92 42 111222333', 'Your result is ready', 'Yesterday', true),
    ];
    const contacts = [
      ('Ammi', '+92 300 1234567'),
      ('School', '+92 42 111222333'),
      ('Best Friend', '+92 301 7654321'),
    ];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages & Contacts'),
          bottom: const TabBar(tabs: [Tab(text: 'Messages'), Tab(text: 'Contacts')]),
        ),
        body: TabBarView(
          children: [
            ListView(
              children: [
                for (final (addr, body, time, incoming) in sms)
                  ListTile(
                    leading: Icon(incoming ? Icons.call_received : Icons.call_made),
                    title: Text(addr),
                    subtitle: Text(body),
                    trailing: Text(time),
                  ),
              ],
            ),
            ListView(
              children: [
                for (final (name, number) in contacts)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(name),
                    subtitle: Text(number),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
