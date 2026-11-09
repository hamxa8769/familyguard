/// A media/file entry read from the child device.
class MediaFile {
  const MediaFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.dateMillis,
    this.isImage = true,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final int dateMillis;
  final bool isImage;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMillis);

  String get sizeLabel {
    if (sizeBytes >= 1048576) return '${(sizeBytes / 1048576).toStringAsFixed(1)} MB';
    if (sizeBytes >= 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '$sizeBytes B';
  }

  /// Metadata only — file bytes are never uploaded.
  Map<String, dynamic> toMap() => {
        'name': name,
        'path': path,
        'size': sizeBytes,
        'date': dateMillis,
        'isImage': isImage,
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
      );
}
