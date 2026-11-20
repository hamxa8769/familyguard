/// An SMS message read from the child device.
/// `type` 1 = received (inbox), 2 = sent.
/// `threadId` is the Android conversation thread (Telephony.Sms.THREAD_ID);
/// null when unknown — grouping then falls back to the normalised address.
class SmsMessage {
  const SmsMessage({
    required this.address,
    required this.body,
    required this.dateMillis,
    required this.type,
    this.threadId,
  });

  final String address;
  final String body;
  final int dateMillis;
  final int type;
  final int? threadId;

  bool get isIncoming => type == 1;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMillis);

  Map<String, dynamic> toMap() => {
        'address': address,
        'body': body,
        'date': dateMillis,
        'type': type,
        if (threadId != null) 'threadId': threadId,
      };

  factory SmsMessage.fromMap(Map<dynamic, dynamic> map) {
    final rawThread = map['threadId'];
    final thread = rawThread is int
        ? rawThread
        : int.tryParse('$rawThread');
    return SmsMessage(
      address: (map['address'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      dateMillis: (map['date'] ?? 0) is int
          ? map['date'] as int
          : int.tryParse('${map['date']}') ?? 0,
      type: (map['type'] ?? 1) is int
          ? map['type'] as int
          : int.tryParse('${map['type']}') ?? 1,
      // Android sends -1 when the thread column is unavailable.
      threadId: thread != null && thread >= 0 ? thread : null,
    );
  }
}
