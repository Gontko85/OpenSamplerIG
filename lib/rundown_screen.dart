//==============================================================================
//    rundown_screen.dart — match rundowns ("conducteurs"): list and step editor
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:flutter/material.dart';

import 'dialogs.dart';
import 'l10n.dart';
import 'pad_picker.dart';
import 'settings.dart';

//==============================================================================

enum _RundownAction { rename, duplicate, delete }

/// The rundowns of a project. Edits [project] in place (the caller saves).
class RundownsScreen extends StatefulWidget {
  final Settings project;

  const RundownsScreen(this.project, {super.key});

  @override
  State<RundownsScreen> createState() => _RundownsScreenState();
}

class _RundownsScreenState extends State<RundownsScreen> {
  Settings get _project => widget.project;

  Future<void> _new() async {
    final name = await askText(
      context,
      S.rundownNamePrompt,
      initial: _project.rundowns.isEmpty ? S.rundownDefaultName : '',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final r = Rundown(name.trim());
    setState(() {
      _project.rundowns.add(r);
      _project.currentRundown = _project.rundowns.length - 1;
    });
    await _open(r);
  }

  Future<void> _open(Rundown r) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RundownEditScreen(_project, r)));
    if (mounted) setState(() {});
  }

  Future<void> _onAction(int i, _RundownAction a) async {
    final r = _project.rundowns[i];
    switch (a) {
      case _RundownAction.rename:
        final name = await askText(context, S.rundownNamePrompt, initial: r.name);
        if (name != null && name.trim().isNotEmpty) setState(() => r.name = name.trim());
        break;
      case _RundownAction.duplicate:
        setState(() {
          _project.rundowns.insert(
            i + 1,
            Rundown.copy(r)
              ..name = S.rundownCopyName(r.name)
              ..position = 0,
          );
        });
        break;
      case _RundownAction.delete:
        final ok = await confirm(context, content: Text(S.rundownDeleteConfirm(r.name)));
        if (!ok) return;
        setState(() {
          _project.rundowns.removeAt(i);
          if (_project.currentRundown > i || _project.currentRundown >= _project.rundowns.length) {
            _project.currentRundown = (_project.currentRundown - 1).clamp(0, 1 << 30);
          }
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _project.rundowns;
    return Scaffold(
      appBar: AppBar(title: Text(S.rundowns)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: Text(S.rundownNew),
      ),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(S.rundownsEmpty, textAlign: TextAlign.center),
              ),
            )
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: list.length,
              onReorderItem: (from, to) => setState(() {
                final current = _project.rundown;
                list.insert(to, list.removeAt(from));
                if (current != null) _project.currentRundown = list.indexOf(current);
              }),
              itemBuilder: (_, i) {
                final r = list[i];
                return ListTile(
                  key: ObjectKey(r),
                  leading: Icon(
                    Icons.playlist_play,
                    color: identical(r, _project.rundown) ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(r.name),
                  subtitle: Text(S.rundownSteps(r.steps.length)),
                  onTap: () => _open(r),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<_RundownAction>(
                        onSelected: (a) => _onAction(i, a),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: _RundownAction.rename, child: Text(S.rename)),
                          PopupMenuItem(value: _RundownAction.duplicate, child: Text(S.duplicate)),
                          PopupMenuItem(value: _RundownAction.delete, child: Text(S.delete)),
                        ],
                      ),
                      ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

//==============================================================================

/// Steps of one rundown: add (pad picker), note, reorder, delete.
class RundownEditScreen extends StatefulWidget {
  final Settings project;
  final Rundown rundown;

  const RundownEditScreen(this.project, this.rundown, {super.key});

  @override
  State<RundownEditScreen> createState() => _RundownEditScreenState();
}

class _RundownEditScreenState extends State<RundownEditScreen> {
  Settings get _project => widget.project;
  Rundown get _r => widget.rundown;

  Future<void> _addStep() async {
    final int? pad = await showDialog<int>(
      context: context,
      builder: (_) =>
          PadPickerDialog(project: _project, current: -1, title: S.rundownPickPad, onlyWithSound: true),
    );
    if (pad == null || !mounted) return;
    final p = _project.padSettings[pad];
    setState(() => _r.steps.add(RundownStep(p.id, caption: p.caption.trim())));
  }

  Future<void> _editNote(RundownStep s) async {
    final note = await askText(context, S.rundownNote, initial: s.note);
    if (note != null) setState(() => s.note = note.trim());
  }

  void _remove(int i) => setState(() {
    _r.steps.removeAt(i);
    if (_r.position > i) _r.position--;
    _r.position = _r.position.clamp(0, _r.steps.length);
  });

  void _reorder(int from, int to) => setState(() {
    // Keep "up next" on the same step.
    final RundownStep? next = _r.finished ? null : _r.steps[_r.position];
    _r.steps.insert(to, _r.steps.removeAt(from));
    _r.position = next == null ? _r.steps.length : _r.steps.indexOf(next);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_r.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStep,
        icon: const Icon(Icons.add),
        label: Text(S.rundownAddStep),
      ),
      body: _r.steps.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(S.rundownStepsEmpty, textAlign: TextAlign.center),
              ),
            )
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: _r.steps.length,
              onReorderItem: _reorder,
              itemBuilder: (_, i) {
                final s = _r.steps[i];
                final int pad = _project.padIndexOfStep(s);
                final String caption = _project.stepCaption(s);
                final String where = pad >= 0
                    ? S.rundownPage(_project.pageLabel(_project.pageOf(pad), S.pageN))
                    : S.rundownMissingPad;
                return ListTile(
                  key: ObjectKey(s),
                  leading: StepBadge(number: i + 1, color: pad >= 0 ? _project.padSettings[pad].color : null),
                  title: Text(
                    caption.isEmpty ? '—' : caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: pad < 0 ? TextStyle(color: theme.colorScheme.error) : null,
                  ),
                  subtitle: Text(
                    s.note.isEmpty ? where : '$where · ${s.note}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _editNote(s),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: S.rundownEditNote,
                        icon: const Icon(Icons.edit_note),
                        onPressed: () => _editNote(s),
                      ),
                      IconButton(
                        tooltip: S.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remove(i),
                      ),
                      ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

//==============================================================================

/// Step number in a disc of the pad's colour (grey with a cross when the pad is gone).
class StepBadge extends StatelessWidget {
  final int number;
  final Color? color;
  final double radius;

  const StepBadge({super.key, required this.number, this.color, this.radius = 15});

  @override
  Widget build(BuildContext context) {
    final Color bg = color ?? Colors.grey.shade700;
    final Color fg = bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: color == null
          ? Icon(Icons.close, size: radius, color: fg)
          : Text(
              '$number',
              style: TextStyle(fontSize: radius * 0.8, color: fg, fontWeight: FontWeight.bold),
            ),
    );
  }
}

//==============================================================================
