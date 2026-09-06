import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/book.dart';
import '../models/book_meta_field.dart';
import '../models/stamp.dart';
import '../theme.dart';
import 'app_image.dart';
import 'meta_label.dart';
import 'status_chip.dart';

/// One book in the library list: a soft card holding a status stripe, the
/// cover, the title block, and the current reading status.
///
/// The row is a card rather than a bare list row so the list reads as a
/// stack of separate books instead of one long ruled table — the same
/// treatment the shelf views give a cover. The stripe down the leading edge
/// repeats the status chip's color, so a scroll through the library shows
/// what's being read and what's finished without reading a single word.
class BookListTile extends StatelessWidget {
  const BookListTile({
    super.key,
    required this.book,
    this.coverImagePath,
    required this.currentStatus,
    required this.onTap,
    this.onLongPress,
    this.metaFields = BookMetaField.defaults,
    this.metaLayout = BookMetaLayout.singleLine,
    this.categoryNames = const [],
  });

  final Book book;

  /// The book's scanned front-cover photo (its active preset's
  /// `frontImagePath`), preferred over [Book.thumbnailUrl] when present —
  /// the user's own scan of the physical book beats the generic API cover.
  final String? coverImagePath;
  final StampType? currentStatus;
  final VoidCallback onTap;

  /// Long-pressing shows a quick preview sheet instead of navigating in.
  final VoidCallback? onLongPress;

  /// Which secondary details to print under the title, and how to lay them
  /// out — both come from the user's "Book list details" setting (see
  /// [BookMetaField]). Defaulted rather than required so a tile built
  /// outside the library screen, with no provider to read the setting from,
  /// still shows what the list showed before any of this was configurable.
  final Set<BookMetaField> metaFields;
  final BookMetaLayout metaLayout;

  /// The book's linked category names, for [BookMetaField.category]. They
  /// live in their own table, so unlike every other detail they can't be
  /// read off [book] and have to be passed in.
  final List<String> categoryNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final path = coverImagePath ?? book.thumbnailUrl;
    final accent = stampColors(context, currentStatus).foreground;

    // The status chip stays on the trailing edge rather than stacking under
    // the author: a library list is for scanning many books at once, so the
    // row keeps roughly its original height instead of growing by half.
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 68,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              _Cover(path: path),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.authorsDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    _MetaRow(
                      tokens: bookMetaTokens(
                        book,
                        fields: metaFields,
                        t: t,
                        categoryNames: categoryNames,
                      ),
                      layout: metaLayout,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(currentType: currentStatus),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tokens under the author line — whichever details the user turned on
/// in settings, and only the ones the book actually carries, so a bare
/// manual entry doesn't render an empty row of icons.
///
/// [BookMetaLayout.singleLine] caps the row at
/// [BookMetaLayout.singleLineLimit] tokens on one ellipsized line, keeping
/// every row the height of its cover — this is a list built for scanning
/// many books at once, and letting the tokens wrap would push every row to
/// twice that height. [BookMetaLayout.wrapped] accepts exactly that cost
/// for a reader who'd rather see the whole record than scan quickly.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.tokens, required this.layout});

  final List<BookMetaToken> tokens;
  final BookMetaLayout layout;

  @override
  Widget build(BuildContext context) {
    if (tokens.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: layout == BookMetaLayout.wrapped
          ? Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                for (final token in tokens)
                  MetaLabel(icon: token.icon, label: token.label),
              ],
            )
          : Row(
              children: [
                for (final (index, token)
                    in tokens.take(BookMetaLayout.singleLineLimit).indexed) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Flexible(
                    child: MetaLabel(icon: token.icon, label: token.label),
                  ),
                ],
              ],
            ),
    );
  }
}

/// The row's cover thumbnail: rounded and lightly shadowed so it reads as
/// the same object the shelf views show, with a neutral book placeholder
/// when the book has neither a scanned cover nor an API thumbnail.
class _Cover extends StatelessWidget {
  const _Cover({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.menu_book_outlined,
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
    );
    final imagePath = path;

    return Container(
      width: 46,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.cover),
        boxShadow: coverShadow(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.cover),
        child: imagePath == null
            ? placeholder
            : AppImage(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
      ),
    );
  }
}
