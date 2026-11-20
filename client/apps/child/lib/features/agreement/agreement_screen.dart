import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Child side of the family agreement: the parent proposes rules, the
/// child reads them and signs (accept) or declines. The decision is
/// recorded with the time — a declined agreement stays declined until a
/// new one is proposed.
class AgreementScreen extends StatefulWidget {
  const AgreementScreen({super.key, required this.childId});

  /// Until child accounts land, the registered deviceId is used as the
  /// child id (same stand-in as the other child screens).
  final String childId;

  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  final _api = ApiClient();
  FamilyAgreement? _agreement;
  String? _status;
  bool _loading = true;

  Future<void> _load() async {
    if (widget.childId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await _api.get('/api/agreement/${widget.childId}');
      setState(() {
        _agreement = data['agreement'] == null
            ? null
            : FamilyAgreement.fromMap(data['agreement'] as Map);
        _status = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _status = 'Could not load agreement: ${e.message}';
        _loading = false;
      });
    }
  }

  Future<void> _sign(bool accepted) async {
    final agreement = _agreement;
    if (agreement == null) return;
    try {
      await _api.post('/api/agreement/${agreement.id}/sign', {
        'accepted': accepted,
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accepted ? 'Agreement accepted.' : 'Agreement declined.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not sign: ${e.message}')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Agreement')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.childId.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('This device is not registered yet.'),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'The rules your family agreed on together. Both you '
                        'and your parent see the same text and the same '
                        'decision.',
                      ),
                      const SizedBox(height: 12),
                      if (_status != null) Text(_status!),
                      if (_agreement == null)
                        const ListTile(
                          title: Text('No agreement proposed yet.'),
                        )
                      else ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status: ${_agreement!.status}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                        if (_agreement!.isProposed) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              FilledButton(
                                onPressed: () => _sign(true),
                                child: const Text('I accept these rules'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _sign(false),
                                child: const Text('I decline'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }
}
