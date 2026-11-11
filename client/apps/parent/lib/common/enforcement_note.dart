import 'package:flutter/material.dart';
import 'package:familyguard_core/ui.dart';
import '../state/parent_state.dart';

/// Tells the parent whether a rule is really applied on the selected child
/// device, based on the status the device last reported — and if not, which
/// permission the child still needs to allow.
class EnforcementNote extends StatelessWidget {
  const EnforcementNote({super.key, this.web = false});

  /// True for the web filter (needs the VPN); false for app/bedtime/limit rules.
  final bool web;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final sel = ParentState.instance.selected;
    final child = sel?.$1.displayName ?? 'your child';
    final device = sel?.$2;
    final e = device?.enforcement;

    final IconData icon;
    final Color color;
    final String text;
    if (e == null) {
      icon = Icons.hourglass_empty_rounded;
      color = c.textMuted;
      text = 'Rules apply on $child\'s Android phone after its next sync.';
    } else if (e['supported'] == false) {
      icon = Icons.info_outline_rounded;
      color = c.textMuted;
      text = '${device!.deviceName} (${device.platform}) can\'t enforce rules '
          'yet — they are shown to $child there.';
    } else {
      final missing = <String>[
        if (web && e['vpnApproved'] != true) 'Web filter',
        if (!web && e['usageAccess'] != true) 'App usage',
        if (!web && e['overlay'] != true) 'Display over other apps',
      ];
      if (missing.isEmpty) {
        icon = Icons.verified_user_outlined;
        color = c.safe;
        text = 'Enforced on ${device!.deviceName}.';
      } else {
        icon = Icons.warning_amber_rounded;
        color = c.warn;
        text = 'Not enforced yet: on $child\'s phone, open FamilyGuard → '
            'Permissions and allow ${missing.join(' and ')}.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(FgSpace.md),
      decoration: BoxDecoration(
        color: c.tint(color),
        borderRadius: BorderRadius.circular(FgSpace.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: FgSpace.sm),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
