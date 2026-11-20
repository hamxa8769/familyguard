/// A child managed by a parent account, with its paired devices.
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.displayName,
    this.birthYear,
    this.pairingCode,
    this.devices = const [],
  });

  final String id;
  final String displayName;
  final int? birthYear;

  /// One-time code the child's device enters to pair (parent app only).
  final String? pairingCode;
  final List<DeviceInfo> devices;

  factory ChildProfile.fromMap(Map<dynamic, dynamic> map) => ChildProfile(
        id: map['id'].toString(),
        displayName: (map['displayName'] ?? '').toString(),
        birthYear: map['birthYear'] is int ? map['birthYear'] as int : null,
        pairingCode: map['pairingCode']?.toString(),
        devices: ((map['devices'] as List?) ?? const [])
            .map((d) => DeviceInfo.fromMap(d as Map<dynamic, dynamic>))
            .toList(),
      );
}

/// A child device paired to a child profile.
class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.childId,
    required this.platform,
    required this.deviceName,
    this.lastSeenAt,
    this.enforcement,
  });

  final String id;
  final String childId;
  final String platform;
  final String deviceName;

  /// Last time the device talked to the server (its sync heartbeat).
  final DateTime? lastSeenAt;

  /// What the device last said it can enforce (permissions, services).
  final Map<String, dynamic>? enforcement;

  factory DeviceInfo.fromMap(Map<dynamic, dynamic> map) => DeviceInfo(
        id: map['id'].toString(),
        childId: (map['childId'] ?? '').toString(),
        platform: (map['platform'] ?? '').toString(),
        deviceName: (map['deviceName'] ?? '').toString(),
        lastSeenAt: DateTime.tryParse('${map['lastSeenAt'] ?? ''}'),
        enforcement: map['enforcement'] is Map
            ? Map<String, dynamic>.from(map['enforcement'] as Map)
            : null,
      );
}
