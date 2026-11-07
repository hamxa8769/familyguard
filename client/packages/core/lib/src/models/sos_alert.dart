/// An emergency alert raised from a child device.
class SosAlert {
  const SosAlert({
    required this.id,
    required this.deviceId,
    required this.message,
    required this.at,
    this.resolved = false,
  });

  final String id;
  final String deviceId;
  final String message;
  final String at;
  final bool resolved;

  factory SosAlert.fromMap(Map<dynamic, dynamic> map) => SosAlert(
        id: map['id'].toString(),
        deviceId: (map['deviceId'] ?? '').toString(),
        message: (map['message'] ?? 'SOS').toString(),
        at: (map['at'] ?? '').toString(),
        resolved: map['resolved'] == true,
      );
}
