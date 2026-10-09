//==============================================================================
//    load_screen.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'dialogs.dart';
import 'main.dart';
import 'settings.dart';
import 'l10n.dart';

//==============================================================================

class LoadScreen extends StatefulWidget {
  final List<File> files;

  const LoadScreen(this.files, {super.key});

  @override
  State<LoadScreen> createState() => _LoadScreenState();
}

//==============================================================================

class _LoadScreenState extends State<LoadScreen> {
  String _nameOf(File f) => p.basenameWithoutExtension(f.path);

  Future<void> _onChoose(File file) async {
    final ok = await confirm(context, title: Text(S.openConfirm(_nameOf(file))));
    if (!ok || !mounted) return;
    preferences.setString(GlobalPrefs.lastFileKey, file.absolute.path);
    Navigator.pop(context, file);
  }

  Future<void> _onDelete(File file) async {
    final ok = await confirm(context, title: Text(S.deleteConfirm(_nameOf(file))));
    if (!ok) return;
    try {
      await file.delete();
    } catch (_) {}
    setState(() => widget.files.remove(file));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.openProject)),
      body: widget.files.isEmpty
          ? Center(child: Text(S.noProject, textAlign: TextAlign.center))
          : ListView.separated(
              itemCount: widget.files.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final f = widget.files[i];
                return ListTile(
                  title: Text(_nameOf(f), style: const TextStyle(fontSize: 20)),
                  onTap: () => _onChoose(f),
                  trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _onDelete(f)),
                );
              },
            ),
    );
  }
}

//==============================================================================
