import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'category_manager_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _screens = [
    LibraryScreen(),
    CategoryManagerScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        // Outlined at rest, filled when selected: the destination you're on
        // reads as the solid one even before the label's weight registers.
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.auto_stories_outlined),
            selectedIcon: const Icon(Icons.auto_stories_rounded),
            label: t.navLibrary,
          ),
          NavigationDestination(
            icon: const Icon(Icons.category_outlined),
            selectedIcon: const Icon(Icons.category_rounded),
            label: t.navCategories,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: t.navSettings,
          ),
        ],
      ),
    );
  }
}
