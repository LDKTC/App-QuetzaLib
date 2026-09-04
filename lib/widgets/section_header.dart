import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// A labeled rule between groups of books — the current sort field's
/// group key (a date, series name, or language/genre pair) — used by both
/// the grouped list view and the sectioned shelf views.
///
/// It reads as an underlined label in the brand color rather than a solid
/// filled bar: the groups are a navigational aid, so they should organize
/// the shelf without taking visual weight away from the covers.
///
/// When [onToggleExpanded] is given, the header also shows an expand/collapse
/// affordance for the shelf views' per-section row-vs-grid toggle.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  final String label;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final toggle = onToggleExpanded;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 18, toggle == null ? 16 : 4, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (toggle != null)
            IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              tooltip: isExpanded
                  ? t.collapseSectionTooltip
                  : t.expandSectionTooltip,
              icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: toggle,
            ),
        ],
      ),
    );
  }
}
