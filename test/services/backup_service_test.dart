import 'package:flutter_test/flutter_test.dart';
import 'package:quetzalib/services/backup_service.dart';

void main() {
  group('imageExtensionFor', () {
    test('keeps a real extension, lower-cased', () {
      expect(imageExtensionFor('covers/3_1699999999.JPG'), '.jpg');
      expect(imageExtensionFor('images/img_0.png'), '.png');
    });

    test('falls back to .jpg with no dot', () {
      expect(imageExtensionFor('webimg://covers/3_1699999999'), '.jpg');
    });

    test('falls back to .jpg for an implausibly long "extension"', () {
      expect(imageExtensionFor('covers/a.notreallyanextension'), '.jpg');
    });

    test('falls back to .jpg when the dot is the last character', () {
      expect(imageExtensionFor('covers/3_1699999999.'), '.jpg');
    });
  });
}
