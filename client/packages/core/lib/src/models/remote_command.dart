/// A remote command from a parent to a child device.
///
/// Delivery contract: the child app polls
/// `GET /api/remotecommands?deviceId=…&status=pending`. Push (FCM) is a
/// best-effort notification only — a command is never delivered by push
/// alone. Commands expire (default 15 minutes) so a stale "lock now" can
/// never fire hours later.
class RemoteCommand {
  const RemoteCommand({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.status,
    this.payload = const {},
    this.createdAt,
    this.expiresAt,
  });

  /// lock_now | unlock | send_message | request_screenshot | request_audio
  final String type;

  /// pending | delivered | acknowledged | completed | expired | rejected | cancelled
  final String status;

  final String id;
  final String deviceId;
  final Map<String, dynamic> payload;
  final String? createdAt;
  final String? expiresAt;

  bool get isPending => status == 'pending';
  bool get isScreenshotRequest => type == 'request_screenshot';
  bool get isAudioRequest => type == 'request_audio';

  factory RemoteCommand.fromMap(Map<dynamic, dynamic> map) => RemoteCommand(
        id: map['id'].toString(),
        deviceId: (map['deviceId'] ?? '').toString(),
        type: (map['type'] ?? '').toString(),
        status: (map['status'] ?? '').toString(),
        payload: map['payload'] is Map
            ? Map<String, dynamic>.from(map['payload'] as Map)
            : const {},
        createdAt: map['createdAt']?.toString(),
        expiresAt: map['expiresAt']?.toString(),
      );
}
