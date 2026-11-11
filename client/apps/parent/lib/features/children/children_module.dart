import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../shell/settings_screen.dart';
import '../../state/parent_state.dart';
import '../../theme/app_theme.dart';
import '../../ui/fg_widgets.dart';

class ChildrenModule implements FeatureModule {
  @override
  String get id => 'children';
  @override
  FeatureSection get section => FeatureSection.family;
  @override
  String get title => 'My children';
  @override
  String get description => 'Add children and pair their devices';
  @override
  IconData get icon => Icons.family_restroom;
  @override
  Widget buildScreen(BuildContext context) => const ChildrenScreen();
}

class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({super.key});
  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  final _state = ParentState.instance;

  @override
  void initState() {
    super.initState();
    _state.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        actions: const [SettingsButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-child',
        onPressed: _addChild,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add child'),
      ),
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          if (_state.loading && _state.children.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(FgSpace.lg),
              child: Skeleton(height: 180, radius: FgSpace.radius),
            );
          }
          if (_state.error != null) {
            return EmptyHint('Could not load: ${_state.error}');
          }
          if (_state.children.isEmpty) {
            return const EmptyHint(
                'No children yet. Tap "Add child" to create a profile and get '
                'a pairing code for their device.');
          }
          return RefreshIndicator(
            onRefresh: _state.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  FgSpace.lg, FgSpace.sm, FgSpace.lg, 96),
              children: [
                for (final c in _state.children) ...[
                  _ChildCard(child: c),
                  const SizedBox(height: FgSpace.md),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addChild() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add child'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    await saveWithFeedback(
      context,
      () => _state.addChild(name),
      '$name added — scan the QR or enter the code on their device',
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final state = ParentState.instance;
    final code = child.pairingCode ?? '------';
    return FgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: c.tint(c.accent),
                child: Text(
                  child.displayName.isEmpty
                      ? '?'
                      : child.displayName[0].toUpperCase(),
                  style: TextStyle(
                      color: c.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ),
              const SizedBox(width: FgSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(child.displayName,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                        child.devices.isEmpty
                            ? 'No device yet'
                            : '${child.devices.length} device${child.devices.length == 1 ? '' : 's'}',
                        style: TextStyle(color: c.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FgSpace.md),
          Container(
            padding: const EdgeInsets.fromLTRB(FgSpace.md, FgSpace.sm, 4, FgSpace.sm),
            decoration: BoxDecoration(
              color: c.surfaceHigh,
              borderRadius: BorderRadius.circular(FgSpace.radiusSm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pairing code',
                          style: TextStyle(color: c.textMuted, fontSize: 12)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: SelectableText(code,
                            style: fgNumber(context, 26)
                                .copyWith(letterSpacing: 5)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Show QR code',
                  icon: Icon(Icons.qr_code_2_rounded, color: c.accent),
                  onPressed: () => _showQr(context, code),
                ),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')));
                    }
                  },
                ),
                IconButton(
                  tooltip: 'New code',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: () => saveWithFeedback(
                    context,
                    () => state.newPairingCode(child.id),
                    'New pairing code created',
                  ),
                ),
              ],
            ),
          ),
          for (final d in child.devices) ...[
            const SizedBox(height: FgSpace.sm),
            _DeviceRow(device: d, selected: state.selectedDeviceId == d.id),
          ],
        ],
      ),
    );
  }

  void _showQr(BuildContext context, String code) {
    final server = AuthService.instance.api.baseUrl;
    final payload = jsonEncode({'fg': 1, 'server': server, 'code': code});
    final local = server.contains('localhost') || server.contains('127.0.0.1');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final c = FgColors.of(ctx);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                FgSpace.xl, 0, FgSpace.xl, FgSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pair ${child.displayName}\'s device',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Scan this in the FamilyGuard Child app',
                    style: TextStyle(color: c.textMuted)),
                const SizedBox(height: FgSpace.lg),
                Container(
                  padding: const EdgeInsets.all(FgSpace.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(FgSpace.radius),
                  ),
                  child: QrImageView(
                    data: payload,
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: FgSpace.lg),
                Text(code, style: fgNumber(ctx, 28).copyWith(letterSpacing: 6)),
                if (local) ...[
                  const SizedBox(height: FgSpace.md),
                  Text(
                    'Server is "$server" — a phone can\'t reach localhost. '
                    'Sign in with your PC\'s network address (e.g. '
                    'http://192.168.1.10:4000) before pairing a real phone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.warn, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.selected});
  final DeviceInfo device;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final seen = device.lastSeenAt;
    final online =
        seen != null && DateTime.now().difference(seen).inMinutes < 20;
    return Row(
      children: [
        IconWell(
            device.platform == 'windows'
                ? Icons.computer_rounded
                : Icons.phone_android_rounded,
            size: 36,
            color: c.textMuted),
        const SizedBox(width: FgSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.deviceName,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              Row(
                children: [
                  StatusDot(
                      color: online ? c.safe : c.textMuted, pulse: online),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                        seen == null
                            ? device.platform
                            : '${device.platform} · seen ${timeAgo(seen)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textMuted, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
        selected
            ? Chip(
                label: const Text('Viewing'),
                backgroundColor: c.tint(c.accent),
                side: BorderSide(color: c.accent),
                labelStyle: TextStyle(color: c.accent, fontSize: 12),
                visualDensity: VisualDensity.compact,
              )
            : TextButton(
                onPressed: () => ParentState.instance.select(device.id),
                child: const Text('View')),
      ],
    );
  }
}
