import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:familyguard_core/ui.dart';
import 'scan_screen.dart';

/// Step 1 of onboarding: link this device to a child profile, by scanning
/// the QR in the parent app (Family → child → QR) or typing the 6-letter code.
class PairScreen extends StatefulWidget {
  const PairScreen({super.key, required this.onPaired});

  final VoidCallback onPaired;

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _auth = AuthService.instance;
  late final _server = TextEditingController(text: _auth.api.baseUrl);
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _server.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _platform {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'windows';
  }

  Future<void> _scan() async {
    final raw = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (raw == null || !mounted) return;
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['fg'] != 1 || data['code'] == null) {
        throw const FormatException();
      }
      _code.text = '${data['code']}';
      if (data['server'] is String) _server.text = data['server'] as String;
      await _pair();
    } on FormatException {
      setState(() => _error = 'That QR code isn\'t a FamilyGuard pairing code');
    }
  }

  Future<void> _pair() async {
    if (_code.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-character code from the parent app');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.setBaseUrl(_server.text);
      await _auth.pairDevice(
        code: _code.text,
        platform: _platform,
        deviceName: Platform.localHostname,
      );
      widget.onPaired();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FgSpace.xl),
          children: [
            const OnboardingSteps(current: 0),
            const SizedBox(height: FgSpace.xl),
            const Center(child: IconWell(Icons.link_rounded, size: 72)),
            const SizedBox(height: FgSpace.lg),
            Text('Connect to your parent',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: FgSpace.sm),
            Text(
              Platform.isAndroid || Platform.isIOS
                  ? 'Ask your parent to open FamilyGuard → Family and show '
                      'you the QR code for your profile.'
                  : 'Ask your parent to open FamilyGuard → Family and read '
                      'you the pairing code for your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted),
            ),
            const SizedBox(height: FgSpace.xl),
            if (Platform.isAndroid || Platform.isIOS) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan QR code'),
              ),
              const SizedBox(height: FgSpace.lg),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or type the code',
                        style: TextStyle(color: c.textMuted, fontSize: 13)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: FgSpace.lg),
            ],
            TextField(
              controller: _code,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: fgNumber(context, 28).copyWith(letterSpacing: 10),
              decoration: const InputDecoration(
                hintText: 'ABC123',
                counterText: '',
              ),
              onSubmitted: (_) => _pair(),
            ),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('Server',
                    style: TextStyle(color: c.textMuted, fontSize: 14)),
                tilePadding: EdgeInsets.zero,
                children: [
                  TextField(
                    controller: _server,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      helperText: 'e.g. http://192.168.1.10:4000',
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: FgSpace.md),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.danger)),
                    ),
            ),
            OutlinedButton(
              onPressed: _busy ? null : _pair,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Connect with code'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1 Connect · 2 Agree · 3 Permissions" progress dots shown during setup.
class OnboardingSteps extends StatelessWidget {
  const OnboardingSteps({super.key, required this.current});
  final int current;

  static const _labels = ['Connect', 'Agree', 'Permissions'];

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= current ? c.accent : c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${i + 1}. ${_labels[i]}',
                    style: TextStyle(
                      fontSize: 12,
                      color: i == current ? c.text : c.textMuted,
                      fontWeight:
                          i == current ? FontWeight.w600 : FontWeight.w400,
                    )),
              ],
            ),
          ),
          if (i < _labels.length - 1) const SizedBox(width: FgSpace.sm),
        ],
      ],
    );
  }
}
