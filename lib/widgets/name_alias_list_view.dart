import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/name_alias_group.dart';
import '../state/library_provider.dart';
import 'name_alias_editor_dialog.dart';

/// The name-sets tab of the category manager: every [NameAliasGroup] the
/// user has defined, each shown as the bag of equivalent names it is.
///
/// Sets are untyped by design — nothing here asks which field a name
/// belongs to. The library search decides that at query time by comparing
/// a set's names against a book's author/illustrator/series/genre/
/// language/publisher/category values (never its title).
class NameAliasListView extends StatelessWidget {
  const NameAliasListView({super.key});

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

    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _NameAliasTile(group: groups[index]),
    );
  }
}

class _NameAliasTile extends StatelessWidget {
  const _NameAliasTile({required this.group});

  final NameAliasGroup group;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final library = context.read<LibraryProvider>();
    return InkWell(
      onTap: () => promptEditNameAliasGroup(context, group),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
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
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
        ),
      ),
    );
  }
}

/// Opens an empty editor and saves the resulting set. Called from the
/// hosting screen's "+" action.
Future<void> promptAddNameAliasGroup(BuildContext context) async {
  final terms = await showNameAliasEditor(context);
  if (terms == null || terms.isEmpty || !context.mounted) return;
  await context.read<LibraryProvider>().addAliasGroup(terms);
}

/// Opens [group] for editing. Clearing every name deletes the set (see
/// [LibraryProvider.updateAliasGroup]).
Future<void> promptEditNameAliasGroup(
  BuildContext context,
  NameAliasGroup group,
) async {
  final terms = await showNameAliasEditor(
    context,
    initialTerms: group.terms,
    isNew: false,
  );
  if (terms == null || !context.mounted) return;
  await context.read<LibraryProvider>().updateAliasGroup(group, terms);
}
