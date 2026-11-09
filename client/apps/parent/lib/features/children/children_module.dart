import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../shell/settings_screen.dart';
import '../../state/parent_state.dart';

class ChildrenModule implements FeatureModule {
  @override
  String get id => 'children';
  @override
  FeatureSection get section => FeatureSection.family;
  @override
  String get title => 'My Children';
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
        onPressed: _addChild,
        icon: const Icon(Icons.person_add),
        label: const Text('Add child'),
      ),
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, _) {
          if (_state.loading && _state.children.isEmpty) {
            return const Center(child: CircularProgressIndicator());
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
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final c in _state.children) _ChildCard(child: c),
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
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    await saveWithFeedback(
      context,
      () => _state.addChild(name),
      '$name added — enter the pairing code on their device',
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child});
  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    final state = ParentState.instance;
    final code = child.pairingCode ?? '------';
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.child_care)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(child.displayName,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Pairing code (enter in the Child app):',
                style: Theme.of(context).textTheme.bodySmall),
            Row(
              children: [
                SelectableText(code,
                    style: const TextStyle(
                        fontSize: 28,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold)),
                IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: code)),
                ),
                IconButton(
                  tooltip: 'New code',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => saveWithFeedback(
                    context,
                    () => state.newPairingCode(child.id),
                    'New pairing code created',
                  ),
                ),
              ],
            ),
            const Divider(),
            if (child.devices.isEmpty)
              const Text('No device paired yet.')
            else
              for (final d in child.devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(d.platform == 'windows'
                      ? Icons.computer
                      : Icons.phone_android),
                  title: Text(d.deviceName),
                  subtitle: Text(d.platform),
                  trailing: state.selectedDeviceId == d.id
                      ? const Chip(label: Text('Viewing'))
                      : TextButton(
                          onPressed: () => state.select(d.id),
                          child: const Text('View')),
                ),
          ],
        ),
      ),
    );
  }
}
