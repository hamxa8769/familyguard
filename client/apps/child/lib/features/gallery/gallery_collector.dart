import 'dart:io';
import 'dart:ui' as ui;
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
        final parts = e.path.split(Platform.pathSeparator);
        final key = 'w:${_fnv1a(e.path)}';
        _windowsPaths[key] = e.path;
        out.add(MediaFile(
          name: name,
          path: e.path,
          sizeBytes: st.size,
          dateMillis: st.modified.millisecondsSinceEpoch,
          isImage: isImg,
          key: key,
          // Folder the picture is in, e.g. "Screenshots" (root = "Pictures").
          album: parts.length >= 2 ? parts[parts.length - 2] : 'Pictures',
        ));
        if (out.length >= 200) break;
      }
    } catch (_) {}
    out.sort((a, b) => b.dateMillis.compareTo(a.dateMillis));
    return out;
  }

  // Windows: key -> full path, filled by images().
  final Map<String, String> _windowsPaths = {};

  /// Small preview (JPEG on Android, PNG on Windows) of the photo with [key],
  /// or null. Only used when the parent has turned photo previews on.
  Future<Uint8List?> thumbnail(String key, {int size = 256}) async {
    if (Platform.isAndroid) {
      try {
        return await _channel
            .invokeMethod<Uint8List>('getThumbnail', {'key': key, 'size': size});
      } catch (_) {
        return null;
      }
    }
    final path = _windowsPaths[key];
    if (path == null) return null;
    try {
      final bytes = await File(path).readAsBytes();
      final probe = await ui.instantiateImageCodec(bytes);
      final first = (await probe.getNextFrame()).image;
      final w = first.width, h = first.height;
      first.dispose();
      final scale = size / (w > h ? w : h);
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: scale < 1 ? (w * scale).round() : w,
        targetHeight: scale < 1 ? (h * scale).round() : h,
      );
      final img = (await codec.getNextFrame()).image;
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      return png?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Stable 32-bit FNV-1a hash (String.hashCode changes between runs).
  static String _fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }

  static final _sample = [
    MediaFile(name: 'photo_1.jpg', path: '', sizeBytes: 2411724, dateMillis: DateTime.now().millisecondsSinceEpoch - 600000),
    MediaFile(name: 'screenshot.png', path: '', sizeBytes: 845123, dateMillis: DateTime.now().millisecondsSinceEpoch - 7200000),
    MediaFile(name: 'notes.pdf', path: '', sizeBytes: 123456, dateMillis: DateTime.now().millisecondsSinceEpoch - 86400000, isImage: false),
  ];
}
