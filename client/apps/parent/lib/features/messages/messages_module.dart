import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/share_file.dart';
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

/// Number matching for display names: strip spaces, dashes, brackets and
/// dots; keep a leading + (same rule as the server).
String normaliseNumber(String value) =>
    value.replaceAll(RegExp(r'[\s\-().]'), '');

/// One SMS conversation: grouped by thread id when present, otherwise by
/// normalised address.
class Conversation {
  Conversation({
    required this.key,
    required this.address,
    required this.threadId,
    required this.contactName,
    required this.messages,
  });

  final String key;
  final String address;
  final int? threadId;
  final String? contactName;

  /// Newest first.
  final List<SmsMessage> messages;

  String get displayName => contactName ?? address;
  int get count => messages.length;
  SmsMessage get last => messages.first;
}

/// Synced SMS, contacts and call log for one device (GET /api/comms/:id).
class CommsData {
  CommsData(this.sms, this.contacts, this.calls,
      {this.total = 0, this.limit = 200, this.offset = 0});
  final List<SmsMessage> sms;
  final List<ContactEntry> contacts;
  final List<CallLogEntry> calls;

  /// Filtered SMS count on the server (the paginated list); contacts and
  /// calls are returned in full (filtered).
  final int total;
  final int limit;
  final int offset;

  static Future<CommsData> load(
    String deviceId, {
    String? q,
    int? type,
    String? address,
    int limit = 200,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (q != null && q.isNotEmpty) 'q': q,
      if (type != null) 'type': '$type',
      if (address != null && address.isNotEmpty) 'address': address,
    };
    final qs = query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final res = await ParentState.instance.api.get('/api/comms/$deviceId?$qs');
    List<Map> list(String key) => List<Map>.from(res[key] as List? ?? const []);
    return CommsData(
      list('sms').map(SmsMessage.fromMap).toList()
        ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis)),
      list('contacts').map(ContactEntry.fromMap).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      list('callLog').map(CallLogEntry.fromMap).toList()
        ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis)),
      total: (res['total'] as num?)?.toInt() ?? 0,
      limit: (res['limit'] as num?)?.toInt() ?? limit,
      offset: (res['offset'] as num?)?.toInt() ?? offset,
    );
  }

  /// Contact display name for a number, matched on the normalised number.
  String? contactNameFor(String number) {
    final norm = normaliseNumber(number);
    if (norm.isEmpty) return null;
    for (final c in contacts) {
      if (normaliseNumber(c.number) == norm) return c.name;
    }
    return null;
  }

  /// SMS grouped into conversations, newest conversation first.
  List<Conversation> get conversations {
    final groups = <String, List<SmsMessage>>{};
    for (final m in sms) {
      final key = m.threadId != null
          ? 't:${m.threadId}'
          : 'a:${normaliseNumber(m.address)}';
      groups.putIfAbsent(key, () => []).add(m);
    }
    final out = <Conversation>[];
    for (final entry in groups.entries) {
      final messages = entry.value
        ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis));
      final first = messages.first;
      out.add(Conversation(
        key: entry.key,
        address: first.address,
        threadId: first.threadId,
        contactName: contactNameFor(first.address),
        messages: messages,
      ));
    }
    out.sort((a, b) => b.last.dateMillis.compareTo(a.last.dateMillis));
    return out;
  }
}

class MessagesViewScreen extends StatefulWidget {
  const MessagesViewScreen({super.key});

  @override
  State<MessagesViewScreen> createState() => _MessagesViewScreenState();
}

class _MessagesViewScreenState extends State<MessagesViewScreen> {
  String _query = '';
  int _limit = 200;
  CommsData? _lastData;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _export(String deviceId, String type, String format) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ParentState.instance.api.getBytes(
        '/api/comms/$deviceId/export?format=$format&type=$type',
      );
      if (!mounted) return;
      final data = _lastData;
      final counts = data == null
          ? ''
          : ' (${data.total} SMS, ${data.contacts.length} contacts, '
              '${data.calls.length} calls retained on the server)';
      await saveAndShareBytes(
        context,
        bytes,
        'familyguard-comms-$deviceId-$type.$format',
        mimeType: format == 'csv' ? 'text/csv' : 'application/json',
      );
      messenger.showSnackBar(SnackBar(content: Text('Exported$counts')));
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export: ${e.message}')),
      );
    }
  }

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
            actions: [
              PopupMenuButton<(String, String)>(
                icon: const Icon(Icons.download),
                tooltip: 'Export',
                onSelected: (choice) => _export(deviceId, choice.$1, choice.$2),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: ('sms', 'csv'),
                      child: Text('Messages (CSV)')),
                  PopupMenuItem(
                      value: ('contacts', 'csv'),
                      child: Text('Contacts (CSV)')),
                  PopupMenuItem(
                      value: ('calls', 'csv'), child: Text('Calls (CSV)')),
                  PopupMenuItem(
                      value: ('all', 'json'),
                      child: Text('Everything (JSON)')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search messages, contacts, calls…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => setState(() => _query = v.trim()),
                ),
              ),
              Expanded(
                child: ApiView<CommsData>(
                  // A new key forces a fresh load when the query/limit changes.
                  key: ValueKey('$_query|$_limit'),
                  load: () => CommsData.load(
                    deviceId,
                    q: _query.isEmpty ? null : _query,
                    limit: _limit,
                  ),
                  builder: (context, data, _) {
                    _lastData = data;
                    return TabBarView(
                      children: [
                        _ConversationList(
                          data: data,
                          onLoadMore: data.sms.length < data.total
                              ? () => setState(() => _limit += 200)
                              : null,
                        ),
                        data.contacts.isEmpty
                            ? const EmptyHint('No contacts shared yet.')
                            : ListView(
                                children: [
                                  for (final c in data.contacts)
                                    ListTile(
                                      leading: const CircleAvatar(
                                          child: Icon(Icons.person)),
                                      title: Text(c.name),
                                      subtitle: Text(c.number),
                                    ),
                                ],
                              ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.data, this.onLoadMore});
  final CommsData data;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final conversations = data.conversations;
    if (conversations.isEmpty) {
      return const EmptyHint('No messages shared yet (Android only, '
          'after the child allows SMS access).');
    }
    return ListView(
      children: [
        for (final conv in conversations)
          ListTile(
            leading: CircleAvatar(
              child: Icon(conv.last.isIncoming
                  ? Icons.call_received
                  : Icons.call_made),
            ),
            title: Text(conv.displayName),
            subtitle: Text(
              conv.last.body,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeAgo(conv.last.date)),
                Text('${conv.count}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ConversationScreen(conversation: conv),
            )),
          ),
        if (onLoadMore != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: onLoadMore,
              child: Text('Load more (${data.sms.length} of ${data.total})'),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${data.total} message${data.total == 1 ? '' : 's'} retained on the server',
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// One conversation, oldest message at the top, bubbles left/right.
class ConversationScreen extends StatelessWidget {
  const ConversationScreen({super.key, required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final messages = [...conversation.messages]
      ..sort((a, b) => a.dateMillis.compareTo(b.dateMillis));
    return Scaffold(
      appBar: AppBar(title: Text(conversation.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final m in messages)
            Align(
              alignment:
                  m.isIncoming ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                decoration: BoxDecoration(
                  color: m.isIncoming
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.body),
                    const SizedBox(height: 4),
                    Text(
                      timeAgo(m.date),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
