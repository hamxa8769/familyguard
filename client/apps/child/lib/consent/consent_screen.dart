import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:familyguard_core/ui.dart';
import '../build_flavor.dart';
import '../pairing/pair_screen.dart' show OnboardingSteps;

/// Step 2 of onboarding: the full, plain-language notice. Nothing is collected
/// until the child accepts — this visible step is what makes FamilyGuard
/// parental control and not spyware.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  /// Exact text recorded on the server when the child accepts.
  static String get consentText =>
      'This device is managed with FamilyGuard. While it is active, a parent or '
      'guardian in your family can see which apps are used and for how long, this '
      'device\'s location, screen-time limits, '
      '${kLiteBuild ? '' : 'your SMS messages, contacts, call history, '}'
      'and the names, albums and dates of the photos and files on this device. '
      'If your parent turns on photo previews, small previews of your newest '
      '100 photos are shared too; "What my parent sees" shows when this is on. '
      'This information is shared about every 15 minutes, also while the app '
      'is closed. '
      'Your parent can also set rules on this phone: block apps, set a daily '
      'screen-time limit, a bedtime, and block websites. When a rule applies, '
      'apps are paused (calls, the home screen and FamilyGuard always work) and '
      'you can ask for more time. '
      'FamilyGuard runs visibly and does not hide itself, and you can always open '
      '"What my parent sees" to check exactly what is shared. Monitoring starts '
      'only after you accept below.';

  static final shared = [
    (Icons.bar_chart_rounded, 'App usage', 'Which apps and for how long'),
    (Icons.location_on_outlined, 'Location', 'Where this device is'),
    if (!kLiteBuild)
      (Icons.sms_outlined, 'Messages and contacts', 'SMS text, sender and time'),
    if (!kLiteBuild)
      (Icons.call_outlined, 'Call history', 'Number, type, time, length'),
    (Icons.photo_library_outlined, 'Photos and files',
        'Name, album and date; small previews only if your parent turns them on'),
    (Icons.sos_rounded, 'SOS alerts', 'When you press SOS'),
  ];

  static const rules = [
    (Icons.block_rounded, 'Block apps', 'Chosen apps are paused'),
    (Icons.timelapse_rounded, 'Daily limit', 'Apps pause when time is up'),
    (Icons.bedtime_outlined, 'Bedtime', 'Apps pause at night'),
    (Icons.public_off_rounded, 'Web filter', 'Chosen websites won\'t open'),
    (Icons.call_outlined, 'Always allowed', 'Calls, home screen, FamilyGuard'),
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
                  const SectionLabel('Rules your parent can set'),
                  FgCard(
                    padding: const EdgeInsets.symmetric(vertical: FgSpace.xs),
                    child: Column(
                      children: [
                        for (final (icon, title, sub) in rules)
                          ListTile(
                            leading: IconWell(icon, size: 36, color: c.warn),
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
                  FgCard(
                    child: Row(
                      children: [
                        const IconWell(Icons.sync_rounded),
                        const SizedBox(width: FgSpace.md),
                        Expanded(
                          child: Text(
                            'Shared about every 15 minutes — also while the '
                            'app is closed.',
                            style: TextStyle(color: c.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FgSpace.md),
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
