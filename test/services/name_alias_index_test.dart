import 'package:flutter_test/flutter_test.dart';
import 'package:quetzalib/models/name_alias_group.dart';
import 'package:quetzalib/services/name_alias_index.dart';

void main() {
  final index = NameAliasIndex([
    const NameAliasGroup(id: 1, terms: ['TH', 'thai', 'ไทย']),
    const NameAliasGroup(id: 2, terms: ['Kadokawa', 'คาโดคาวะ']),
  ]);

  group('NameAliasGroup.sanitizeTerms', () {
    test('trims, drops empties and collapses case-insensitive duplicates', () {
      expect(
        NameAliasGroup.sanitizeTerms(['  TH ', '', 'th', 'ไทย', '   ']),
        ['TH', 'ไทย'],
      );
    });

    test('strips the storage separator so a term cannot split in two', () {
      expect(NameAliasGroup.sanitizeTerms(['a|b']), ['a b']);
    });
  });

  group('NameAliasIndex.expand', () {
    test('returns every name in a set the query names', () {
      expect(index.expand('ไทย'), {'th', 'thai', 'ไทย'});
      expect(index.expand('TH'), {'th', 'thai', 'ไทย'});
    });

    test('triggers on a partially typed name', () {
      expect(index.expand('kado'), {'kadokawa', 'คาโดคาวะ'});
    });

    test('does not trigger on a query that merely contains a name', () {
      // "the hobbit" contains "th" — expanding on that would drag the
      // Thai set into every unrelated search.
      expect(index.expand('the hobbit'), isEmpty);
    });

    test('is empty for an unknown or blank query', () {
      expect(index.expand('japanese'), isEmpty);
      expect(index.expand('   '), isEmpty);
    });
  });

  group('NameAliasIndex.matchesAnyValue', () {
    test('matches a value equal to any name in the set, ignoring case', () {
      expect(index.matchesAnyValue('ไทย', ['Thai']), isTrue);
      expect(index.matchesAnyValue('thai', ['th']), isTrue);
    });

    test('matches whole values only, never substrings', () {
      expect(index.matchesAnyValue('ไทย', ['North Star']), isFalse);
    });

    test('is false when no set is triggered', () {
      expect(index.matchesAnyValue('kodansha', ['Kodansha']), isFalse);
      expect(NameAliasIndex.empty.matchesAnyValue('ไทย', ['TH']), isFalse);
    });
  });
}
