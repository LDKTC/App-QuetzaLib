import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/book.dart';
import '../services/settings_service.dart';
import '../state/library_grouping.dart';
import '../state/library_provider.dart';
import '../theme.dart';
import '../widgets/book_list_tile.dart';
import '../widgets/book_preview_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_header.dart';
import '../widgets/shelf_grid_view.dart';
import 'book_detail_screen.dart';
import 'book_edit_screen.dart';
import 'isbn_entry_screen.dart';
import 'scan_cover_first_screen.dart';
import 'scan_screen.dart';

extension on LibraryViewMode {
  IconData get icon => switch (this) {
        LibraryViewMode.list => Icons.view_list_rounded,
        LibraryViewMode.shelfCover => Icons.grid_view_rounded,
        LibraryViewMode.shelfSpine => Icons.menu_book_rounded,
      };
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _viewModeButtonKey = GlobalKey();
  bool _searchExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openBook(BuildContext context, int bookId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: bookId)),
    );
  }

  void _toggleSearch(LibraryProvider library) {
    setState(() => _searchExpanded = !_searchExpanded);
    if (_searchExpanded) {
      _searchFocusNode.requestFocus();
    } else {
      _searchController.clear();
      library.setSearchQuery('');
    }
  }

  Future<void> _pickViewMode(LibraryProvider library) async {
    final button =
        _viewModeButtonKey.currentContext!.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
            button.size.bottomLeft(Offset.zero), ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final t = AppLocalizations.of(context);
    final selected = await showMenu<LibraryViewMode>(
      context: context,
      position: position,
      items: [
        for (final mode in LibraryViewMode.values)
          PopupMenuItem(
            value: mode,
            child: Row(
              children: [
                Icon(mode.icon, size: 20),
                const SizedBox(width: 12),
                Text(mode.label(t)),
                if (mode == library.viewMode) ...[
                  const Spacer(),
                  const Icon(Icons.check_rounded, size: 18),
                ],
              ],
            ),
          ),
      ],
    );
    if (selected != null) {
      library.setViewMode(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final books = library.filteredBooks;
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.myLibrary),
        actions: [
          IconButton(
            icon: Icon(
              _searchExpanded ? Icons.search_off_rounded : Icons.search_rounded,
            ),
            tooltip: _searchExpanded ? t.closeSearch : t.openSearch,
            onPressed: () => _toggleSearch(library),
          ),
          IconButton(
            key: _viewModeButtonKey,
            icon: Icon(library.viewMode.icon),
            tooltip: t.switchToViewMode(library.viewMode.next.label(t)),
            onPressed: library.cycleViewMode,
            onLongPress: () => _pickViewMode(library),
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _searchExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: t.searchHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          tooltip: t.scanToSearch,
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ScanScreen(mode: ScanMode.search),
                            ),
                          ),
                        ),
                        isDense: true,
                      ),
                      onChanged: library.setSearchQuery,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SelectButton<LibraryStatusFilter?>(
                    icon: Icons.filter_list_rounded,
                    tooltip: t.filterStatusLabel,
                    value: library.statusFilter,
                    isActive: library.statusFilter != null,
                    onChanged: library.setStatusFilter,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text('${t.filterAll} (${library.totalBookCount})'),
                      ),
                      for (final filter in LibraryStatusFilter.values)
                        DropdownMenuItem(
                          value: filter,
                          child: Text(
                            '${filter.label(t)} (${library.statusCounts[filter]})',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  _SelectButton<LibrarySortField>(
                    icon: Icons.sort_rounded,
                    tooltip: t.sortByLabel,
                    value: library.sortField,
                    onChanged: (field) {
                      if (field != null) library.setSortField(field);
                    },
                    items: [
                      for (final field in LibrarySortField.values)
                        DropdownMenuItem(value: field, child: Text(field.label(t))),
                    ],
                  ),
                  if (library.categories.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _SelectButton<int?>(
                      icon: Icons.category_rounded,
                      tooltip: t.filterCategoryLabel,
                      value: library.categoryFilterId,
                      isActive: library.categoryFilterId != null,
                      onChanged: library.setCategoryFilter,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('${t.filterAll} (${library.totalBookCount})'),
                        ),
                        for (final category in library.categories)
                          DropdownMenuItem(
                            value: category.id,
                            child: Text(
                              '${category.name} (${library.categoryCounts[category.id] ?? 0})',
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (!library.loading && books.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  t.bookCountLabel(books.length.toString()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          Expanded(
            child: library.loading
                ? const Center(child: CircularProgressIndicator())
                : books.isEmpty
                    ? const _EmptyState()
                    : (library.viewMode == LibraryViewMode.list
                        ? _BookListView(
                            books: books,
                            sortField: library.sortField,
                            library: library,
                            onTapBook: (bookId) => _openBook(context, bookId),
                          )
                        : ShelfGridView(
                            onTapBook: (bookId) => _openBook(context, bookId),
                          )),
          ),
        ],
      ),
      floatingActionButton: _AddBookMenu(),
    );
  }
}

/// A pill-shaped dropdown ("select") button: an icon plus the current
/// selection's label, tapping it opens the options menu — used for both the
/// status filter and the sort-field picker so the library screen only needs
/// one row for both instead of a full chip-per-option list.
///
/// When [isActive], the pill fills with the brand's secondary container
/// instead of sitting outlined on the background — so a filter that's
/// currently hiding books is visible at a glance rather than looking
/// identical to one that isn't.
class _SelectButton<T> extends StatelessWidget {
  const _SelectButton({
    required this.icon,
    required this.tooltip,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        isActive ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.secondaryContainer : null,
          border: isActive
              ? null
              : Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isDense: true,
                borderRadius: BorderRadius.circular(AppRadius.tile),
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: foreground,
                ),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
                selectedItemBuilder: (context) => [
                  for (final item in items)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DefaultTextStyle.merge(
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                        ),
                        child: item.child,
                      ),
                    ),
                ],
                items: items,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row in the sorted/grouped library list: either a book or the
/// section header (the date or series it was grouped under) that opens a
/// run of them.
sealed class _LibraryRow {}

class _HeaderRow extends _LibraryRow {
  _HeaderRow(this.label, this.count);
  final String label;

  /// How many books the header opens, shown as its badge. Counted up as
  /// the rows are built, since a group's size isn't known until the group
  /// key changes again.
  int count;
}

class _BookRow extends _LibraryRow {
  _BookRow(this.book);
  final Book book;
}

/// Turns the already-sorted [books] into header/book rows: a header is
/// inserted whenever the group key changes, carrying the size of the group
/// it opens. Books no longer need a divider row between them — each is its
/// own card, so the gap does the separating.
List<_LibraryRow> _buildLibraryRows(
  List<Book> books,
  LibrarySortField sortField,
  AppLocalizations t,
) {
  final rows = <_LibraryRow>[];
  _HeaderRow? currentHeader;
  String? lastHeader;
  for (final book in books) {
    final header = groupHeaderFor(book, sortField, t);
    if (header != null) {
      if (header != lastHeader) {
        currentHeader = _HeaderRow(header, 0);
        rows.add(currentHeader);
      }
      currentHeader!.count++;
    }
    rows.add(_BookRow(book));
    lastHeader = header;
  }
  return rows;
}

class _BookListView extends StatelessWidget {
  const _BookListView({
    required this.books,
    required this.sortField,
    required this.library,
    required this.onTapBook,
  });

  final List<Book> books;
  final LibrarySortField sortField;
  final LibraryProvider library;
  final void Function(int bookId) onTapBook;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rows = _buildLibraryRows(books, sortField, t);
    return ListView.builder(
      // Clears the extended action button, so the last book can still be
      // tapped once the list is scrolled to the bottom.
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return switch (row) {
          _HeaderRow(:final label, :final count) => SectionHeader(
              label: label,
              count: count,
            ),
          _BookRow(:final book) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: BookListTile(
                book: book,
                coverImagePath:
                    library.activeCoverPresetFor(book.id!)?.frontImagePath,
                currentStatus: library.currentStampFor(book.id!)?.type,
                onTap: () => onTapBook(book.id!),
                onLongPress: () => showBookPreview(
                  context,
                  book: book,
                  coverImagePath:
                      library.activeCoverPresetFor(book.id!)?.frontImagePath,
                  currentStatus: library.currentStampFor(book.id!)?.type,
                  onOpenDetails: () => onTapBook(book.id!),
                ),
              ),
            ),
        };
      },
    );
  }
}

/// The library with nothing in it: the shared empty state, pointed at the
/// scan flow — the first screen a new user sees, so it offers the way in
/// rather than leaving them to find the floating action button.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.auto_stories_rounded,
      title: t.noBooksYet,
      message: t.emptyLibraryHint,
      action: FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        ),
        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
        label: Text(t.scanIsbnBarcode),
      ),
    );
  }
}

class _AddBookMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return MenuAnchor(
      builder: (context, controller, child) {
        return FloatingActionButton.extended(
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.add_rounded),
          label: Text(t.addBookLabel),
        );
      },
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.qr_code_scanner_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScanScreen()),
          ),
          child: Text(t.scanIsbnBarcode),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.pin_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const IsbnEntryScreen()),
          ),
          child: Text(t.enterIsbnNumber),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.add_a_photo_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ScanCoverFirstScreen()),
          ),
          child: Text(t.scanCoverFirstLabel),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BookEditScreen()),
          ),
          child: Text(t.addManually),
        ),
      ],
    );
  }
}
