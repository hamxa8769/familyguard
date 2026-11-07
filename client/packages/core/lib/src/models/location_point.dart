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
