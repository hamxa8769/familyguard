import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../feature_module.dart';

/// Parent side of AI keyword alerts.
///
/// This is a simple keyword list with substring matching on messages the
/// child app already syncs (SMS). There is NO sentiment analysis and NO
/// ML model — the screen says so, and the keyword list is the whole
/// mechanism. A match creates an alert the parent sees in Alerts.
class KeywordsModule implements FeatureModule {
  @override
  String get id => 'keywords';
  @override
  String get title => 'Keyword Alerts';
  @override
  String get description => 'Simple keyword list — alerts on matching messages (no ML model)';
  @override
  IconData get icon => Icons.key;
  @override
  FeatureSection get section => FeatureSection.alerts;
  @override
  Widget buildScreen(BuildContext context) => const KeywordsScreen();
}

class KeywordsScreen extends StatefulWidget {
  const KeywordsScreen({super.key});

  @override
  State<KeywordsScreen> createState() => _KeywordsScreenState();
}

class _KeywordsScreenState extends State<KeywordsScreen> {
  final _api = ApiClient();
  final _childId = TextEditingController();
  final _keywords = TextEditingController();
  final _scanText = TextEditingController();
  KeywordList? _list;
  String? _status;
  List<String> _lastMatched = [];

  Future<void> _load() async {
    if (_childId.text.isEmpty) {
      setState(() => _status = 'Enter a child ID first.');
      return;
    }
    try {
      final data = await _api.get('/api/keywords/${_childId.text}');
      setState(() {
        _list = KeywordList.fromMap(data as Map);
        _keywords.text = _list!.keywords.join(', ');
        _status = null;
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Could not load keywords: ${e.message}');
    }
  }

  Future<void> _save() async {
    if (_childId.text.isEmpty) {
      setState(() => _status = 'Enter a child ID first.');
      return;
    }
    final keywords = _keywords.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    try {
      await _api.post('/api/keywords/${_childId.text}', {'keywords': keywords});
      setState(() => _status = 'Keyword list saved.');
      await _load();
    } on ApiException catch (e) {
      setState(() => _status = 'Could not save keywords: ${e.message}');
    }
  }

  Future<void> _scan() async {
    if (_childId.text.isEmpty || _scanText.text.isEmpty) {
      setState(() => _status = 'Enter a child ID and some text to scan.');
      return;
    }
    try {
      final data = await _api.post('/api/keywords/${_childId.text}/scan', {
        'text': _scanText.text,
        'source': 'manual_test',
      });
      setState(() {
        _lastMatched = (data['matched'] as List? ?? []).map((m) => m.toString()).toList();
        _status = data['alertCreated'] == true
            ? 'Match found — an alert was created.'
            : 'No keywords matched.';
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Scan failed: ${e.message}');
    }
  }

  @override
  void dispose() {
    _childId.dispose();
    _keywords.dispose();
    _scanText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keyword Alerts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Simple keyword list only. Messages that contain one of these '
            'words raise an alert. There is no sentiment analysis and no '
            'ML model — the list below is the whole mechanism.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _childId,
            decoration: const InputDecoration(labelText: 'Child ID'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _keywords,
            decoration: const InputDecoration(
              labelText: 'Keywords (comma-separated)',
              hintText: 'bully, meet me, secret',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('Save keyword list')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _load, child: const Text('Load current list')),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!),
          ],
          if (_lastMatched.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Matched: ${_lastMatched.join(', ')}'),
          ],
          const SizedBox(height: 16),
          Text('Test a scan', style: Theme.of(context).textTheme.titleMedium),
          TextField(
            controller: _scanText,
            decoration: const InputDecoration(labelText: 'Text to scan'),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _scan, child: const Text('Scan text')),
        ],
      ),
    );
  }
}
