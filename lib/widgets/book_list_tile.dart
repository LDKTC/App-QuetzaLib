import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/stamp.dart';
import '../theme.dart';
import 'app_image.dart';
import 'status_chip.dart';

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
    final path = coverImagePath ?? book.thumbnailUrl;

    // The status chip stays on the trailing edge rather than stacking under
    // the author: a library list is for scanning many books at once, so the
    // row keeps roughly its original height instead of growing by half.
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
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
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    book.authorsDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StatusChip(currentType: currentStatus),
          ],
        ),
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
