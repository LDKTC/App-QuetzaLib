import '../models/name_alias_group.dart';

/// Resolves a search term to every other name that means the same thing,
/// using the user's [NameAliasGroup] sets.
///
/// Built once per library load from the stored groups and handed to the
/// search matcher (`lib/state/library_search.dart`), so a query only has
/// to walk the (small) list of groups once per keystroke.
///
/// Two deliberately asymmetric rules keep expansion useful without making
/// it noisy:
///
/// * A group is **triggered** when the query is a substring of one of its
///   terms, so a half-typed `th` still pulls in the `TH / thai / ไทย`
///   set. The reverse (a term being a substring of the query) is *not*
///   used — it would make searching "the hobbit" drag in every group
///   holding a short term like `TH`.
/// * A triggered group's terms are then matched against a book's field
///   values as **whole values**, not substrings: an alias stands for a
///   complete name, so `TH` matches the language `TH`, never the
///   publisher `North Star`.
class NameAliasIndex {
  NameAliasIndex(Iterable<NameAliasGroup> groups)
      : _groups = List.unmodifiable(groups);

  /// The no-sets-configured index — every lookup misses. Used before the
  /// library has loaded and by callers that don't want alias expansion.
  static final NameAliasIndex empty = NameAliasIndex(const []);

  final List<NameAliasGroup> _groups;

  bool get isEmpty => _groups.isEmpty;

  /// Every normalized name equivalent to [query], across all sets that
  /// [query] triggers. Empty when [query] matches no set — including for
  /// a blank query.
  Set<String> expand(String query) {
    final normalizedQuery = NameAliasGroup.normalize(query);
    final expanded = <String>{};
    if (normalizedQuery.isEmpty) return expanded;
    for (final group in _groups) {
      final terms = group.normalizedTerms;
      if (terms.any((term) => term.contains(normalizedQuery))) {
        expanded.addAll(terms);
      }
    }
    return expanded;
  }

  /// Whether any of [values] is, as a whole value, one of the names
  /// equivalent to [query].
  bool matchesAnyValue(String query, Iterable<String?> values) {
    final expanded = expand(query);
    if (expanded.isEmpty) return false;
    for (final value in values) {
      if (value == null || value.isEmpty) continue;
      if (expanded.contains(NameAliasGroup.normalize(value))) return true;
    }
    return false;
  }
}
