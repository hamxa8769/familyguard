/// A family agreement: rules the parent proposes and the child signs.
/// Both sides see the same text and the same status; a declined agreement
/// is recorded, never silently overwritten.
class FamilyAgreement {
  const FamilyAgreement({
    required this.id,
    required this.childId,
    required this.rules,
    required this.status,
    this.createdAt,
    this.signedAt,
  });

  /// proposed | accepted | declined
  final String status;

  final String id;
  final String childId;
  final List<String> rules;
  final String? createdAt;
  final String? signedAt;

  bool get isProposed => status == 'proposed';

  factory FamilyAgreement.fromMap(Map<dynamic, dynamic> map) => FamilyAgreement(
        id: map['id'].toString(),
        childId: (map['childId'] ?? '').toString(),
        rules: (map['rules'] as List? ?? []).map((r) => r.toString()).toList(),
        status: (map['status'] ?? '').toString(),
        createdAt: map['createdAt']?.toString(),
        signedAt: map['signedAt']?.toString(),
      );
}
