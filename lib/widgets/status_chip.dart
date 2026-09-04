import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/stamp.dart';
import '../theme.dart';

/// The icon used to represent a stamp type wherever it shows up in the UI
/// (the current-status chip, the timeline, the shelf badge). `null` means
/// "not started" (no stamps yet).
IconData stampIcon(StampType? type) {
  return switch (type) {
    null => Icons.menu_book_outlined,
    StampType.reading => Icons.auto_stories,
    StampType.finished => Icons.check_circle,
    StampType.dropped => Icons.block,
    StampType.paused => Icons.pause_circle_outline,
  };
}

/// The localized label for a stamp type — `null` reads as "not started".
String stampLabel(AppLocalizations t, StampType? type) {
  return switch (type) {
    null => t.statusNotStarted,
    StampType.reading => t.statusReading,
    StampType.finished => t.statusFinished,
    StampType.dropped => t.statusDropped,
    StampType.paused => t.statusPaused,
  };
}

/// The stamp type's semantic colors for the current theme — see
/// [StatusPalette], which is what makes these adapt to dark mode instead
/// of every status being a fixed `Colors.orange`/`green`/`red`.
StatusColors stampColors(BuildContext context, StampType? type) {
  final palette = StatusPalette.of(context);
  return switch (type) {
    null => palette.notStarted,
    StampType.reading => palette.reading,
    StampType.finished => palette.finished,
    StampType.dropped => palette.dropped,
    StampType.paused => palette.paused,
  };
}

/// Shows a book's *current* reading status: the type of its most recent
/// [ReadingStamp], or "Not started" when [currentType] is null (no stamps
/// yet).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.currentType});

  final StampType? currentType;

  @override
  Widget build(BuildContext context) {
    final colors = stampColors(context, currentType);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stampIcon(currentType), size: 14, color: colors.foreground),
          const SizedBox(width: 5),
          Text(
            stampLabel(AppLocalizations.of(context), currentType),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
