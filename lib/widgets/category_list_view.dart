import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/library_provider.dart';

/// The categories tab of the category manager: the list of categories plus
/// the add/rename dialogs that maintain it. Split out of
/// `category_manager_screen.dart` when that screen gained a second tab
/// (name sets), so each tab owns its own list and dialogs.
class CategoryListView extends StatelessWidget {
  const CategoryListView({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final t = AppLocalizations.of(context);

    if (library.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t.noCategoriesYet, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.separated(
      itemCount: library.categories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final category = library.categories[index];
        final count = library.categoryCounts[category.id] ?? 0;
        final colorScheme = Theme.of(context).colorScheme;
        return ListTile(
          // The avatar carries the category's initial rather than being a
          // bare colored dot: it tells you which category you're looking at
          // while scanning, and it stays on-palette in both themes.
          leading: CircleAvatar(
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            child: Text(
              _initialOf(category.name),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(category.name),
          subtitle: Text(t.bookCountLabel(count.toString())),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: t.renameCategoryTitle,
                onPressed: () =>
                    promptRenameCategory(context, category.id!, category.name),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: t.delete,
                onPressed: () => library.deleteCategory(category.id!),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The single character shown in a category's avatar — its first
/// non-whitespace character, or a bullet for a name that has none.
String _initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '\u2022' : trimmed.characters.first.toUpperCase();
}

/// Asks for a name and adds a category. Called both from this tab and from
/// the hosting screen's "+" action.
Future<void> promptAddCategory(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final t = AppLocalizations.of(ctx);
      return AlertDialog(
        title: Text(t.newCategoryTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: t.categoryNameField),
          onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(t.add),
          ),
        ],
      );
    },
  );
  if (name != null && name.isNotEmpty && context.mounted) {
    await context.read<LibraryProvider>().addCategory(name);
  }
}

Future<void> promptRenameCategory(
  BuildContext context,
  int id,
  String currentName,
) async {
  final controller = TextEditingController(text: currentName);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final t = AppLocalizations.of(ctx);
      return AlertDialog(
        title: Text(t.renameCategoryTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(ctx).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(t.save),
          ),
        ],
      );
    },
  );
  if (name != null && name.isNotEmpty && context.mounted) {
    final library = context.read<LibraryProvider>();
    final category = library.categories.firstWhere((c) => c.id == id);
    await library.renameCategory(category, name);
  }
}
