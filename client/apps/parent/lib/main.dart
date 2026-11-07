import 'package:flutter/material.dart';
import 'feature_registry.dart';

void main() => runApp(const ParentApp());

class ParentApp extends StatelessWidget {
  const ParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyGuard (Parent)',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ParentHome(),
    );
  }
}

/// Dashboard builds itself from the feature registry, so new features appear
/// automatically.
class ParentHome extends StatelessWidget {
  const ParentHome({super.key});

  @override
  Widget build(BuildContext context) {
    final features = FeatureRegistry.all;
    return Scaffold(
      appBar: AppBar(title: const Text('FamilyGuard — Parent')),
      body: ListView(
        children: [
          for (final f in features)
            ListTile(
              leading: Icon(f.icon),
              title: Text(f.title),
              subtitle: Text(f.description),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => f.buildScreen(context)),
              ),
            ),
        ],
      ),
    );
  }
}
