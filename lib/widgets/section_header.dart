import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';

/// The heading that opens a group of content — a shelf section's group key
/// (a date, series name, or language/genre pair), or a block of settings.
///
/// It reads as a short accent bar followed by the label, with an optional
/// icon, one line of supporting text, and a count badge on the trailing
/// edge. The accent bar is what does the grouping work: it marks where a
/// section starts without drawing a rule across the screen, so the covers
/// and cards below keep the visual weight.
///
/// When [onToggleExpanded] is given, the header also shows an
/// expand/collapse affordance for the shelf views' per-section row-vs-grid
/// toggle.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    this.count,
    this.color,
    this.trailing,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  final String label;

  /// One line under the label explaining what the section holds. Omitted
  /// by the shelf views, whose group keys speak for themselves.
  final String? subtitle;

  /// A glyph for the section, shown between the accent bar and the label.
  final IconData? icon;

  /// How many items the section holds, rendered as a badge tinted with the
  /// section's accent color.
  final int? count;

  /// The section's accent, defaulting to the brand primary. Settings
  /// blocks keep the default; screens that color-code their sections pass
  /// their own.
  final Color? color;

  /// An action for the section, placed after the count badge.
  final Widget? trailing;

  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final toggle = onToggleExpanded;
    final hasAction = toggle != null || trailing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 18, hasAction ? 4 : 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 26,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          if (toggle != null)
            IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              tooltip: isExpanded
                  ? t.collapseSectionTooltip
                  : t.expandSectionTooltip,
              icon: Icon(
                isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              onPressed: toggle,
            ),
        ],
      ),
    );
  }
}
