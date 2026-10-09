//==============================================================================
//    pad_settings_screen.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:path/path.dart' as p;

import 'dialogs.dart';
import 'l10n.dart';
import 'sample_store.dart';
import 'settings.dart';

//==============================================================================

class PadSettingsScreen extends StatefulWidget {
  final int col;
  final int row;
  final int index;
  final Settings project;

  /// Pops with the index of another pad when this pad was swapped with or
  /// copied to it, so the caller can reload both.
  const PadSettingsScreen(this.col, this.row, this.index, this.project, {super.key});

  @override
  State<PadSettingsScreen> createState() => _PadSettingsScreenState();
}

//==============================================================================

class _PadSettingsScreenState extends State<PadSettingsScreen> {
  bool _importing = false;

  PadSettings get _pad => widget.project.padSettings[widget.index];

  //----------------------------------------------------------------------------

  /// True when the caption is still an automatic one (empty, a pad number,
  /// or the name of the previous sample), so it may follow the new sample.
  bool _captionIsAutomatic(String oldSample) {
    final c = _pad.caption.trim();
    if (c.isEmpty) return true;
    if (double.tryParse(c) != null) return true; // was: double.parse → crashed on text
    if (oldSample.isNotEmpty && c == _stripCopySuffix(p.basenameWithoutExtension(oldSample))) {
      return true;
    }
    return false;
  }

  String _stripCopySuffix(String s) => s.replaceFirst(RegExp(r'_\d{13}$'), '');

  Future<void> _onSelectSample() async {
    final PlatformFile? picked = await FilePicker.pickFile(type: FileType.audio);
    if (picked == null) return;

    setState(() => _importing = true);
    try {
      final String oldSample = _pad.sample;
      final String stored = await SampleStore.import(
        picked.name,
        picked.readAsByteStream(),
        length: picked.lengthSync(),
      );

      final bool autoCaption = _captionIsAutomatic(oldSample);
      _pad.sample = stored;
      _pad.durationMs = 0;
      if (autoCaption) {
        _pad.caption = p.basenameWithoutExtension(picked.name);
      }
      await widget.project.save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.cannotImport(e))));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _onRemoveSample() async {
    final ok = await confirm(context, content: Text(S.removeConfirm));
    if (!ok) return;
    // Remove the sound AND its name: the pad goes back to a blank pad (shows its number).
    _pad.sample = "";
    _pad.durationMs = 0;
    _pad.caption = "${widget.index + 1}";
    await widget.project.save();
    setState(() {});
  }

  Future<void> _onChangeCaption() async {
    final text = await askText(context, S.padNamePrompt, initial: _pad.caption);
    if (text == null) return;
    _pad.caption = text;
    await widget.project.save();
    setState(() {});
  }

  //----------------------------------------------------------------------------

  Future<void> _arrange({required bool copy}) async {
    final int? target = await showDialog<int>(
      context: context,
      builder: (ctx) => _PadPickerDialog(
        project: widget.project,
        current: widget.index,
        title: copy ? S.pickTargetCopy : S.pickTargetSwap,
      ),
    );
    if (target == null || target == widget.index || !mounted) return;

    final pads = widget.project.padSettings;
    if (copy) {
      final dest = pads[target];
      if (dest.hasSample) {
        final ok = await confirm(context, content: Text(S.overwriteConfirm(dest.caption)));
        if (!ok) return;
      }
      pads[target] = PadSettings.copy(_pad);
    } else {
      final a = pads[widget.index];
      pads[widget.index] = pads[target];
      pads[target] = a;
      // A blank pad keeps showing its own position number.
      for (final i in [widget.index, target]) {
        final pad = pads[i];
        if (!pad.hasSample && int.tryParse(pad.caption) != null) pad.caption = '${i + 1}';
      }
    }
    await widget.project.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy ? S.copied : S.swapped)));
    Navigator.pop(context, target);
  }

  //----------------------------------------------------------------------------

  static const List<Color> _palette = [
    Color(0xFF9E9E9E), Color(0xFF424242), Color(0xFFE53935), Color(0xFFFB8C00),
    Color(0xFFFDD835), Color(0xFF43A047), Color(0xFF00897B), Color(0xFF039BE5),
    Color(0xFF3949AB), Color(0xFF8E24AA), Color(0xFFD81B60), Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 16);
    final String sampleName = _pad.hasSample ? _stripCopySuffix(p.basename(_pad.sample)) : S.none;

    return Scaffold(
      appBar: AppBar(title: Text(S.padTitle(widget.row + 1, widget.col + 1))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: <Widget>[
          // Live preview of the pad.
          Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _pad.color, borderRadius: BorderRadius.circular(6)),
            child: Text(_pad.caption, style: TextStyle(color: _pad.textColor, fontSize: 18)),
          ),
          const SizedBox(height: 12),

          Text(S.soundClip, style: label),
          Row(children: <Widget>[
            Expanded(child: Text(sampleName, overflow: TextOverflow.ellipsis)),
            if (_importing)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              if (_pad.hasSample)
                IconButton(tooltip: S.remove, icon: const Icon(Icons.delete_outline), onPressed: _onRemoveSample),
              TextButton(onPressed: _onSelectSample, child: Text(S.select)),
            ],
          ]),
          const Divider(),

          Text(S.caption, style: label),
          Row(children: <Widget>[
            Expanded(child: Text(_pad.caption, overflow: TextOverflow.ellipsis)),
            TextButton(onPressed: _onChangeCaption, child: Text(S.set)),
          ]),
          const Divider(),

          Text(S.arrange, style: label),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              onPressed: () => _arrange(copy: false),
              icon: const Icon(Icons.swap_horiz),
              label: Text(S.swapWith),
            ),
            OutlinedButton.icon(
              onPressed: _pad.hasSample ? () => _arrange(copy: true) : null,
              icon: const Icon(Icons.copy),
              label: Text(S.copyTo),
            ),
          ]),
          const Divider(),

          Row(children: <Widget>[
            Text(S.looped, style: label),
            const Spacer(),
            Switch(value: _pad.looped, onChanged: (v) => setState(() => _pad.looped = v)),
          ]),
          const Divider(),

          Row(children: <Widget>[
            Expanded(child: Text(S.longSound, style: label)),
            Switch(
              value: _pad.long,
              onChanged: (v) => setState(() {
                _pad.long = v;
                _pad.durationMs = 0;
              }),
            ),
          ]),
          const Divider(),

          Row(children: <Widget>[
            Expanded(child: Text(S.behaviour, style: label)),
            DropdownButton<PressBehaviour>(
              value: _pad.behaviour,
              onChanged: (v) => setState(() => _pad.behaviour = v ?? PressBehaviour.restart),
              items: PressBehaviour.values
                  .map((b) => DropdownMenuItem(value: b, child: Text(S.behaviourName(pressBehaviourToString(b)))))
                  .toList(),
            ),
          ]),
          const Divider(),

          Row(children: <Widget>[
            Expanded(child: Text(S.group, style: label)),
            DropdownButton<int>(
              value: _pad.group,
              onChanged: (v) => setState(() => _pad.group = v ?? 0),
              items: List.generate(
                groupNames.length,
                (i) => DropdownMenuItem(value: i, child: Text(S.groupName(i))),
              ),
            ),
          ]),
          const Divider(),

          Text(S.volume((_pad.volume * 100).round()), style: label),
          Slider(
            value: _pad.volume * 100.0,
            min: 0,
            max: 100,
            divisions: 20,
            label: (_pad.volume * 100.0).round().toString(),
            onChanged: (double value) => setState(() => _pad.volume = value / 100.0),
          ),
          const Divider(),

          Text(S.padColor, style: label),
          const SizedBox(height: 8),
          _PaletteRow(colors: _palette, onPick: (c) => setState(() => _pad.color = c)),
          SlidePicker(
            pickerColor: _pad.color,
            onColorChanged: (Color c) => setState(() => _pad.color = c.withAlpha(255)),
            colorModel: ColorModel.rgb,
            enableAlpha: false,
            displayThumbColor: true,
            showParams: false,
            showIndicator: false,
          ),
          const Divider(),

          Text(S.textColor, style: label),
          const SizedBox(height: 8),
          _PaletteRow(colors: _palette, onPick: (c) => setState(() => _pad.textColor = c)),
          SlidePicker(
            pickerColor: _pad.textColor,
            onColorChanged: (Color c) => setState(() => _pad.textColor = c.withAlpha(255)),
            colorModel: ColorModel.rgb,
            enableAlpha: false,
            displayThumbColor: true,
            showParams: false,
            showIndicator: false,
          ),
        ],
      ),
    );
  }
}

//==============================================================================

class _PaletteRow extends StatelessWidget {
  final List<Color> colors;
  final ValueChanged<Color> onPick;

  const _PaletteRow({required this.colors, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors
          .map((c) => InkWell(
                onTap: () => onPick(c),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

//==============================================================================

//==============================================================================

/// Shows the pad grid in miniature to pick a target pad.
class _PadPickerDialog extends StatelessWidget {
  final Settings project;
  final int current;
  final String title;

  const _PadPickerDialog({required this.project, required this.current, required this.title});

  @override
  Widget build(BuildContext context) {
    final int cols = project.x;
    final int rows = project.y;
    return AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 17)),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: SizedBox(
        width: 320,
        child: AspectRatio(
          aspectRatio: cols / rows * 1.4,
          child: Column(
            children: List.generate(rows, (r) => Expanded(
                  child: Row(
                    children: List.generate(cols, (c) {
                      final int i = r * cols + c;
                      final pad = project.padSettings[i];
                      final bool isCurrent = i == current;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Material(
                            color: pad.hasSample ? pad.color : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                            child: InkWell(
                              onTap: isCurrent ? null : () => Navigator.pop(context, i),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(2),
                                decoration: isCurrent
                                    ? BoxDecoration(
                                        border: Border.all(color: Colors.black, width: 2),
                                        borderRadius: BorderRadius.circular(4))
                                    : null,
                                child: Text(
                                  isCurrent ? '(${S.thisPad})' : pad.caption,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: pad.hasSample ? pad.textColor : Colors.black54,
                                    fontStyle: isCurrent ? FontStyle.italic : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                )),
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel))],
    );
  }
}
