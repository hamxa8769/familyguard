/// The parent-managed keyword list for AI keyword alerts.
///
/// Phase 2 is a simple keyword list with substring matching on messages
/// the child app already syncs (SMS). There is no sentiment analysis or ML
/// model here — a `ml_model` field is deliberately absent, and any future
/// model must be added as an explicit, disclosed feature, not a silent one.
class KeywordList {
  const KeywordList({
    required this.childId,
    required this.keywords,
  });

  final String childId;
  final List<String> keywords;

  factory KeywordList.fromMap(Map<dynamic, dynamic> map) => KeywordList(
        childId: (map['childId'] ?? '').toString(),
        keywords: (map['keywords'] as List? ?? []).map((k) => k.toString()).toList(),
      );
}
