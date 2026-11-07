import 'package:flutter/material.dart';
import '../../feature_module.dart';

class ChildrenModule implements FeatureModule {
  @override
  String get id => 'children';
  @override
  String get title => 'My Children';
  @override
  String get description => 'Manage multiple child profiles';
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
  final _children = <String>['Ali (10)', 'Sara (13)'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Children')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addChild,
        icon: const Icon(Icons.person_add),
        label: const Text('Add child'),
      ),
      body: ListView(
        children: [
          for (final c in _children)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.child_care)),
              title: Text(c),
              trailing: const Icon(Icons.chevron_right),
            ),
        ],
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
          decoration: const InputDecoration(labelText: 'Name'),
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
    if (name != null && name.isNotEmpty) {
      // TODO: POST /api/children { displayName: name }
      setState(() => _children.add(name));
    }
  }
}
