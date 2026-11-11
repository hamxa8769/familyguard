/// A media/file entry read from the child device.
class MediaFile {
  const MediaFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.dateMillis,
    this.isImage = true,
    this.key = '',
    this.album = '',
    this.hasThumb = false,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final int dateMillis;
  final bool isImage;

  /// Stable id of the file on the device (Android media id / path hash);
  /// used to match its preview thumbnail.
  final String key;

  /// Folder / album the photo is in (Camera, Screenshots, WhatsApp Images…).
  final String album;

  /// Parent side: the server has a preview thumbnail for this file.
  final bool hasThumb;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMillis);

  String get albumLabel => album.isEmpty ? 'Other' : album;

  String get sizeLabel {
    if (sizeBytes >= 1048576) return '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';
    if (sizeBytes >= 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '$sizeBytes B';
  }

  /// Metadata only. Preview thumbnails are uploaded separately and only when
  /// the parent has turned photo previews on.
  Map<String, dynamic> toMap() => {
        'name': name,
        'path': path,
        'size': sizeBytes,
        'date': dateMillis,
        'isImage': isImage,
        'key': key,
        'album': album,
      };

  factory MediaFile.fromMap(Map<dynamic, dynamic> map) => MediaFile(
        name: (map['name'] ?? '').toString(),
        path: (map['path'] ?? '').toString(),
        sizeBytes: (map['size'] ?? 0) is int
            ? map['size'] as int
            : int.tryParse('${map['size']}') ?? 0,
        dateMillis: (map['date'] ?? 0) is int
            ? map['date'] as int
            : int.tryParse('${map['date']}') ?? 0,
        isImage: map['isImage'] != false,
        key: (map['key'] ?? '').toString(),
        album: (map['album'] ?? '').toString(),
        hasThumb: map['hasThumb'] == true,
      );
}
