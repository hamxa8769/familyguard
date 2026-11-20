/// A call-log entry read from the child device.
/// `type` 1 = incoming, 2 = outgoing, 3 = missed.
class CallLogEntry {
  const CallLogEntry({
    required this.number,
    required this.type,
    required this.dateMillis,
    required this.durationSeconds,
  });

  final String number;
  final int type;
  final int dateMillis;
  final int durationSeconds;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMillis);

  String get typeLabel => switch (type) {
        2 => 'Outgoing',
        3 => 'Missed',
        _ => 'Incoming',
      };

  Map<String, dynamic> toMap() => {
        'number': number,
        'type': type,
        'date': dateMillis,
        'duration': durationSeconds,
      };

  factory CallLogEntry.fromMap(Map<dynamic, dynamic> map) => CallLogEntry(
        number: (map['number'] ?? '').toString(),
        type: (map['type'] ?? 1) is int
            ? map['type'] as int
            : int.tryParse('${map['type']}') ?? 1,
        dateMillis: (map['date'] ?? 0) is int
            ? map['date'] as int
            : int.tryParse('${map['date']}') ?? 0,
        durationSeconds: (map['duration'] ?? 0) is int
            ? map['duration'] as int
            : int.tryParse('${map['duration']}') ?? 0,
      );
}
