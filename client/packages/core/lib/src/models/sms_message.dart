/// An SMS message read from the child device.
/// `type` 1 = received (inbox), 2 = sent.
class SmsMessage {
  const SmsMessage({
    required this.address,
    required this.body,
    required this.dateMillis,
    required this.type,
  });

  final String address;
  final String body;
  final int dateMillis;
  final int type;

  bool get isIncoming => type == 1;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMillis);

  Map<String, dynamic> toMap() =>
      {'address': address, 'body': body, 'date': dateMillis, 'type': type};

  factory SmsMessage.fromMap(Map<dynamic, dynamic> map) => SmsMessage(
        address: (map['address'] ?? '').toString(),
        body: (map['body'] ?? '').toString(),
        dateMillis: (map['date'] ?? 0) is int
            ? map['date'] as int
            : int.tryParse('${map['date']}') ?? 0,
        type: (map['type'] ?? 1) is int
            ? map['type'] as int
            : int.tryParse('${map['type']}') ?? 1,
      );
}
