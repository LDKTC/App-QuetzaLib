import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/book.dart';
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
                    _MetaRow(book: book, t: t),
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

/// The tokens under the author line — the series it belongs to, the year,
/// and its length — each shown only when the book actually carries it, so a
/// bare manual entry doesn't render an empty row of icons.
///
/// Capped at the two most identifying facts on a single ellipsized line:
/// this is a list built for scanning many books, and letting the tokens
/// wrap would push every row to twice the height of its cover.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.book, required this.t});

  final Book book;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    final series = book.series;
    final volume = book.seriesVolumeDisplay;
    final year = _yearOf(book.publishedDate);
    final pageCount = book.pageCount;

    final items = <Widget>[
      if (series != null && series.isNotEmpty)
        MetaLabel(
          icon: Icons.collections_bookmark_outlined,
          label: volume == null ? series : t.seriesWithVolume(series, volume),
        ),
      if (year != null) MetaLabel(icon: Icons.event_outlined, label: year),
      if (pageCount != null && pageCount > 0)
        MetaLabel(
          icon: Icons.menu_book_outlined,
          label: t.pagesLabel(pageCount.toString()),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          for (final item in items.take(2)) ...[
            Flexible(child: item),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

/// The four-digit year out of a `publishedDate`, which arrives from the
/// metadata providers in whatever shape they use (`2019`, `2019-04`,
/// `2019-04-22`) — anything without a leading year renders nothing rather
/// than a confusing fragment.
String? _yearOf(String? publishedDate) {
  final match = RegExp(r'\d{4}').firstMatch(publishedDate ?? '');
  return match?.group(0);
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
