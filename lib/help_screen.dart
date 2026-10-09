//==============================================================================
//    help_screen.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:flutter/material.dart';

import 'l10n.dart';

//==============================================================================

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    for (final (title, body) in S.helpSections) {
      if (body == null) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 18));
        children.add(Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)));
        children.add(const Divider());
      } else {
        children.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(body)));
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(S.help)),
      body: ListView(padding: const EdgeInsets.all(20), children: children),
    );
  }
}

//==============================================================================
