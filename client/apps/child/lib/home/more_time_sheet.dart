import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:familyguard_core/ui.dart';

/// Bottom sheet: child asks the parent for extra minutes today.
/// Returns true if a request was sent.
Future<bool> showMoreTimeSheet(BuildContext context) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _MoreTimeSheet(),
  );
  return sent == true;
}

class _MoreTimeSheet extends StatefulWidget {
  const _MoreTimeSheet();

  @override
  State<_MoreTimeSheet> createState() => _MoreTimeSheetState();
}

class _MoreTimeSheetState extends State<_MoreTimeSheet> {
  static const _options = [15, 30, 60];
  int _minutes = 30;
  final _reason = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final auth = AuthService.instance;
    try {
      await auth.api.post('/api/requests', {
        'deviceId': auth.deviceId,
        'minutes': _minutes,
        'reason': _reason.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(FgSpace.xl, 0, FgSpace.xl,
          FgSpace.xl + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ask for more time',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Your parent gets the request and can say yes or no.',
              style: TextStyle(color: c.textMuted)),
          const SizedBox(height: FgSpace.lg),
          Row(
            children: [
              for (final m in _options) ...[
                Expanded(
                  child: _MinuteOption(
                    minutes: m,
                    selected: _minutes == m,
                    onTap: () => setState(() => _minutes = m),
                  ),
                ),
                if (m != _options.last) const SizedBox(width: FgSpace.sm),
              ],
            ],
          ),
          const SizedBox(height: FgSpace.md),
          TextField(
            controller: _reason,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Why? (optional)',
              hintText: 'Finishing homework',
            ),
          ),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: c.danger)),
            const SizedBox(height: FgSpace.sm),
          ],
          FilledButton(
            onPressed: _sending ? null : _send,
            child: Text(_sending ? 'Sending…' : 'Send request'),
          ),
        ],
      ),
    );
  }
}

class _MinuteOption extends StatelessWidget {
  const _MinuteOption(
      {required this.minutes, required this.selected, required this.onTap});
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FgSpace.radiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: FgSpace.lg),
        decoration: BoxDecoration(
          color: selected ? c.tint(c.accent) : c.surfaceHigh,
          borderRadius: BorderRadius.circular(FgSpace.radiusSm),
          border: Border.all(color: selected ? c.accent : c.border),
        ),
        child: Column(
          children: [
            Text('+$minutes',
                style: fgNumber(context, 22,
                    color: selected ? c.accent : c.text)),
            Text('min', style: TextStyle(color: c.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
