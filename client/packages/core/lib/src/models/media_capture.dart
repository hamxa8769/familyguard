/// Metadata for one screenshot or SOS-audio capture.
///
/// Hard limits (enforced server-side, mirrored here for the UI):
///  - Screenshots are on-request only, after a visible notification and
///    countdown on the child device. Never secret, never continuous.
///  - Audio is SOS-triggered or parent-requested only, max 30 seconds,
///    with a visible on-screen indicator and sound. Never continuous
///    or ambient listening.
///  - Captures auto-expire after 7 days (MEDIA_RETENTION_DAYS).
/// Phase 1 stores metadata only; the file bytes are uploaded in Phase 2
/// (native capture + storage), referenced by [storageRef].
class MediaCapture {
  const MediaCapture({
    required this.id,
    required this.deviceId,
    required this.kind,
    required this.source,
    required this.status,
    this.commandId,
    this.storageRef,
    this.sizeBytes,
    this.durationSeconds,
    this.createdAt,
    this.expiresAt,
  });

  /// screenshot | sos_audio
  final String kind;

  /// sos | parent_request
  final String source;

  /// requested | captured | delivered | deleted | expired
  final String status;

  final String id;
  final String deviceId;
  final String? commandId;
  final String? storageRef;
  final int? sizeBytes;
  final int? durationSeconds;
  final String? createdAt;
  final String? expiresAt;

  bool get isScreenshot => kind == 'screenshot';
  bool get isAudio => kind == 'sos_audio';

  factory MediaCapture.fromMap(Map<dynamic, dynamic> map) => MediaCapture(
        id: map['id'].toString(),
        deviceId: (map['deviceId'] ?? '').toString(),
        kind: (map['kind'] ?? '').toString(),
        source: (map['source'] ?? '').toString(),
        status: (map['status'] ?? '').toString(),
        commandId: map['commandId']?.toString(),
        storageRef: map['storageRef']?.toString(),
        sizeBytes: map['sizeBytes'] is num ? (map['sizeBytes'] as num).toInt() : null,
        durationSeconds:
            map['durationSeconds'] is num ? (map['durationSeconds'] as num).toInt() : null,
        createdAt: map['createdAt']?.toString(),
        expiresAt: map['expiresAt']?.toString(),
      );
}
