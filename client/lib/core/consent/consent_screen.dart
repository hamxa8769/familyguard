import 'package:flutter/material.dart';
import 'consent_service.dart';

/// Full-screen notice shown on the child device before any monitoring starts.
/// This visible, explicit step is what makes the app parental control, not spyware.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  static const consentText =
      'This device is managed with FamilyGuard. While it is active, a parent or '
      'guardian in your family can see which apps are used and for how long, this '
      'device\'s location, and screen-time limits. FamilyGuard runs visibly and '
      'does not hide itself. Monitoring starts only after you accept below.';

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
            const Text(
              'FamilyGuard — what you are agreeing to',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
