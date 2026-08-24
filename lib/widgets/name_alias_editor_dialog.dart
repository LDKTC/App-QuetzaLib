import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/name_alias_group.dart';

/// Opens the editor for one set of equivalent names and returns the names
/// the user settled on, or null if they cancelled.
///
/// An empty result is a real answer, not a cancel: clearing every name in
/// an existing set is how the caller is told to delete it.
Future<List<String>?> showNameAliasEditor(
  BuildContext context, {
  List<String> initialTerms = const [],
  bool isNew = true,
}) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _NameAliasEditorDialog(
      initialTerms: initialTerms,
      isNew: isNew,
    ),
  );
}

/// Collects the names of one set as removable chips plus a field for the
/// next one, so a set is built the way it reads — a bag of equivalent
/// words, with no type to pick and no "primary" name among them.
class _NameAliasEditorDialog extends StatefulWidget {
  const _NameAliasEditorDialog({
    required this.initialTerms,
    required this.isNew,
  });

  final List<String> initialTerms;
  final bool isNew;

  @override
  State<_NameAliasEditorDialog> createState() => _NameAliasEditorDialogState();
}

class _NameAliasEditorDialogState extends State<_NameAliasEditorDialog> {
  late final List<String> _terms = List.of(widget.initialTerms);
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Commits whatever is in the text field as another name. Duplicates
  /// (case-insensitively) just clear the field instead of piling up.
  void _commitPendingTerm() {
    final terms = NameAliasGroup.sanitizeTerms([..._terms, _controller.text]);
    setState(() {
      _terms
        ..clear()
        ..addAll(terms);
      _controller.clear();
    });
    _focusNode.requestFocus();
  }

  void _removeTerm(String term) {
    setState(() => _terms.remove(term));
  }

  void _save() {
    final terms = NameAliasGroup.sanitizeTerms([..._terms, _controller.text]);
    Navigator.of(context).pop(terms);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.isNew ? t.newNameSetTitle : t.editNameSetTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.nameSetHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_terms.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final term in _terms)
                    InputChip(
                      label: Text(term),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _removeTerm(term),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: t.nameSetTermField,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: t.addNameToSetTooltip,
                  onPressed: _commitPendingTerm,
                ),
              ),
              onSubmitted: (_) => _commitPendingTerm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        TextButton(onPressed: _save, child: Text(t.save)),
      ],
    );
  }
}
