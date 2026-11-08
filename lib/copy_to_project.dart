//==============================================================================
//    copy_to_project.dart — copy one pad into another saved project
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'dialogs.dart';
import 'l10n.dart';
import 'main.dart';
import 'pad_picker.dart';
import 'settings.dart';

//==============================================================================

/// Saved projects other than [current] (by file), sorted by name.
Future<List<File>> otherProjects(File current) async {
  final List<File> files = [];
  if (!await documentDirectory.exists()) return files;
  final String self = p.normalize(current.absolute.path);
  await for (final f in documentDirectory.list(followLinks: false)) {
    if (f is! File || !f.path.endsWith('.json')) continue;
    if (p.basename(f.path) == 'temp.json') continue;
    if (p.normalize(f.absolute.path) == self) continue;
    files.add(f);
  }
  files.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
  return files;
}

/// Puts a copy of [pad] (new identity, same sound file) at [target] in [dest] and saves it.
Future<void> copyPadInto(Settings dest, int target, PadSettings pad) async {
  dest.padSettings[target] = pad.duplicate();
  await dest.save();
}

/// The whole flow: pick a project, then a pad in it. Returns the project name
/// when the pad was copied, null when cancelled.
Future<String?> copyPadToProject(BuildContext context, PadSettings pad, File current) async {
  final files = await otherProjects(current);
  if (!context.mounted) return null;
  if (files.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.copyToProject),
        content: Text(S.copyToProjectNone),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.ok))],
      ),
    );
    return null;
  }

  final File? file = await showDialog<File>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(S.copyToProjectPick),
      children: [
        for (final f in files)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, f),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(p.basenameWithoutExtension(f.path), style: const TextStyle(fontSize: 18)),
            ),
          ),
      ],
    ),
  );
  if (file == null || !context.mounted) return null;

  Settings dest;
  try {
    dest = Settings.fromJson(file, await file.readAsString());
    dest.validate();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.copyToProjectError)));
    }
    return null;
  }
  if (!context.mounted) return null;

  final String name = dest.name.isNotEmpty ? dest.name : p.basenameWithoutExtension(file.path);
  final int? target = await showDialog<int>(
    context: context,
    builder: (_) => PadPickerDialog(project: dest, current: -1, title: S.copyToProjectPad(name)),
  );
  if (target == null || !context.mounted) return null;

  final existing = dest.padSettings[target];
  if (existing.hasSample) {
    final ok = await confirm(context, content: Text(S.overwriteConfirm(existing.caption)));
    if (!ok) return null;
  }
  await copyPadInto(dest, target, pad);
  return name;
}

//==============================================================================
