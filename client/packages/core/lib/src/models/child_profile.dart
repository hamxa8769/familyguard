/// A child managed by a parent account.
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.displayName,
    this.birthYear,
  });

  final String id;
  final String displayName;
  final int? birthYear;

  factory ChildProfile.fromMap(Map<dynamic, dynamic> map) => ChildProfile(
        id: map['id'].toString(),
        displayName: (map['displayName'] ?? '').toString(),
        birthYear: map['birthYear'] is int ? map['birthYear'] as int : null,
      );
}
