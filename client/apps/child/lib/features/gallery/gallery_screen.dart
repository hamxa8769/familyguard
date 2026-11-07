import 'dart:io';
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'gallery_collector.dart';

/// Child-side view of the gallery/files shared with the parent (transparency).
/// On the child's own device, real thumbnails render from the local path.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _collector = GalleryCollector();
  List<MediaFile> _files = [];
  bool _loading = true;
  bool _needsPermission = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (!await _collector.hasPermission()) {
      setState(() {
        _needsPermission = true;
        _loading = false;
      });
      return;
    }
    final files = await _collector.images();
    setState(() {
      _files = files;
      _needsPermission = false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery & Files'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _needsPermission
              ? _permissionPrompt()
              : _files.isEmpty
                  ? const Center(child: Text('No files found.'))
                  : _grid(),
    );
  }

  Widget _permissionPrompt() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library, size: 56),
          const SizedBox(height: 16),
          const Text('Gallery access needed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Your parent/guardian can see photos and files on this device through '
            'FamilyGuard. Grant access so this works. You can always review here '
            'what is shared.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => _collector.requestPermission(),
            child: const Text('Grant access'),
          ),
          TextButton(onPressed: _load, child: const Text('I\'ve granted it')),
        ],
      ),
    );
  }

  Widget _grid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _files.length,
      itemBuilder: (context, i) {
        final f = _files[i];
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: f.isImage && f.path.isNotEmpty
              ? Image.file(
                  File(f.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback(f),
                )
              : _fallback(f),
        );
      },
    );
  }

  Widget _fallback(MediaFile f) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(f.isImage ? Icons.image : Icons.insert_drive_file),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(f.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}
