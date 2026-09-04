import 'package:flutter/material.dart';

/// One piece of secondary information on a tile — a small glyph and a short
/// label, e.g. a publication year, a page count, or a series volume.
///
/// Tiles lay several of these out in a `Wrap` under the title, which is how
/// a row carries its details without turning into three stacked lines of
/// prose: each fact reads as its own token, and the row reflows instead of
/// truncating when the screen is narrow.
class MetaLabel extends StatelessWidget {
  const MetaLabel({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;

  /// Overrides the muted default, for a fact that needs attention of its
  /// own (an overdue date, a warning).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: effective),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: effective),
          ),
        ),
      ],
    );
  }
}
