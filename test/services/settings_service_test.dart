import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quetzalib/models/book_meta_field.dart';
import 'package:quetzalib/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppThemeMode.fromStorage', () {
    test('round-trips every theme mode through its storage value', () {
      for (final mode in AppThemeMode.values) {
        expect(AppThemeMode.fromStorage(mode.storageValue), mode);
      }
    });

    test('falls back to following the system for missing or stale values', () {
      // A value written by a future version (or a hand-edited preference)
      // must not throw — the app just follows the device again.
      expect(AppThemeMode.fromStorage(null), AppThemeMode.system);
      expect(AppThemeMode.fromStorage(''), AppThemeMode.system);
      expect(AppThemeMode.fromStorage('sepia'), AppThemeMode.system);
    });
  });

  test('AppThemeMode maps onto the matching Flutter ThemeMode', () {
    expect(AppThemeMode.system.themeMode, ThemeMode.system);
    expect(AppThemeMode.light.themeMode, ThemeMode.light);
    expect(AppThemeMode.dark.themeMode, ThemeMode.dark);
  });

  group('SettingsService book list details', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('an untouched install shows the default details', () async {
      expect(
        await SettingsService.instance.getBookMetaFields(),
        BookMetaField.defaults,
      );
      expect(
        await SettingsService.instance.getBookMetaLayout(),
        BookMetaLayout.defaultLayout,
      );
    });

    test('round-trips a chosen set of details', () async {
      const chosen = {BookMetaField.language, BookMetaField.isbn};
      await SettingsService.instance.setBookMetaFields(chosen);
      expect(await SettingsService.instance.getBookMetaFields(), chosen);
    });

    test('remembers that every detail was turned off', () async {
      // The regression this guards: storing "none" as an absent preference
      // would read back as "never configured" and silently restore the
      // defaults on the next launch.
      await SettingsService.instance.setBookMetaFields({});
      expect(await SettingsService.instance.getBookMetaFields(), isEmpty);
    });

    test('round-trips the layout', () async {
      await SettingsService.instance.setBookMetaLayout(BookMetaLayout.wrapped);
      expect(
        await SettingsService.instance.getBookMetaLayout(),
        BookMetaLayout.wrapped,
      );
    });
  });
}
