import 'package:flutter/material.dart';

/// What a list shows when it has nothing in it: a soft circular glyph, the
/// headline, an optional line of explanation, and an optional way out.
///
/// Shared rather than re-written per screen so the library, the category
/// list, and the name-set list all report "nothing here yet" at the same
/// size, spacing, and tone — an empty screen is often the first thing a new
/// user sees, so it should look designed rather than like a missing list.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;

  /// The headline — a short statement of what isn't there yet.
  final String title;

  /// Supporting text under [title], usually how to add the first item.
  final String? message;

  /// The primary way out of the empty state, e.g. the scan flow.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.secondaryContainer,
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}
