import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/name_alias_group.dart';

/// Opens a picker for pulling a subset of [group]'s names out into a
/// brand-new set of their own, and returns the picked names — or null if
/// cancelled.
///
/// Picking none, or picking every name in the set, isn't a valid split
/// (there'd be nothing left on one side), so the split action stays
/// disabled until the selection is a real subset.
Future<List<String>?> showNameAliasSplitDialog(
  BuildContext context,
  NameAliasGroup group,
) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _NameAliasSplitDialog(group: group),
  );
}

class _NameAliasSplitDialog extends StatefulWidget {
  const _NameAliasSplitDialog({required this.group});

  final NameAliasGroup group;

  @override
  State<_NameAliasSplitDialog> createState() => _NameAliasSplitDialogState();
}

class _NameAliasSplitDialogState extends State<_NameAliasSplitDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canSplit =
        _selected.isNotEmpty && _selected.length < widget.group.terms.length;

    return AlertDialog(
      title: Text(t.splitNameSetTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.splitNameSetHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final term in widget.group.terms)
                  FilterChip(
                    label: Text(term),
                    visualDensity: VisualDensity.compact,
                    selected: _selected.contains(term),
                    onSelected: (value) => setState(() {
                      if (value) {
                        _selected.add(term);
                      } else {
                        _selected.remove(term);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        TextButton(
          onPressed:
              canSplit ? () => Navigator.of(context).pop(_selected.toList()) : null,
          child: Text(t.splitNameSetAction),
        ),
      ],
    );
  }
}
