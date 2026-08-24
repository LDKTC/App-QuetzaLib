import 'package:flutter_test/flutter_test.dart';
import 'package:quetzalib/models/name_alias_group.dart';

void main() {
  group('NameAliasGroup.merged', () {
    test('unions the terms of every group, first spelling wins', () {
      final a = NameAliasGroup(id: 1, terms: const ['TH', 'thai']);
      final b = NameAliasGroup(id: 2, terms: const ['Thai', 'ไทย']);

      final merged = NameAliasGroup.merged([a, b]);

      expect(merged, ['TH', 'thai', 'ไทย']);
    });

    test('two unrelated groups', () {
      final a = NameAliasGroup(id: 1, terms: const ['EN', 'english']);
      final b = NameAliasGroup(id: 2, terms: const ['JP', 'japanese']);

      final merged = NameAliasGroup.merged([a, b]);

      expect(merged, ['EN', 'english', 'JP', 'japanese']);
    });
  });

  group('NameAliasGroup.split', () {
    test('pulls the matched names out, case-insensitively, in order', () {
      final (remaining, extracted) = NameAliasGroup.split(
        ['TH', 'thai', 'ไทย', 'Thailand'],
        ['THAI', 'Thailand'],
      );

      expect(remaining, ['TH', 'ไทย']);
      expect(extracted, ['thai', 'Thailand']);
    });

    test('ignores names that are not actually in the term list', () {
      final (remaining, extracted) = NameAliasGroup.split(
        ['TH', 'thai'],
        ['nope'],
      );

      expect(remaining, ['TH', 'thai']);
      expect(extracted, isEmpty);
    });

    test('extracting nothing leaves everything remaining', () {
      final (remaining, extracted) = NameAliasGroup.split(['TH', 'thai'], []);

      expect(remaining, ['TH', 'thai']);
      expect(extracted, isEmpty);
    });

    test('extracting everything leaves nothing remaining', () {
      final (remaining, extracted) =
          NameAliasGroup.split(['TH', 'thai'], ['TH', 'thai']);

      expect(remaining, isEmpty);
      expect(extracted, ['TH', 'thai']);
    });
  });
}
