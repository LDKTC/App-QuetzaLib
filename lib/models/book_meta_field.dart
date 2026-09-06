import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'book.dart';

/// One optional fact the library list can print under a book's title.
///
/// The list used to hardcode which three of these it showed (series, year,
/// page count). Which facts actually identify a book differs from library
/// to library though — a shelf of translated light novels is told apart by
/// language and volume, a shelf of textbooks by publisher and year — so the
/// set is a user setting instead, and this enum is what that setting stores.
enum BookMetaField {
  series,
  volume,
  language,
  genre,
  category,
  publisher,
  year,
  pageCount,
  isbn;

  String get storageValue => name;

  /// The glyph [MetaLabel] puts in front of the value. Deliberately the
  /// outlined variants: these sit under the title as secondary text, and
  /// the filled icons read as loud as the title itself at 13px.
  IconData get icon => switch (this) {
        BookMetaField.series => Icons.collections_bookmark_outlined,
        BookMetaField.volume => Icons.bookmark_outline,
        BookMetaField.language => Icons.translate_outlined,
        BookMetaField.genre => Icons.local_offer_outlined,
        BookMetaField.category => Icons.folder_outlined,
        BookMetaField.publisher => Icons.business_outlined,
        BookMetaField.year => Icons.event_outlined,
        BookMetaField.pageCount => Icons.menu_book_outlined,
        BookMetaField.isbn => Icons.qr_code_2_outlined,
      };

  /// The name shown next to this field's toggle in settings. Mostly reuses
  /// the book editor's own field labels, so the settings list names each
  /// fact exactly as the form the user typed it into does.
  String label(AppLocalizations t) => switch (this) {
        BookMetaField.series => t.seriesField,
        BookMetaField.volume => t.seriesVolumeField,
        BookMetaField.language => t.languageField,
        BookMetaField.genre => t.genreField,
        BookMetaField.category => t.categoriesLabel,
        BookMetaField.publisher => t.publisherField,
        BookMetaField.year => t.metaFieldYear,
        BookMetaField.pageCount => t.pageCountField,
        BookMetaField.isbn => t.metaFieldIsbn,
      };

  /// What a fresh install shows — the same three facts the list printed
  /// before any of this was configurable, so upgrading doesn't silently
  /// rearrange an existing library.
  static const defaults = <BookMetaField>{series, volume, year, pageCount};

  /// Parses the stored comma-joined field names. Unknown names (a field
  /// removed in a later version, a hand-edited preference) are dropped
  /// rather than throwing; a missing value means "never configured" and
  /// yields [defaults], while an empty string is a real choice — the user
  /// turned every field off — and yields the empty set.
  static Set<BookMetaField> fromStorage(String? value) {
    if (value == null) return defaults;
    final names = value.split(',').map((name) => name.trim());
    return {
      for (final field in BookMetaField.values)
        if (names.contains(field.storageValue)) field,
    };
  }

  /// [fields] as the string [fromStorage] reads back, always in enum order
  /// so the stored value doesn't depend on the order they were toggled in.
  static String toStorage(Set<BookMetaField> fields) => [
        for (final field in BookMetaField.values)
          if (fields.contains(field)) field.storageValue,
      ].join(',');
}

/// How the chosen [BookMetaField]s are laid out on a list row.
///
/// [singleLine] keeps every row the height of its cover, at the cost of
/// showing only the first [BookMetaLayout.singleLineLimit] facts a book
/// actually has; [wrapped] shows all of them and lets rows grow. Which one
/// is right depends on whether the library is being scanned or studied, so
/// it's the user's call rather than a fixed choice.
enum BookMetaLayout {
  singleLine,
  wrapped;

  /// How many facts [singleLine] prints before it stops. Three ellipsized
  /// tokens still read on a narrow phone; a fourth turns them all into
  /// stubs.
  static const singleLineLimit = 3;

  /// What a fresh install lays the details out as — the scannable list the
  /// library screen has always been.
  static const defaultLayout = singleLine;

  String get storageValue => name;

  String label(AppLocalizations t) => switch (this) {
        BookMetaLayout.singleLine => t.metaLayoutSingleLine,
        BookMetaLayout.wrapped => t.metaLayoutWrapped,
      };

  static BookMetaLayout fromStorage(String? value) {
    return BookMetaLayout.values.firstWhere(
      (layout) => layout.storageValue == value,
      orElse: () => BookMetaLayout.defaultLayout,
    );
  }
}

/// One rendered fact: the glyph and the text a [MetaLabel] draws.
class BookMetaToken {
  const BookMetaToken({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The tokens to print for [book], covering only the [fields] the user
/// turned on and only those the book actually carries — a bare manual entry
/// with every field enabled still renders nothing rather than a row of
/// empty icons.
///
/// Always in [BookMetaField] declaration order, so two books' rows line up
/// against each other no matter which fields each one happens to have.
/// [categoryNames] comes from the provider rather than [Book] (categories
/// are a separate table), and is ignored unless
/// [BookMetaField.category] is on.
List<BookMetaToken> bookMetaTokens(
  Book book, {
  required Set<BookMetaField> fields,
  required AppLocalizations t,
  List<String> categoryNames = const [],
}) {
  final series = _nonEmpty(book.series);
  final volume = book.seriesVolumeDisplay;
  final showSeries = fields.contains(BookMetaField.series) && series != null;
  final showVolume = fields.contains(BookMetaField.volume) && volume != null;

  final tokens = <BookMetaToken>[];
  for (final field in BookMetaField.values) {
    if (!fields.contains(field)) continue;
    final label = switch (field) {
      // With both on, the volume folds into the series token ("Foo · Vol.
      // 3") instead of spending two of the row's slots on one fact.
      // showSeries/showVolume promote `series`/`volume` to non-null here,
      // so no `!` is needed (and the analyzer rejects one that is).
      BookMetaField.series => !showSeries
          ? null
          : showVolume
              ? t.seriesWithVolume(series, volume)
              : series,
      BookMetaField.volume =>
        (showVolume && !showSeries) ? t.volumeLabel(volume) : null,
      BookMetaField.language => _nonEmpty(book.language),
      BookMetaField.genre => _nonEmpty(book.genre),
      BookMetaField.category =>
        categoryNames.isEmpty ? null : categoryNames.join(', '),
      BookMetaField.publisher => _nonEmpty(book.publisher),
      BookMetaField.year => _yearOf(book.publishedDate),
      BookMetaField.pageCount => (book.pageCount ?? 0) > 0
          ? t.pagesLabel(book.pageCount!.toString())
          : null,
      BookMetaField.isbn => _nonEmpty(book.isbn13) ?? _nonEmpty(book.isbn10),
    };
    if (label != null) {
      tokens.add(BookMetaToken(icon: field.icon, label: label));
    }
  }
  return tokens;
}

String? _nonEmpty(String? value) =>
    (value == null || value.isEmpty) ? null : value;

/// The four-digit year out of a `publishedDate`, which arrives from the
/// metadata providers in whatever shape they use (`2019`, `2019-04`,
/// `2019-04-22`) — anything without a year renders nothing rather than a
/// confusing fragment.
String? _yearOf(String? publishedDate) {
  final match = RegExp(r'\d{4}').firstMatch(publishedDate ?? '');
  return match?.group(0);
}
