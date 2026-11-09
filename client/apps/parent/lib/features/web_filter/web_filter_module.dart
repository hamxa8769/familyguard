import 'package:flutter/material.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

class WebFilterModule implements FeatureModule {
  @override
  String get id => 'web_filter';
  @override
  FeatureSection get section => FeatureSection.rules;
  @override
  String get title => 'Web Filter';
  @override
  String get description => 'Block unsafe websites';
  @override
  IconData get icon => Icons.public_off;
  @override
  Widget buildScreen(BuildContext context) => const WebFilterScreen();
}

class WebFilterScreen extends StatelessWidget {
  const WebFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Web Filter',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Web Filter')),
        body: ApiView<List<String>>(
          load: () async {
            final res = await ParentState.instance.api
                .get('/api/webfilter/$deviceId');
            return List<String>.from(res['blockedDomains'] as List);
          },
          builder: (context, domains, _) =>
              _DomainList(deviceId: deviceId, initial: domains),
        ),
      ),
    );
  }
}

class _DomainList extends StatefulWidget {
  const _DomainList({required this.deviceId, required this.initial});
  final String deviceId;
  final List<String> initial;

  @override
  State<_DomainList> createState() => _DomainListState();
}

class _DomainListState extends State<_DomainList> {
  late final List<String> _domains = [...widget.initial];
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// "https://www.Example.com/path" → "example.com".
  String _normalise(String input) {
    var d = input.trim().toLowerCase();
    d = d.replaceFirst(RegExp(r'^[a-z]+://'), '');
    d = d.split('/').first;
    if (d.startsWith('www.')) d = d.substring(4);
    return d;
  }

  Future<void> _save(List<String> next, String message) async {
    final ok = await saveWithFeedback(
      context,
      () => ParentState.instance.api.put(
          '/api/webfilter/${widget.deviceId}', {'blockedDomains': next}),
      message,
    );
    if (ok) {
      setState(() {
        _domains
          ..clear()
          ..addAll(next);
      });
    }
  }

  void _add() {
    final d = _normalise(_controller.text);
    if (d.isEmpty || !d.contains('.') || _domains.contains(d)) return;
    _controller.clear();
    _save([..._domains, d], '$d blocked');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Add domain to block',
                    hintText: 'example.com',
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              IconButton(icon: const Icon(Icons.add), onPressed: _add),
            ],
          ),
        ),
        if (_domains.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No blocked websites yet.'),
          ),
        for (final d in _domains)
          ListTile(
            leading: const Icon(Icons.link_off),
            title: Text(d),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _save(
                  _domains.where((x) => x != d).toList(), '$d unblocked'),
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Subdomains are included (blocking example.com also blocks '
            'm.example.com). Filtering in the device browser is not enforced yet.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
