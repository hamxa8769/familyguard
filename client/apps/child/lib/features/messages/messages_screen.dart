import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'comms_collector.dart';

/// Child-side view of the messages & contacts that are shared with the parent.
/// Shown openly so the child knows exactly what is visible (transparency).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _collector = CommsCollector();
  List<SmsMessage> _sms = [];
  List<ContactEntry> _contacts = [];
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
    final sms = await _collector.sms();
    final contacts = await _collector.contacts();
    setState(() {
      _sms = sms;
      _contacts = contacts;
      _needsPermission = false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages & Contacts'),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
          bottom: const TabBar(tabs: [Tab(text: 'Messages'), Tab(text: 'Contacts')]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _needsPermission
                ? _permissionPrompt()
                : TabBarView(children: [_smsList(), _contactsList()]),
      ),
    );
  }

  Widget _permissionPrompt() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sms, size: 56),
          const SizedBox(height: 16),
          const Text('Messages & Contacts access',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Your parent/guardian can view your SMS and contacts through '
            'FamilyGuard. Grant access so this works. You can see here exactly '
            'what is shared, and you can turn it off in settings any time.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await _collector.requestPermission();
            },
            child: const Text('Grant access'),
          ),
          TextButton(onPressed: _load, child: const Text('I\'ve granted it')),
        ],
      ),
    );
  }

  Widget _smsList() {
    if (_sms.isEmpty) return const Center(child: Text('No messages.'));
    return ListView(
      children: [
        for (final m in _sms)
          ListTile(
            leading: Icon(m.isIncoming ? Icons.call_received : Icons.call_made),
            title: Text(m.address),
            subtitle: Text(m.body),
            trailing: Text(
              '${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}',
            ),
          ),
      ],
    );
  }

  Widget _contactsList() {
    if (_contacts.isEmpty) return const Center(child: Text('No contacts.'));
    return ListView(
      children: [
        for (final c in _contacts)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(c.name),
            subtitle: Text(c.number),
          ),
      ],
    );
  }
}
