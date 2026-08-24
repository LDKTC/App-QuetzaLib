import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/category_list_view.dart';
import '../widgets/name_alias_list_view.dart';

/// Hosts the two lists that organize the library by name: the categories a
/// book can be filed under, and the name sets (`TH` / `thai` / `ไทย`) that
/// make searching any one name find all of them.
///
/// The "+" action belongs to whichever tab is showing, so each tab keeps
/// its own add flow (see `category_list_view.dart` /
/// `name_alias_list_view.dart`) and this screen only routes to it.
class CategoryManagerScreen extends StatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this)..addListener(_onTabChanged);

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  /// Rebuilds so the "+" action's tooltip matches the visible tab (its
  /// `onPressed` reads the index when tapped, but the tooltip is baked in
  /// at build time).
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  Future<void> _addForCurrentTab() {
    return _tabController.index == 0
        ? promptAddCategory(context)
        : promptAddNameAliasGroup(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isCategoriesTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.categoryManagerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: isCategoriesTab ? t.newCategoryTitle : t.newNameSetTitle,
            onPressed: _addForCurrentTab,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.category_outlined), text: t.categoriesTab),
            Tab(icon: const Icon(Icons.link), text: t.nameSetsTab),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [CategoryListView(), NameAliasListView()],
      ),
    );
  }
}
