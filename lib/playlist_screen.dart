//==============================================================================
//    playlist_screen.dart — the tracks of a playlist pad
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'l10n.dart';
import 'sample_store.dart';
import 'settings.dart';

//==============================================================================

/// Add, remove and reorder the tracks of a pad; choose in order / random.
/// Writes the result back into [pad] (first track = pad.sample).
class PlaylistScreen extends StatefulWidget {
  final PadSettings pad;

  const PlaylistScreen(this.pad, {super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late final List<String> _tracks = List.of(widget.pad.tracks);
  late bool _shuffle = widget.pad.shuffle;
  bool _adding = false;
  int _added = 0, _toAdd = 0;

  static String trackLabel(String path) =>
      p.basenameWithoutExtension(path).replaceFirst(RegExp(r'_\d{13}$'), '');

  void _writeBack() {
    final pad = widget.pad;
    if (_tracks.isEmpty) {
      pad.clearSound();
      return;
    }
    if (pad.sample != _tracks.first) pad.durationMs = 0;
    pad.sample = _tracks.first;
    pad.extraTracks = _tracks.sublist(1);
    pad.shuffle = _shuffle;
    if (pad.isPlaylist) pad.looped = false; // a playlist moves on instead of looping
  }

  Future<void> _addTracks() async {
    final picked = List.of(await FilePicker.pickFiles(type: FileType.audio));
    if (picked.isEmpty) return;
    picked.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _adding = true;
      _added = 0;
      _toAdd = picked.length;
    });
    for (final f in picked) {
      try {
        final stored = await SampleStore.import(f.name, f.readAsByteStream(), length: f.lengthSync());
        _tracks.add(stored);
      } catch (_) {}
      if (mounted) setState(() => _added++);
    }
    _writeBack();
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(S.playlistTitle(widget.pad.caption))),
      floatingActionButton: _adding
          ? null
          : FloatingActionButton.extended(
              onPressed: _addTracks,
              icon: const Icon(Icons.library_add),
              label: Text(S.playlistAdd),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.format_list_numbered),
                  label: Text(S.playlistInOrder),
                ),
                ButtonSegment(value: true, icon: const Icon(Icons.shuffle), label: Text(S.playlistShuffle)),
              ],
              selected: {_shuffle},
              onSelectionChanged: (v) => setState(() {
                _shuffle = v.first;
                _writeBack();
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              _shuffle ? S.playlistShuffleHint : S.playlistInOrderHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
          if (_adding)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(S.progressCount(_added, _toAdd)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: _toAdd > 0 ? _added / _toAdd : null),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _tracks.isEmpty
                ? Center(child: Text(S.playlistEmpty, textAlign: TextAlign.center))
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: _tracks.length,
                    onReorderItem: (from, to) => setState(() {
                      _tracks.insert(to, _tracks.removeAt(from));
                      _writeBack();
                    }),
                    itemBuilder: (_, i) => ListTile(
                      key: ValueKey('${_tracks[i]}#$i'),
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(trackLabel(_tracks[i]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: S.remove,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => setState(() {
                              _tracks.removeAt(i);
                              _writeBack();
                            }),
                          ),
                          ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

//==============================================================================
