import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../messages/comms_collector.dart';

/// Child-side view of the call history shared with the parent (transparency).
class CallLogScreen extends StatefulWidget {
  const CallLogScreen({super.key});
  @override
  State<CallLogScreen> createState() => _CallLogScreenState();
}

class _CallLogScreenState extends State<CallLogScreen> {
  final _collector = CommsCollector();
  List<CallLogEntry> _calls = [];
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
    final calls = await _collector.callLog();
    setState(() {
      _calls = calls;
      _needsPermission = false;
      _loading = false;
    });
  }

  IconData _iconFor(int type) => switch (type) {
        2 => Icons.call_made,
        3 => Icons.call_missed,
        _ => Icons.call_received,
      };

  String _duration(int seconds) {
    if (seconds <= 0) return '—';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Call Log'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _needsPermission
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.call, size: 56),
                      const SizedBox(height: 16),
                      const Text('Call log access needed',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'Your parent/guardian can see your call history through '
                        'FamilyGuard. Grant access so this works. You can always '
                        'review here what is shared.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => _collector.requestPermission(),
                        child: const Text('Grant access'),
                      ),
                      TextButton(
                          onPressed: _load,
                          child: const Text('I\'ve granted it')),
                    ],
                  ),
                )
              : _calls.isEmpty
                  ? const Center(child: Text('No calls.'))
                  : ListView(
                      children: [
                        for (final call in _calls)
                          ListTile(
                            leading: Icon(_iconFor(call.type)),
                            title: Text(call.number),
                            subtitle: Text(call.typeLabel),
                            trailing: Text(_duration(call.durationSeconds)),
                          ),
                      ],
                    ),
    );
  }
}
