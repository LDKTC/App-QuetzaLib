/// A set of names that all mean the same thing — e.g. `TH`, `thai`, `ไทย`.
///
/// Groups are deliberately **untyped**: a set is just a bag of equivalent
/// words, with no declared field it belongs to. The same set can therefore
/// stand in for a language on one book, a publisher's two spellings on
/// another, and an author's pen name on a third, without the user having
/// to say which is which up front.
///
/// Which fields a set is actually matched against is decided at search
/// time (see `lib/state/library_search.dart`): every "Info" field whose
/// value is a name — author, illustrator, series, genre, language,
/// publisher, category — but never the book title, which stays a single
/// name in its own language and is matched exactly as typed.
class NameAliasGroup {
  final int? id;

  /// The equivalent names, in the order the user added them. Already
  /// sanitized by [sanitizeTerms] when it comes from the app; rows read
  /// back from the database are re-sanitized by [fromMap].
  final List<String> terms;

  const NameAliasGroup({this.id, required this.terms});

  /// Terms are stored as one `|`-joined column, the same way a book's
  /// authors/illustrators lists are.
  static const storageSeparator = '|';

  /// The comparison form of a term: trimmed and lower-cased, so `TH`,
  /// `th` and ` Th ` are one and the same name.
  static String normalize(String term) => term.trim().toLowerCase();

  /// Cleans up user-entered terms: trims whitespace, drops the storage
  /// separator (which would otherwise split one term into two on the way
  /// back out of the database), removes empties, and collapses
  /// case-insensitive duplicates keeping the first spelling entered.
  static List<String> sanitizeTerms(Iterable<String> raw) {
    final seen = <String>{};
    final result = <String>[];
    for (final term in raw) {
      final cleaned = term.replaceAll(storageSeparator, ' ').trim();
      if (cleaned.isEmpty) continue;
      if (seen.add(normalize(cleaned))) result.add(cleaned);
    }
    return result;
  }

  /// Every term in [normalize]d form — what searching compares against.
  Set<String> get normalizedTerms => {for (final term in terms) normalize(term)};

  bool get isEmpty => terms.isEmpty;

  NameAliasGroup copyWith({int? id, List<String>? terms}) {
    return NameAliasGroup(
      id: id ?? this.id,
      terms: terms ?? this.terms,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'terms': terms.join(storageSeparator),
    };
  }

  factory NameAliasGroup.fromMap(Map<String, Object?> map) {
    final termsRaw = map['terms'] as String?;
    return NameAliasGroup(
      id: map['id'] as int?,
      terms: (termsRaw == null || termsRaw.isEmpty)
          ? const []
          : sanitizeTerms(termsRaw.split(storageSeparator)),
    );
  }
}
