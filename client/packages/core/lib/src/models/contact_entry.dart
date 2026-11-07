/// A contact read from the child device.
class ContactEntry {
  const ContactEntry(this.name, this.number);

  final String name;
  final String number;

  factory ContactEntry.fromMap(Map<dynamic, dynamic> map) => ContactEntry(
        (map['name'] ?? '').toString(),
        (map['number'] ?? '').toString(),
      );
}
