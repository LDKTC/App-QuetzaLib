import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/book_meta_field.dart';

/// Which theme the app renders in. [system] follows the device's dark-mode
/// setting; the other two pin the app to one brightness regardless of it —
/// a reading app is often used in bed with the phone still in light mode,
/// so following the device isn't always what the reader wants.
enum AppThemeMode {
  system,
  light,
  dark;

  String get storageValue => name;

  String label(AppLocalizations t) => switch (this) {
        AppThemeMode.system => t.themeModeSystem,
        AppThemeMode.light => t.themeModeLight,
        AppThemeMode.dark => t.themeModeDark,
      };

  /// The [ThemeMode] to hand [MaterialApp].
  ThemeMode get themeMode => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  static AppThemeMode fromStorage(String? value) {
    return AppThemeMode.values.firstWhere(
      (m) => m.storageValue == value,
      orElse: () => AppThemeMode.system,
    );
  }
}

/// The app's display language. [system] follows the device's locale
/// (falling back to English if the device locale isn't supported); the
/// others force a specific language regardless of device locale.
enum AppLocale {
  system,
  english,
  thai;

  String get storageValue => name;

  String label(AppLocalizations t) => switch (this) {
        AppLocale.system => t.localeSystemDefault,
        AppLocale.english => t.localeEnglish,
        AppLocale.thai => t.localeThai,
      };

  /// The [Locale] to pass to [MaterialApp.locale], or null for [system]
  /// (letting Flutter resolve the device's locale against
  /// [MaterialApp.supportedLocales] itself).
  Locale? get locale => switch (this) {
        AppLocale.system => null,
        AppLocale.english => const Locale('en'),
        AppLocale.thai => const Locale('th'),
      };

  static AppLocale fromStorage(String? value) {
    return AppLocale.values.firstWhere(
      (l) => l.storageValue == value,
      orElse: () => AppLocale.system,
    );
  }
}

/// How books render on the visual shelf: as their front cover, or as their
/// spine (each book's active cover preset supplies both images). Derived
/// from [LibraryViewMode] — it's only meaningful for the two shelf modes,
/// but the shelf-rendering widgets only ever care about cover-vs-spine, not
/// whether list view is also in the rotation.
enum ShelfDisplayMode {
  cover,
  spine;

  String label(AppLocalizations t) => switch (this) {
        ShelfDisplayMode.cover => t.shelfModeCover,
        ShelfDisplayMode.spine => t.shelfModeSpine,
      };
}

/// The library screen's single view toggle button cycles through all three
/// of these in order: a flat list, the visual shelf showing front covers,
/// and the visual shelf showing spines.
enum LibraryViewMode {
  list,
  shelfCover,
  shelfSpine;

  String get storageValue => name;

  /// The [ShelfDisplayMode] to render with when this mode is one of the two
  /// shelf modes; meaningless (and unused) for [list].
  ShelfDisplayMode get shelfDisplayMode =>
      this == LibraryViewMode.shelfSpine
          ? ShelfDisplayMode.spine
          : ShelfDisplayMode.cover;

  /// The mode the view-toggle button switches to next.
  LibraryViewMode get next => switch (this) {
        LibraryViewMode.list => LibraryViewMode.shelfCover,
        LibraryViewMode.shelfCover => LibraryViewMode.shelfSpine,
        LibraryViewMode.shelfSpine => LibraryViewMode.list,
      };

  String label(AppLocalizations t) => switch (this) {
        LibraryViewMode.list => t.viewModeListLabel,
        LibraryViewMode.shelfCover => t.viewModeShelfCoverLabel,
        LibraryViewMode.shelfSpine => t.viewModeShelfSpineLabel,
      };

  static LibraryViewMode fromStorage(String? value) {
    return LibraryViewMode.values.firstWhere(
      (m) => m.storageValue == value,
      orElse: () => LibraryViewMode.list,
    );
  }
}

/// How the library list/shelf orders its books. [dateAdded] (the default)
/// matches the database's natural insertion order; the rest sort
/// alphabetically/numerically over the matching [Book] field.
enum LibrarySortField {
  dateAdded,
  title,
  series,
  author,
  publisher,
  isbn,
  languageGenre;

  String get storageValue => name;

  String label(AppLocalizations t) => switch (this) {
        LibrarySortField.dateAdded => t.sortByDateAdded,
        LibrarySortField.title => t.titleField,
        LibrarySortField.series => t.seriesField,
        LibrarySortField.author => t.sortByAuthor,
        LibrarySortField.publisher => t.publisherField,
        LibrarySortField.isbn => t.isbn13Field,
        LibrarySortField.languageGenre => t.sortByLanguageGenre,
      };

  static LibrarySortField fromStorage(String? value) {
    return LibrarySortField.values.firstWhere(
      (f) => f.storageValue == value,
      orElse: () => LibrarySortField.dateAdded,
    );
  }
}

/// Persists user-configurable app settings: the display language and theme,
/// the optional Cloud Vision API key used for OCR text scanning, the
/// library view mode, and which details the library list prints under each
/// book's title.
class SettingsService {
  SettingsService._internal();
  static final SettingsService instance = SettingsService._internal();

  static const _keyLibraryViewMode = 'library_view_mode';
  static const _keyLibrarySortField = 'library_sort_field';
  static const _keyCloudVisionApiKey = 'cloud_vision_api_key';
  static const _keyAppLocale = 'app_locale';
  static const _keyAppThemeMode = 'app_theme_mode';
  static const _keyBookMetaFields = 'library_list_meta_fields';
  static const _keyBookMetaLayout = 'library_list_meta_layout';

  Future<AppLocale> getAppLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return AppLocale.fromStorage(prefs.getString(_keyAppLocale));
  }

  Future<void> setAppLocale(AppLocale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppLocale, locale.storageValue);
  }

  Future<AppThemeMode> getAppThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return AppThemeMode.fromStorage(prefs.getString(_keyAppThemeMode));
  }

  Future<void> setAppThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppThemeMode, mode.storageValue);
  }

  /// Google Cloud Vision API key used for OCR text scanning (title, author,
  /// illustrator, ISBN, publisher). Optional: when unset, OCR scans fall
  /// back to on-device ML Kit text recognition, which is free and offline
  /// but only reads Latin-script text — Cloud Vision also reads Thai.
  Future<String?> getCloudVisionApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCloudVisionApiKey);
  }

  Future<void> setCloudVisionApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.trim().isEmpty) {
      await prefs.remove(_keyCloudVisionApiKey);
    } else {
      await prefs.setString(_keyCloudVisionApiKey, key.trim());
    }
  }

  Future<LibraryViewMode> getLibraryViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return LibraryViewMode.fromStorage(prefs.getString(_keyLibraryViewMode));
  }

  Future<void> setLibraryViewMode(LibraryViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLibraryViewMode, mode.storageValue);
  }

  Future<LibrarySortField> getLibrarySortField() async {
    final prefs = await SharedPreferences.getInstance();
    return LibrarySortField.fromStorage(prefs.getString(_keyLibrarySortField));
  }

  Future<void> setLibrarySortField(LibrarySortField field) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLibrarySortField, field.storageValue);
  }

  /// Which details the library list shows under each book's title. An
  /// unset preference means the user has never opened the setting, and
  /// yields [BookMetaField.defaults] rather than an empty row.
  Future<Set<BookMetaField>> getBookMetaFields() async {
    final prefs = await SharedPreferences.getInstance();
    return BookMetaField.fromStorage(prefs.getString(_keyBookMetaFields));
  }

  /// Stores [fields], including when it's empty — turning every detail off
  /// is a real choice, and must not read back as "never configured" and
  /// silently restore the defaults on the next launch.
  Future<void> setBookMetaFields(Set<BookMetaField> fields) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBookMetaFields, BookMetaField.toStorage(fields));
  }

  Future<BookMetaLayout> getBookMetaLayout() async {
    final prefs = await SharedPreferences.getInstance();
    return BookMetaLayout.fromStorage(prefs.getString(_keyBookMetaLayout));
  }

  Future<void> setBookMetaLayout(BookMetaLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBookMetaLayout, layout.storageValue);
  }
}
