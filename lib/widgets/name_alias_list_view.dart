import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/name_alias_group.dart';
import '../state/library_provider.dart';
import 'name_alias_editor_dialog.dart';
import 'name_alias_split_dialog.dart';

/// The name-sets tab of the category manager: every [NameAliasGroup] the
/// user has defined, each shown as the bag of equivalent names it is.
///
/// Sets are untyped by design — nothing here asks which field a name
/// belongs to. The library search decides that at query time by comparing
/// a set's names against a book's author/illustrator/series/genre/
/// language/publisher/category values (never its title).
///
/// Long-pressing a set enters selection mode, where two or more sets can
/// be merged into one; a single set can also be split back apart into two
/// via its split action.
class NameAliasListView extends StatefulWidget {
  const NameAliasListView({super.key});

  @override
  State<NameAliasListView> createState() => _NameAliasListViewState();
}

class _NameAliasListViewState extends State<NameAliasListView> {
  final Set<int> _selectedIds = {};

  void _toggleSelected(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _mergeSelected() async {
    final ids = _selectedIds.toList();
    _clearSelection();
    await context.read<LibraryProvider>().mergeAliasGroups(ids);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final t = AppLocalizations.of(context);
    final groups = library.aliasGroups;

    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(t.noNameSetsYet, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                t.nameSetHelp,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_selectedIds.isNotEmpty)
          _SelectionBar(
            selectedCount: _selectedIds.length,
            onCancel: _clearSelection,
            onMerge: _selectedIds.length >= 2 ? _mergeSelected : null,
          ),
        Expanded(
          child: ListView.separated(
            itemCount: groups.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final group = groups[index];
              return _NameAliasTile(
                group: group,
                selectionActive: _selectedIds.isNotEmpty,
                selected: _selectedIds.contains(group.id),
                onToggleSelected: () => _toggleSelected(group.id!),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.onCancel,
    required this.onMerge,
  });

  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback? onMerge;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.selectedCountLabel(selectedCount.toString()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: t.cancelNameSetSelection,
              onPressed: onCancel,
            ),
            FilledButton.icon(
              icon: const Icon(Icons.merge_type),
              label: Text(t.mergeNameSetsAction),
              onPressed: onMerge,
            ),
          ],
        ),
      ),
    );
  }
}

class _NameAliasTile extends StatelessWidget {
  const _NameAliasTile({
    required this.group,
    required this.selectionActive,
    required this.selected,
    required this.onToggleSelected,
  });

  final NameAliasGroup group;
  final bool selectionActive;
  final bool selected;
  final VoidCallback onToggleSelected;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final library = context.read<LibraryProvider>();
    return InkWell(
      onTap: selectionActive
          ? onToggleSelected
          : () => promptEditNameAliasGroup(context, group),
      onLongPress: onToggleSelected,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
        child: Row(
          children: [
            if (selectionActive)
              Checkbox(value: selected, onChanged: (_) => onToggleSelected()),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: selectionActive ? 0 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final term in group.terms)
                          Chip(
                            label: Text(term),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide.none,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.nameCountLabel(group.terms.length.toString()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!selectionActive) ...[
              IconButton(
                icon: const Icon(Icons.call_split),
                tooltip: t.splitNameSetTooltip,
                onPressed: group.terms.length < 2
                    ? null
                    : () => promptSplitNameAliasGroup(context, group),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: t.editNameSetTitle,
                onPressed: () => promptEditNameAliasGroup(context, group),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: t.deleteNameSetTooltip,
                onPressed: () => library.deleteAliasGroup(group.id!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens an empty editor and saves the resulting set. Called from the
/// hosting screen's "+" action.
Future<void> promptAddNameAliasGroup(BuildContext context) async {
  final library = context.read<LibraryProvider>();
  final terms = await showNameAliasEditor(
    context,
    suggestions: library.nameSetSuggestions,
  );
  if (terms == null || terms.isEmpty || !context.mounted) return;
  await library.addAliasGroup(terms);
}

/// Opens [group] for editing. Clearing every name deletes the set (see
/// [LibraryProvider.updateAliasGroup]).
Future<void> promptEditNameAliasGroup(
  BuildContext context,
  NameAliasGroup group,
) async {
  final library = context.read<LibraryProvider>();
  final terms = await showNameAliasEditor(
    context,
    initialTerms: group.terms,
    isNew: false,
    suggestions: library.nameSetSuggestions,
  );
  if (terms == null || !context.mounted) return;
  await library.updateAliasGroup(group, terms);
}

/// Opens the split picker for [group] and, if names were picked, pulls
/// them out into a new set of their own.
Future<void> promptSplitNameAliasGroup(
  BuildContext context,
  NameAliasGroup group,
) async {
  final namesToExtract = await showNameAliasSplitDialog(context, group);
  if (namesToExtract == null || namesToExtract.isEmpty || !context.mounted) {
    return;
  }
  await context.read<LibraryProvider>().splitAliasGroup(group, namesToExtract);
}
