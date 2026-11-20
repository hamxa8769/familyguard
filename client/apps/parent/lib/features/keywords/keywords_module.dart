import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

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

class KeywordsScreen extends StatelessWidget {
  const KeywordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Keyword Alerts',
      builder: (context, deviceId) {
        // Keyword lists are keyed by child; the device only scopes which
        // child is selected.
        final childId = ParentState.instance.selected?.$1.id ?? '';
        return _KeywordsBody(childId: childId);
      },
    );
  }
}

class _KeywordsBody extends StatefulWidget {
  const _KeywordsBody({required this.childId});

  final String childId;

  @override
  State<_KeywordsBody> createState() => _KeywordsBodyState();
}

class _KeywordsBodyState extends State<_KeywordsBody> {
  ApiClient get _api => ParentState.instance.api;
  final _keywords = TextEditingController();
  final _scanText = TextEditingController();
  KeywordList? _list;
  String? _status;
  List<String> _lastMatched = [];
  // Phase 5: first-load spinner + explicit retry on load failure (this
  // screen is a form, so it keeps its hand-rolled load instead of ApiView).
  bool _loading = false;
  bool _loadFailed = false;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final data = await _api.get('/api/keywords/${widget.childId}');
      if (!mounted) return;
      setState(() {
        _list = KeywordList.fromMap(data as Map);
        _keywords.text = _list!.keywords.join(', ');
        _status = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Could not load keywords: ${e.message}';
        _loadFailed = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final keywords = _keywords.text
        .split(',')
        .map((k) => k.trim())
        .where((k) => k.isNotEmpty)
        .toList();
    try {
      await _api.post('/api/keywords/${widget.childId}', {'keywords': keywords});
      if (!mounted) return;
      setState(() => _status = 'Keyword list saved.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Could not save keywords: ${e.message}');
    }
  }

  Future<void> _scan() async {
    if (_scanText.text.isEmpty) {
      setState(() => _status = 'Enter some text to scan.');
      return;
    }
    try {
      final data = await _api.post('/api/keywords/${widget.childId}/scan', {
        'text': _scanText.text,
        'source': 'manual_test',
      });
      if (!mounted) return;
      setState(() {
        _lastMatched = (data['matched'] as List? ?? []).map((m) => m.toString()).toList();
        _status = data['alertCreated'] == true
            ? 'Match found — an alert was created.'
            : 'No keywords matched.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Scan failed: ${e.message}');
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keywords.dispose();
    _scanText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keyword Alerts')),
      body: _loading && _list == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Simple keyword list only. Messages that contain one of these '
                    'words raise an alert. There is no sentiment analysis and no '
                    'ML model — the list below is the whole mechanism.',
                  ),
                  const SizedBox(height: 12),
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
                  if (_loadFailed) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _load, child: const Text('Try again')),
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
            ),
    );
  }
}
