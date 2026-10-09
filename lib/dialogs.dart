//==============================================================================
//    dialogs.dart
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:flutter/material.dart';
import 'l10n.dart';

/// Yes/No confirmation (replaces the abandoned confirm_dialog package).
Future<bool> confirm(BuildContext context, {Widget? title, Widget? content}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: title,
      content: content,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.ok)),
      ],
    ),
  );
  return ok ?? false;
}

/// Asks for a line of text. Returns null when cancelled.
Future<String?> askText(BuildContext context, String title, {String initial = ''}) async {
  final controller = TextEditingController(text: initial);
  final ok = await confirm(
    context,
    title: Text(title),
    content: TextField(controller: controller, autofocus: true),
  );
  return ok ? controller.text : null;
}
