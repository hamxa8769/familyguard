import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../common/widgets.dart';
import '../../feature_module.dart';
import '../../state/parent_state.dart';

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
    // Metadata only (name, size, date) — image bytes are not uploaded.
    return DeviceScoped(
      title: 'Gallery & Files',
      builder: (context, deviceId) => Scaffold(
        appBar: AppBar(title: const Text('Gallery & Files')),
        body: ApiView<List<MediaFile>>(
          load: () async {
            final res =
                await ParentState.instance.api.get('/api/files/$deviceId');
            return (res['items'] as List)
                .map((e) => MediaFile.fromMap(e as Map))
                .toList()
              ..sort((a, b) => b.dateMillis.compareTo(a.dateMillis));
          },
          builder: (context, files, _) {
            if (files.isEmpty) {
              return const EmptyHint('No files shared yet.');
            }
            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: files.length,
              itemBuilder: (context, i) {
                final f = files[i];
                return Container(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(f.isImage ? Icons.image : Icons.insert_drive_file,
                          size: 32),
                      const SizedBox(height: 6),
                      Text(f.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                      Text('${f.sizeLabel} • ${timeAgo(f.date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9)),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
