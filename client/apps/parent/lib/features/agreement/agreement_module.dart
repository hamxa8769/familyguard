import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

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
  FeatureSection get section => FeatureSection.family;
  @override
  Widget buildScreen(BuildContext context) => const AgreementScreen();
}

class AgreementScreen extends StatelessWidget {
  const AgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DeviceScoped(
      title: 'Family Agreement',
      builder: (context, deviceId) {
        // The agreement is keyed by child, so use the selected child's id
        // (the device only scopes which child is selected).
        final childId = ParentState.instance.selected?.$1.id ?? '';
        return _AgreementBody(childId: childId);
      },
    );
  }
}

class _AgreementBody extends StatefulWidget {
  const _AgreementBody({required this.childId});

  final String childId;

  @override
  State<_AgreementBody> createState() => _AgreementBodyState();
}

class _AgreementBodyState extends State<_AgreementBody> {
  ApiClient get _api => ParentState.instance.api;
  final _rules = TextEditingController();
  FamilyAgreement? _agreement;
  String? _status;
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
      final data = await _api.get('/api/agreement/${widget.childId}');
      if (!mounted) return;
      setState(() {
        _agreement = data['agreement'] == null
            ? null
            : FamilyAgreement.fromMap(data['agreement'] as Map);
        _status = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Could not load agreement: ${e.message}';
        _loadFailed = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _propose() async {
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
        'childId': widget.childId,
        'rules': rules,
      });
      if (!mounted) return;
      setState(() => _status = 'Agreement proposed — the child can now accept or decline it.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Could not propose agreement: ${e.message}');
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rules.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Agreement')),
      body: _loading && _agreement == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
                  if (_loadFailed) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _load, child: const Text('Try again')),
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
            ),
    );
  }
}
