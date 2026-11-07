import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Full-screen notice shown before any monitoring starts. This visible, explicit
/// step is what makes the app parental control, not spyware.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  static const consentText =
      'This device is managed with FamilyGuard. While it is active, a parent or '
      'guardian in your family can see which apps are used and for how long, this '
      'device\'s location, screen-time limits, and your SMS messages and contacts. '
      'FamilyGuard runs visibly and does not hide itself, and you can always open '
      '"What My Parent Sees" to check exactly what is shared. Monitoring starts '
      'only after you accept below.';

  @override
  Widget build(BuildContext context) {
    final consent = ConsentService();
    return Scaffold(
      appBar: AppBar(title: const Text('Before you start')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.shield_outlined, size: 64),
            const SizedBox(height: 16),
            const Text('FamilyGuard — what you are agreeing to',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(consentText),
            const Spacer(),
            FilledButton(
              onPressed: () async {
                await consent.recordConsent();
                onAccepted();
              },
              child: const Text('I understand and accept'),
            ),
          ],
        ),
      ),
    );
  }
}
