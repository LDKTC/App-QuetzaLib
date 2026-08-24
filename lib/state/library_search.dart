import '../models/book.dart';
import '../services/name_alias_index.dart';

/// The "Info" fields a name-alias set is matched against: every field
/// whose value is a *name* someone might write more than one way.
///
/// [Book.title] is deliberately absent — a title stays one name in its own
/// language and is only ever matched exactly as typed (see
/// [bookMatchesQuery]). ISBNs are absent for the same reason: they're
/// identifiers, not names.
List<String> aliasMatchableValues(
  Book book, {
  List<String> categoryNames = const [],
}) {
  return [
    ...book.authors,
    ...book.illustrators,
    if (book.series != null) book.series!,
    if (book.genre != null) book.genre!,
    if (book.language != null) book.language!,
    if (book.publisher != null) book.publisher!,
    ...categoryNames,
  ].where((value) => value.isNotEmpty).toList();
}

/// Whether [book] matches the library search box's [query].
///
/// Two passes, in order:
///
/// 1. **Literal** — the query as a substring of the book's title, ISBNs or
///    any [aliasMatchableValues] field. This is the plain search that
///    works with no name sets configured at all.
/// 2. **Alias** — the query expanded through [aliasIndex] into every name
///    that means the same thing, each compared against the book's
///    [aliasMatchableValues] as a whole value. This is what makes
///    searching `ไทย` find books whose language is recorded as `TH`.
///
/// An empty (or whitespace-only) query matches every book.
bool bookMatchesQuery(
  Book book,
  String query, {
  NameAliasIndex? aliasIndex,
  List<String> categoryNames = const [],
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) return true;

  final aliasValues = aliasMatchableValues(book, categoryNames: categoryNames);
  final haystack = [
    book.title,
    if (book.isbn13 != null) book.isbn13!,
    if (book.isbn10 != null) book.isbn10!,
    ...aliasValues,
  ].join(' ').toLowerCase();
  if (haystack.contains(normalizedQuery)) return true;

  return aliasIndex?.matchesAnyValue(normalizedQuery, aliasValues) ?? false;
}
