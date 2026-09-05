import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

import 'package:quetzalib/services/settings_service.dart';

void main() {
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
}
