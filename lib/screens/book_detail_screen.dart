import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/book.dart';
import '../models/cover_preset.dart';
import '../state/library_provider.dart';
import '../theme.dart';
import '../widgets/app_image.dart';
import '../widgets/book_3d_cover.dart';
import '../widgets/full_image_viewer.dart';
import '../widgets/meta_label.dart';
import '../widgets/stamp_timeline.dart';
import '../widgets/status_chip.dart';
import 'book_edit_screen.dart';
import 'book_pages_screen.dart';
import 'cover_presets_screen.dart';
import 'page_scan_screen.dart';

class BookDetailScreen extends StatelessWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final int bookId;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final book = library.getById(bookId);
    final t = AppLocalizations.of(context);

    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(t.bookRemovedMessage)),
      );
    }

    final categoryIds = library.categoryIdsFor(bookId).toSet();
    final categories =
        library.categories.where((c) => categoryIds.contains(c.id)).toList();
    final activePreset = library.activeCoverPresetFor(bookId);
    final pages = library.pagesFor(bookId);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: t.edit,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BookEditScreen(existingBook: book),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: t.delete,
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  final t = AppLocalizations.of(ctx);
                  return AlertDialog(
                    title: Text(t.removeBookTitle),
                    content: Text(t.deleteBookConfirm(book.title)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(t.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(t.delete),
                      ),
                    ],
                  );
                },
              );
              if (confirmed == true) {
                await library.deleteBook(bookId);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 104,
                height: 152,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.cover),
                  boxShadow: coverShadow(context),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.cover),
                  child: _CoverArt(book: book, activePreset: activePreset),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (book.series != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.seriesVolumeDisplay != null
                            ? t.seriesWithVolume(
                                book.series!, book.seriesVolumeDisplay!)
                            : book.series!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      book.authorsDisplay,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (book.illustrators.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        t.illustratedBy(book.illustrators.join(', ')),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    // Publisher, year, genre, language, length and ISBN as
                    // separate tokens instead of dot-joined lines: each fact
                    // is findable on its own, and the block reflows on a
                    // narrow screen instead of truncating mid-sentence.
                    const SizedBox(height: 8),
                    _BookFacts(book: book),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => CoverPresetsScreen(book: book)),
            ),
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: Text(activePreset == null ? t.scanCoverLabel : t.manageCoversLabel),
          ),
          _Section(
            title: t.readingStatusLabel,
            icon: Icons.auto_stories_rounded,
            trailing: StatusChip(currentType: library.currentStampFor(bookId)?.type),
            child: StampTimeline(bookId: bookId),
          ),
          _Section(
            title: t.categoriesLabel,
            icon: Icons.category_rounded,
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: t.editCategoriesTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: () => _pickCategories(context, bookId, categoryIds),
            ),
            child: categories.isEmpty
                ? Text(
                    t.noCategoriesAssignedHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in categories) Chip(label: Text(c.name)),
                    ],
                  ),
          ),
          _Section(
            title: t.savedPagesLabel,
            icon: Icons.photo_library_rounded,
            trailing: pages.isEmpty
                ? null
                : TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BookPagesScreen(book: book)),
                    ),
                    child: Text(t.viewAllLabel),
                  ),
            child: pages.isEmpty
                ? OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PageScanScreen(book: book)),
                    ),
                    icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                    label: Text(t.savePageTitle),
                  )
                : SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pages.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        if (index == pages.length) {
                          return _AddPageTile(book: book);
                        }
                        return _PageThumbnail(imagePath: pages[index].imagePath);
                      },
                    ),
                  ),
          ),
          if (book.description != null)
            _Section(
              title: t.descriptionLabel,
              icon: Icons.notes_rounded,
              child: Text(book.description!),
            ),
          if (book.notes != null)
            _Section(
              title: t.myNotesLabel,
              icon: Icons.edit_note_rounded,
              child: Text(book.notes!),
            ),
          if (book.source != null) ...[
            const SizedBox(height: 24),
            Text(
              t.sourceLabel(book.source!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _pickCategories(
  BuildContext context,
  int bookId,
  Set<int> currentIds,
) async {
  final result = await showDialog<Set<int>>(
    context: context,
    builder: (_) => _CategoryPickerDialog(initialSelectedIds: currentIds),
  );
  if (result != null && context.mounted) {
    await context.read<LibraryProvider>().setBookCategories(bookId, result.toList());
  }
}

class _CategoryPickerDialog extends StatefulWidget {
  const _CategoryPickerDialog({required this.initialSelectedIds});

  final Set<int> initialSelectedIds;

  @override
  State<_CategoryPickerDialog> createState() => _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends State<_CategoryPickerDialog> {
  late final Set<int> _selectedIds = {...widget.initialSelectedIds};

  Future<void> _addNewCategory(BuildContext context) async {
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
      final id = await context.read<LibraryProvider>().addCategory(name);
      if (mounted) setState(() => _selectedIds.add(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final t = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(t.selectCategoriesTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: library.categories.isEmpty
            ? Text(t.noCategoriesYet)
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in library.categories)
                        FilterChip(
                          label: Text(category.name),
                          selected: _selectedIds.contains(category.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedIds.add(category.id!);
                            } else {
                              _selectedIds.remove(category.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _addNewCategory(context),
          icon: const Icon(Icons.add, size: 18),
          label: Text(t.newCategoryTitle),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedIds),
          child: Text(t.save),
        ),
      ],
    );
  }
}

class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.book, required this.activePreset});

  final Book book;
  final BookCoverPreset? activePreset;

  /// Tapping the cover shows it full-screen: a proper 3D mockup when there's
  /// a cover preset with at least one scanned face, or a plain zoomable
  /// preview of the flat API thumbnail otherwise.
  void _open(BuildContext context) {
    final preset = activePreset;
    if (preset != null && !preset.isEmpty) {
      showBook3DPreview(context, preset);
      return;
    }
    final thumbnailUrl = book.thumbnailUrl;
    if (thumbnailUrl != null) {
      showFullImagePreview(context, thumbnailUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.menu_book_outlined, size: 32),
    );

    Widget image;
    final frontPath = activePreset?.frontImagePath;
    if (frontPath != null) {
      image = AppImage(
        frontPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    } else if (book.thumbnailUrl != null) {
      image = Image.network(
        book.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    } else {
      image = placeholder;
    }

    return InkWell(onTap: () => _open(context), child: image);
  }
}

/// The facts under a book's title — only the ones it actually carries, so
/// a hand-entered book doesn't render a row of empty labels.
class _BookFacts extends StatelessWidget {
  const _BookFacts({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pageCount = book.pageCount;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        if (book.publisher != null)
          MetaLabel(icon: Icons.apartment_rounded, label: book.publisher!),
        if (book.publishedDate != null)
          MetaLabel(icon: Icons.event_outlined, label: book.publishedDate!),
        if (book.genre != null)
          MetaLabel(icon: Icons.local_offer_outlined, label: book.genre!),
        if (book.language != null)
          MetaLabel(icon: Icons.translate_rounded, label: book.language!),
        if (pageCount != null && pageCount > 0)
          MetaLabel(
            icon: Icons.menu_book_outlined,
            label: t.pagesLabel(pageCount.toString()),
          ),
        if (book.isbn13 != null)
          MetaLabel(
            icon: Icons.qr_code_2_rounded,
            label: t.isbnLabel(book.isbn13!),
          ),
      ],
    );
  }
}

/// One block of the detail screen — a card opened by an accented heading,
/// with an optional trailing action. Every section below the header uses
/// it, so the reading timeline, categories, saved pages, description, and
/// notes share the same header weight, padding, and separation instead of
/// each being a bare label followed by an ad-hoc gap.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 32,
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(icon, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// One saved page in the detail screen's horizontal strip.
class _PageThumbnail extends StatelessWidget {
  const _PageThumbnail({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.cover);
    return InkWell(
      onTap: () => showFullImagePreview(context, imagePath),
      borderRadius: radius,
      child: Container(
        width: 72,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: coverShadow(context),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: AppImage(
            imagePath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "add another page" slot at the end of the saved-pages strip: an
/// outlined, tinted tile so it reads as an empty slot rather than as one
/// more saved page.
class _AddPageTile extends StatelessWidget {
  const _AddPageTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.cover);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PageScanScreen(book: book)),
      ),
      borderRadius: radius,
      child: Container(
        width: 72,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: radius,
        ),
        child: Icon(Icons.add_a_photo_outlined, color: colorScheme.primary),
      ),
    );
  }
}
