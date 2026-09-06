import 'package:flutter_test/flutter_test.dart';

import 'package:quetzalib/l10n/app_localizations.dart';
import 'package:quetzalib/models/book.dart';
import 'package:quetzalib/models/book_meta_field.dart';

/// An empty value table falls back to the English one key by key (see
/// `AppLocalizations._t`), so this is the English strings without needing a
/// widget tree to resolve a delegate.
final _t = AppLocalizations(const {});

Book _book({
  String title = 'A Book',
  String? isbn13,
  String? isbn10,
  String? series,
  double? seriesVolume,
  String? genre,
  String? publisher,
  String? publishedDate,
  int? pageCount,
  String? language,
}) {
  return Book(
    title: title,
    isbn13: isbn13,
    isbn10: isbn10,
    series: series,
    seriesVolume: seriesVolume,
    genre: genre,
    publisher: publisher,
    publishedDate: publishedDate,
    pageCount: pageCount,
    language: language,
    dateAdded: DateTime(2024, 1, 1),
  );
}

List<String> _labels(
  Book book, {
  required Set<BookMetaField> fields,
  List<String> categoryNames = const [],
}) {
  return bookMetaTokens(
    book,
    fields: fields,
    t: _t,
    categoryNames: categoryNames,
  ).map((token) => token.label).toList();
}

void main() {
  group('BookMetaField storage', () {
    test('round-trips any selection through its stored string', () {
      const selections = [
        BookMetaField.defaults,
        <BookMetaField>{},
        {BookMetaField.isbn},
        {BookMetaField.language, BookMetaField.genre, BookMetaField.category},
      ];
      for (final selection in selections) {
        expect(
          BookMetaField.fromStorage(BookMetaField.toStorage(selection)),
          selection,
        );
      }
    });

    test('stores fields in enum order however they were toggled on', () {
      expect(
        BookMetaField.toStorage({BookMetaField.isbn, BookMetaField.series}),
        BookMetaField.toStorage({BookMetaField.series, BookMetaField.isbn}),
      );
    });

    test('an unset preference means the defaults, not an empty row', () {
      expect(BookMetaField.fromStorage(null), BookMetaField.defaults);
    });

    test('an empty stored value is a real choice: show nothing', () {
      // Distinct from null above — the user turned every field off, and
      // that must survive a restart instead of resetting to the defaults.
      expect(BookMetaField.fromStorage(''), isEmpty);
    });

    test('drops names it does not recognise instead of throwing', () {
      expect(
        BookMetaField.fromStorage('series,rating,,year'),
        {BookMetaField.series, BookMetaField.year},
      );
    });
  });

  group('BookMetaLayout.fromStorage', () {
    test('round-trips every layout through its storage value', () {
      for (final layout in BookMetaLayout.values) {
        expect(BookMetaLayout.fromStorage(layout.storageValue), layout);
      }
    });

    test('falls back to one line for missing or stale values', () {
      expect(BookMetaLayout.fromStorage(null), BookMetaLayout.singleLine);
      expect(BookMetaLayout.fromStorage('twoLines'), BookMetaLayout.singleLine);
    });
  });

  group('bookMetaTokens', () {
    test('shows only the enabled fields', () {
      final book = _book(
        language: 'Thai',
        genre: 'Manga',
        publisher: 'Kadokawa',
        publishedDate: '2019-04-22',
      );
      expect(
        _labels(book, fields: {BookMetaField.language, BookMetaField.genre}),
        ['Thai', 'Manga'],
      );
    });

    test('skips enabled fields the book has no value for', () {
      // A bare manual entry with everything turned on still renders
      // nothing, rather than a row of empty icons.
      expect(
        _labels(_book(), fields: BookMetaField.values.toSet()),
        isEmpty,
      );
    });

    test('treats an empty string the same as a missing value', () {
      expect(
        _labels(_book(genre: '', series: ''),
            fields: {BookMetaField.genre, BookMetaField.series}),
        isEmpty,
      );
    });

    test('orders tokens by field declaration order, not selection order', () {
      final book = _book(language: 'Thai', publisher: 'Kadokawa');
      expect(
        _labels(book, fields: {BookMetaField.publisher, BookMetaField.language}),
        ['Thai', 'Kadokawa'],
      );
    });

    test('folds the volume into the series token when both are on', () {
      final book = _book(series: 'Spice & Wolf', seriesVolume: 3);
      expect(
        _labels(book, fields: {BookMetaField.series, BookMetaField.volume}),
        ['Spice & Wolf · Vol. 3'],
      );
    });

    test('shows the volume on its own when the series is off', () {
      final book = _book(series: 'Spice & Wolf', seriesVolume: 4.5);
      expect(_labels(book, fields: {BookMetaField.volume}), ['Vol. 4.5']);
    });

    test('shows the series alone when the book has no volume', () {
      final book = _book(series: 'Spice & Wolf');
      expect(
        _labels(book, fields: {BookMetaField.series, BookMetaField.volume}),
        ['Spice & Wolf'],
      );
    });

    test('reads the year out of whatever shape publishedDate arrives in', () {
      for (final date in ['2019', '2019-04', '2019-04-22']) {
        expect(
          _labels(_book(publishedDate: date), fields: {BookMetaField.year}),
          ['2019'],
        );
      }
      expect(
        _labels(_book(publishedDate: 'unknown'), fields: {BookMetaField.year}),
        isEmpty,
      );
    });

    test('ignores a zero page count', () {
      expect(
        _labels(_book(pageCount: 0), fields: {BookMetaField.pageCount}),
        isEmpty,
      );
      expect(
        _labels(_book(pageCount: 312), fields: {BookMetaField.pageCount}),
        ['312 pages'],
      );
    });

    test('falls back to ISBN-10 when the book has no ISBN-13', () {
      expect(
        _labels(_book(isbn10: '4048682180'), fields: {BookMetaField.isbn}),
        ['4048682180'],
      );
      expect(
        _labels(
          _book(isbn13: '9784048682183', isbn10: '4048682180'),
          fields: {BookMetaField.isbn},
        ),
        ['9784048682183'],
      );
    });

    test('joins the category names passed in alongside the book', () {
      expect(
        _labels(
          _book(),
          fields: {BookMetaField.category},
          categoryNames: ['Owned', 'Wishlist'],
        ),
        ['Owned, Wishlist'],
      );
    });

    test('ignores category names when the category field is off', () {
      expect(
        _labels(
          _book(language: 'Thai'),
          fields: {BookMetaField.language},
          categoryNames: ['Owned'],
        ),
        ['Thai'],
      );
    });
  });
}
