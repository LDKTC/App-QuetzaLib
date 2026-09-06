import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/book_meta_field.dart';
import '../state/library_provider.dart';
import 'settings_section.dart';

/// The settings block that decides what the library list prints under each
/// book's title: which of the [BookMetaField]s to show, and whether they
/// stay on one line or wrap onto several.
///
/// The fields are filter chips rather than a column of switches — there are
/// nine of them, and as a wrapped row of chips the whole choice is visible
/// at once instead of pushing the rest of settings a screen and a half
/// down. Every toggle writes through immediately (no Save button), so the
/// list behind the settings screen is already correct on the way back.
class BookListDetailsSection extends StatelessWidget {
  const BookListDetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final library = context.watch<LibraryProvider>();
    final selected = library.bookMetaFields;

    return SettingsSection(
      title: t.listDetailsSectionTitle,
      icon: Icons.tune_rounded,
      children: [
        Text(t.listDetailsSectionBody, style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Text(t.listDetailsFieldsLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final field in BookMetaField.values)
              FilterChip(
                avatar: Icon(field.icon, size: 16),
                label: Text(field.label(t)),
                selected: selected.contains(field),
                onSelected: (enabled) =>
                    library.toggleBookMetaField(field, enabled),
              ),
          ],
        ),
        if (selected.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            t.listDetailsNoneHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(t.listDetailsLayoutLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<BookMetaLayout>(
          segments: [
            for (final layout in BookMetaLayout.values)
              ButtonSegment(value: layout, label: Text(layout.label(t))),
          ],
          selected: {library.bookMetaLayout},
          onSelectionChanged: (choice) =>
              library.setBookMetaLayout(choice.first),
        ),
        // Only the capped layout needs explaining — "Wrap" showing
        // everything is what it looks like.
        if (library.bookMetaLayout == BookMetaLayout.singleLine) ...[
          const SizedBox(height: 8),
          Text(
            t.listDetailsSingleLineHint(
              BookMetaLayout.singleLineLimit.toString(),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: library.bookListDetailsAreDefault
                ? null
                : library.resetBookListDetails,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(t.resetToDefault),
          ),
        ),
      ],
    );
  }
}
