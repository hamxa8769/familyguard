/// A GPS location point from the child device.
class LocationPoint {
  const LocationPoint({
    required this.lat,
    required this.lng,
    required this.timeMillis,
  });

  final double lat;
  final double lng;
  final int timeMillis;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timeMillis);

  /// Server format: { lat, lng, at: ISO-8601 }.
  static LocationPoint? fromServer(Map<dynamic, dynamic>? map) {
    if (map == null || map['lat'] == null || map['lng'] == null) return null;
    final at = DateTime.tryParse('${map['at']}');
    return LocationPoint(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      timeMillis: at?.millisecondsSinceEpoch ?? 0,
    );
  }

  static LocationPoint? fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    final lat = map['lat'];
    final lng = map['lng'];
    if (lat == null || lng == null) return null;
    return LocationPoint(
      lat: (lat as num).toDouble(),
      lng: (lng as num).toDouble(),
      timeMillis: (map['time'] ?? 0) is int
          ? map['time'] as int
          : int.tryParse('${map['time']}') ?? 0,
    );
  }
}
