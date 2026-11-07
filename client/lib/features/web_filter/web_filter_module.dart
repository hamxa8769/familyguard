import 'package:flutter/material.dart';
import '../feature_module.dart';

class WebFilterModule implements FeatureModule {
  @override
  String get id => 'web_filter';
  @override
  String get title => 'Web Filter';
  @override
  String get description => 'Block unsafe websites';
  @override
  IconData get icon => Icons.public_off;
  @override
  Widget buildScreen(BuildContext context) => const WebFilterScreen();
}

class WebFilterScreen extends StatefulWidget {
  const WebFilterScreen({super.key});
  @override
  State<WebFilterScreen> createState() => _WebFilterScreenState();
}

class _WebFilterScreenState extends State<WebFilterScreen> {
  final _domains = <String>['example-adult.com', 'gambling-site.com'];
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Web Filter')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Add domain to block',
                      hintText: 'example.com',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    if (_controller.text.trim().isEmpty) return;
                    setState(() {
                      _domains.add(_controller.text.trim());
                      _controller.clear();
                    });
                    // TODO: PUT /api/webfilter/:deviceId { blockedDomains }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final d in _domains)
                  ListTile(
                    leading: const Icon(Icons.link_off),
                    title: Text(d),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _domains.remove(d)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
