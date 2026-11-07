import 'dart:io';
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// Lists images (and, on Windows, picture files) from the child device.
///   - Android: MediaStore via native channel (READ_MEDIA_IMAGES).
///   - Windows: the user's Pictures folder via dart:io (no permission needed).
class GalleryCollector {
  static const _channel = MethodChannel('familyguard/files');
  static const _imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'};

  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<bool>('hasPermission') ?? false;
      } catch (_) {
        return false;
      }
    }
    return true; // Windows/desktop: no runtime permission required.
  }

  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {}
  }

  Future<List<MediaFile>> images() async {
    if (Platform.isAndroid) {
      try {
        final List<dynamic> data =
            await _channel.invokeMethod('getImages') ?? <dynamic>[];
        return data
            .map((e) => MediaFile.fromMap(e as Map<dynamic, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
    if (Platform.isWindows) return _windowsPictures();
    return _sample;
  }

  List<MediaFile> _windowsPictures() {
    final out = <MediaFile>[];
    try {
      final home = Platform.environment['USERPROFILE'];
      if (home == null) return [];
      final dir = Directory('$home\\Pictures');
      if (!dir.existsSync()) return [];
      for (final e in dir.listSync(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final name = e.path.split(Platform.pathSeparator).last;
        final lower = name.toLowerCase();
        final isImg = _imageExts.any(lower.endsWith);
        final st = e.statSync();
        out.add(MediaFile(
          name: name,
          path: e.path,
          sizeBytes: st.size,
          dateMillis: st.modified.millisecondsSinceEpoch,
          isImage: isImg,
        ));
        if (out.length >= 200) break;
      }
    } catch (_) {}
    out.sort((a, b) => b.dateMillis.compareTo(a.dateMillis));
    return out;
  }

  static final _sample = [
    MediaFile(name: 'photo_1.jpg', path: '', sizeBytes: 2411724, dateMillis: DateTime.now().millisecondsSinceEpoch - 600000),
    MediaFile(name: 'screenshot.png', path: '', sizeBytes: 845123, dateMillis: DateTime.now().millisecondsSinceEpoch - 7200000),
    MediaFile(name: 'notes.pdf', path: '', sizeBytes: 123456, dateMillis: DateTime.now().millisecondsSinceEpoch - 86400000, isImage: false),
  ];
}
