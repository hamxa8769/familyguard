import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

class MessagesModule implements FeatureModule {
  @override
  String get id => 'messages';
  @override
  FeatureSection get section => FeatureSection.activity;
  @override
  String get title => 'Messages & Contacts';
  @override
  String get description => 'View the child\'s SMS and contacts';
  @override
  IconData get icon => Icons.sms;
  @override
  Widget buildScreen(BuildContext context) => const MessagesViewScreen();
}

/// Synced SMS, contacts and call log for one device (GET /api/comms/:id).
class CommsData {
  CommsData(this.sms, this.contacts, this.calls);
  final List<SmsMessage> sms;
  final List<ContactEntry> contacts;
  final List<CallLogEntry> calls;

  static Future<CommsData> load(String deviceId) async {
    final res = await ParentState.instance.api.get('/api/comms/$deviceId');
    List<Map> list(String key) => List<Map>.from(res[key] as List? ?? const []);
    return CommsData(
      list('sms').map(SmsMessage.fromMap).toList()
        ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis)),
      list('contacts').map(ContactEntry.fromMap).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      list('callLog').map(CallLogEntry.fromMap).toList()
        ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis)),
    );
  }
}

class MessagesViewScreen extends StatelessWidget {
  const MessagesViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Messages & Contacts',
      builder: (context, deviceId) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Messages & Contacts'),
            bottom: const TabBar(
                tabs: [Tab(text: 'Messages'), Tab(text: 'Contacts')]),
          ),
          body: ApiView<CommsData>(
            load: () => CommsData.load(deviceId),
            builder: (context, data, _) => TabBarView(
              children: [
                data.sms.isEmpty
                    ? const EmptyHint('No messages shared yet (Android only, '
                        'after the child allows SMS access).')
                    : ListView(
                        children: [
                          for (final m in data.sms)
                            ListTile(
                              leading: Icon(m.isIncoming
                                  ? Icons.call_received
                                  : Icons.call_made),
                              title: Text(m.address),
                              subtitle: Text(m.body),
                              trailing: Text(timeAgo(m.date)),
                            ),
                        ],
                      ),
                data.contacts.isEmpty
                    ? const EmptyHint('No contacts shared yet.')
                    : ListView(
                        children: [
                          for (final c in data.contacts)
                            ListTile(
                              leading:
                                  const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(c.name),
                              subtitle: Text(c.number),
                            ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
