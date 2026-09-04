import 'package:flutter/material.dart';

import 'section_header.dart';

/// One block of the settings screen: the section's header, then the card
/// of controls it introduces.
///
/// Settings are a long single-column list, so the grouping has to be
/// obvious at a glance — an accented header opening a filled card reads as
/// a block far more quickly than a bold line of text and a horizontal rule
/// did. Shared so the language, OCR, backup, and update blocks can't drift
/// apart, since three of them live in different files.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;

  /// The card's contents, laid out in a start-aligned column.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(label: title, icon: icon),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
