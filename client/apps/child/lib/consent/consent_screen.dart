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
      'device\'s location, screen-time limits, your SMS messages, contacts, call '
      'history, and the photos and files on this device. '
      'Your parent can also see which apps are installed, which browser was '
      'open and for how long (never the pages or URLs you visit), the family '
      'agreement you sign, and the reward points and badges you earn. '
      'Your parent can also send remote commands (lock this device now, unlock '
      'it, or send you a message), request a screenshot, and request a short '
      'audio clip. A screenshot is only taken after a notification and a '
      'countdown on this device, and audio is only recorded when you press SOS '
      'or after a visible request — at most 30 seconds, with an on-screen '
      'indicator and a sound. FamilyGuard never listens continuously and never '
      'takes secret screenshots. '
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
            // The v2 text is long: scroll instead of overflowing on small
            // screens (the old layout overflowed by ~66 px in tests).
            const Expanded(
              child: SingleChildScrollView(child: Text(consentText)),
            ),
            const SizedBox(height: 16),
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
