import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../feature_module.dart';

/// Parent side of the family agreement: propose rules (one per line),
/// then see whether the child accepted or declined. A declined agreement
/// stays declined until a new one is proposed.
class AgreementModule implements FeatureModule {
  @override
  String get id => 'agreement';
  @override
  String get title => 'Family Agreement';
  @override
  String get description => 'Propose rules and see the child sign-off';
  @override
  IconData get icon => Icons.rule;
  @override
  Widget buildScreen(BuildContext context) => const AgreementScreen();
}

class AgreementScreen extends StatefulWidget {
  const AgreementScreen({super.key});

  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  final _api = ApiClient();
  final _childId = TextEditingController();
  final _rules = TextEditingController();
  FamilyAgreement? _agreement;
  String? _status;

  Future<void> _load() async {
    if (_childId.text.isEmpty) {
      setState(() => _status = 'Enter a child ID first.');
      return;
    }
    try {
      final data = await _api.get('/api/agreement/${_childId.text}');
      setState(() {
        _agreement = data['agreement'] == null
            ? null
            : FamilyAgreement.fromMap(data['agreement'] as Map);
        _status = null;
      });
    } on ApiException catch (e) {
      setState(() => _status = 'Could not load agreement: ${e.message}');
    }
  }

  Future<void> _propose() async {
    if (_childId.text.isEmpty) {
      setState(() => _status = 'Enter a child ID first.');
      return;
    }
    final rules = _rules.text
        .split('\n')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();
    if (rules.isEmpty) {
      setState(() => _status = 'Write at least one rule (one per line).');
      return;
    }
    try {
      await _api.post('/api/agreement', {
        'childId': _childId.text,
        'rules': rules,
      });
      setState(() => _status = 'Agreement proposed — the child can now accept or decline it.');
      await _load();
    } on ApiException catch (e) {
      setState(() => _status = 'Could not propose agreement: ${e.message}');
    }
  }

  @override
  void dispose() {
    _childId.dispose();
    _rules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Agreement')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _childId,
            decoration: const InputDecoration(labelText: 'Child ID'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rules,
            decoration: const InputDecoration(
              labelText: 'Rules (one per line)',
              hintText: 'No phone after 22:00\nHomework before games',
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _propose, child: const Text('Propose agreement')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _load, child: const Text('Load latest agreement')),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!),
          ],
          const SizedBox(height: 8),
          if (_agreement == null)
            const ListTile(title: Text('No agreement proposed yet.'))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: ${_agreement!.status}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final rule in _agreement!.rules)
                      ListTile(
                        leading: const Icon(Icons.rule),
                        title: Text(rule),
                        dense: true,
                      ),
                    if (_agreement!.signedAt != null)
                      Text('Signed: ${_agreement!.signedAt}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
