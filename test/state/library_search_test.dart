import 'package:flutter_test/flutter_test.dart';
import 'package:quetzalib/models/book.dart';
import 'package:quetzalib/models/name_alias_group.dart';
import 'package:quetzalib/services/name_alias_index.dart';
import 'package:quetzalib/state/library_search.dart';

Book _book({
  String title = 'Untitled',
  List<String> authors = const [],
  List<String> illustrators = const [],
  String? series,
  String? genre,
  String? language,
  String? publisher,
  String? isbn13,
}) {
  return Book(
    id: 1,
    title: title,
    authors: authors,
    illustrators: illustrators,
    series: series,
    genre: genre,
    language: language,
    publisher: publisher,
    isbn13: isbn13,
    dateAdded: DateTime(2026),
  );
}

void main() {
  final aliasIndex = NameAliasIndex([
    const NameAliasGroup(id: 1, terms: ['TH', 'thai', 'ไทย']),
    const NameAliasGroup(id: 2, terms: ['Kadokawa', 'คาโดคาวะ']),
  ]);

  group('bookMatchesQuery without alias sets', () {
    test('matches title, ISBN and any info field as a substring', () {
      final book = _book(
        title: 'Spice and Wolf',
        authors: ['Isuna Hasekura'],
        series: 'Spice and Wolf',
        publisher: 'Kadokawa',
        isbn13: '9784048670180',
      );
      expect(bookMatchesQuery(book, 'wolf'), isTrue);
      expect(bookMatchesQuery(book, 'hasekura'), isTrue);
      expect(bookMatchesQuery(book, 'kadokawa'), isTrue);
      expect(bookMatchesQuery(book, '9784048670180'), isTrue);
      expect(bookMatchesQuery(book, 'kodansha'), isFalse);
    });

    test('an empty query matches everything', () {
      expect(bookMatchesQuery(_book(), '   '), isTrue);
    });
  });

  group('bookMatchesQuery with alias sets', () {
    test('finds a book by another name in the same set', () {
      final book = _book(title: 'ตำราอาหาร', language: 'TH');
      expect(bookMatchesQuery(book, 'ไทย', aliasIndex: aliasIndex), isTrue);
      expect(bookMatchesQuery(book, 'thai', aliasIndex: aliasIndex), isTrue);
    });

    test('works for any info field, not one declared type', () {
      expect(
        bookMatchesQuery(
          _book(publisher: 'คาโดคาวะ'),
          'kadokawa',
          aliasIndex: aliasIndex,
        ),
        isTrue,
      );
      expect(
        bookMatchesQuery(
          _book(illustrators: ['ไทย']),
          'TH',
          aliasIndex: aliasIndex,
        ),
        isTrue,
      );
    });

    test('matches a linked category name too', () {
      expect(
        bookMatchesQuery(
          _book(),
          'TH',
          aliasIndex: aliasIndex,
          categoryNames: ['ไทย'],
        ),
        isTrue,
      );
    });

    test('never expands aliases into the book title', () {
      // The title stays one name in its own language: a Thai-language
      // query must not pull in an English title just because it reads
      // "Thai".
      final book = _book(title: 'Thai Cooking', language: 'EN');
      expect(bookMatchesQuery(book, 'ไทย', aliasIndex: aliasIndex), isFalse);
      expect(bookMatchesQuery(book, 'Thai', aliasIndex: aliasIndex), isTrue);
    });

    test('does not match an unrelated value that merely contains a name', () {
      final book = _book(publisher: 'North Star');
      expect(bookMatchesQuery(book, 'ไทย', aliasIndex: aliasIndex), isFalse);
    });
  });
}
