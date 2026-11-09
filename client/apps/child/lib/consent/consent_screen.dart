import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:familyguard_core/ui.dart';
import '../pairing/pair_screen.dart' show OnboardingSteps;

/// Step 2 of onboarding: the full, plain-language notice. Nothing is collected
/// until the child accepts — this visible step is what makes FamilyGuard
/// parental control and not spyware.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  /// Exact text recorded on the server when the child accepts.
  static const consentText =
      'This device is managed with FamilyGuard. While it is active, a parent or '
      'guardian in your family can see which apps are used and for how long, this '
      'device\'s location, screen-time limits, your SMS messages, contacts, call '
      'history, and the photos and files on this device. '
      'FamilyGuard runs visibly and does not hide itself, and you can always open '
      '"What my parent sees" to check exactly what is shared. Monitoring starts '
      'only after you accept below.';

  static const shared = [
    (Icons.bar_chart_rounded, 'App usage', 'Which apps and for how long'),
    (Icons.location_on_outlined, 'Location', 'Where this device is'),
    (Icons.sms_outlined, 'Messages and contacts', 'SMS text, sender and time'),
    (Icons.call_outlined, 'Call history', 'Number, type, time, length'),
    (Icons.photo_library_outlined, 'Photos and files', 'Name, size and date'),
    (Icons.sos_rounded, 'SOS alerts', 'When you press SOS'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final name = AuthService.instance.childName;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(FgSpace.xl),
                children: [
                  const OnboardingSteps(current: 1),
                  const SizedBox(height: FgSpace.xl),
                  Text(name == null ? 'Before you start' : 'Hi $name, before you start',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: FgSpace.sm),
                  Text(
                    'FamilyGuard is visible on this phone and never hides. '
                    'Here is exactly what your parent will be able to see.',
                    style: TextStyle(color: c.textMuted),
                  ),
                  const SectionLabel('Shared with your parent'),
                  FgCard(
                    padding: const EdgeInsets.symmetric(vertical: FgSpace.xs),
                    child: Column(
                      children: [
                        for (final (icon, title, sub) in shared)
                          ListTile(
                            leading: IconWell(icon, size: 36),
                            title: Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(sub,
                                style: TextStyle(color: c.textMuted)),
                          ),
                      ],
                    ),
                  ),
                  const SectionLabel('Never collected'),
                  FgCard(
                    child: Row(
                      children: [
                        IconWell(Icons.videocam_off_outlined, color: c.safe),
                        const SizedBox(width: FgSpace.md),
                        const Expanded(
                          child: Text(
                              'Live camera, microphone, passwords or your '
                              'screen'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FgSpace.lg),
                  Text(
                    'You can check what is shared at any time in "What my '
                    'parent sees".',
                    style: TextStyle(color: c.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  FgSpace.xl, 0, FgSpace.xl, FgSpace.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ConsentService().recordConsent();
                    onAccepted();
                  },
                  child: const Text('I understand and agree'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
