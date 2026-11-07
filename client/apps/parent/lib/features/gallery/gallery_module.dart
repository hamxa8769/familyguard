import 'package:flutter/material.dart';
import '../../feature_module.dart';

class GalleryModule implements FeatureModule {
  @override
  String get id => 'gallery';
  @override
  String get title => 'Gallery & Files';
  @override
  String get description => 'Photos and files on the child\'s device';
  @override
  IconData get icon => Icons.photo_library;
  @override
  Widget buildScreen(BuildContext context) => const GalleryViewScreen();
}

class GalleryViewScreen extends StatelessWidget {
  const GalleryViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample metadata; real list from GET /api/files/:deviceId (synced from child).
    // Thumbnails require syncing image bytes — a TODO (metadata only for now).
    const files = [
      ('photo_1.jpg', '2.3 MB', 'Today 14:05', true),
      ('screenshot.png', '825 KB', 'Today 10:12', true),
      ('selfie.jpg', '1.8 MB', 'Yesterday', true),
      ('notes.pdf', '120 KB', '2 days ago', false),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Gallery & Files')),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: files.length,
        itemBuilder: (context, i) {
          final (name, size, whenLabel, isImage) = files[i];
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isImage ? Icons.image : Icons.insert_drive_file, size: 32),
                const SizedBox(height: 6),
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11)),
                Text('$size • $whenLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9)),
              ],
            ),
          );
        },
      ),
    );
  }
}
