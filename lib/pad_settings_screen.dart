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
import 'sample_store.dart';
import 'settings.dart';

//==============================================================================

class PadSettingsScreen extends StatefulWidget {
  final int col;
  final int row;
  final PadSettings pad;
  final Settings project;

  const PadSettingsScreen(this.col, this.row, this.pad, this.project, {super.key});

  @override
  State<PadSettingsScreen> createState() => _PadSettingsScreenState();
}

//==============================================================================

class _PadSettingsScreenState extends State<PadSettingsScreen> {
  bool _importing = false;

  PadSettings get _pad => widget.pad;

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
            .showSnackBar(SnackBar(content: Text('Cannot import this file: $e')));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _onRemoveSample() async {
    final ok = await confirm(context, content: const Text('Remove the sound from this pad?'));
    if (!ok) return;
    _pad.sample = "";
    _pad.durationMs = 0;
    await widget.project.save();
    setState(() {});
  }

  Future<void> _onChangeCaption() async {
    final text = await askText(context, 'Input pad name', initial: _pad.caption);
    if (text == null) return;
    _pad.caption = text;
    await widget.project.save();
    setState(() {});
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
    final String sampleName = _pad.hasSample ? _stripCopySuffix(p.basename(_pad.sample)) : "(none)";

    return Scaffold(
      appBar: AppBar(title: Text("Pad ${widget.row + 1} × ${widget.col + 1}")),
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

          const Text("Sound Clip:", style: label),
          Row(children: <Widget>[
            Expanded(child: Text(sampleName, overflow: TextOverflow.ellipsis)),
            if (_importing)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              if (_pad.hasSample)
                IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: _onRemoveSample),
              TextButton(onPressed: _onSelectSample, child: const Text("Select")),
            ],
          ]),
          const Divider(),

          const Text("Caption:", style: label),
          Row(children: <Widget>[
            Expanded(child: Text(_pad.caption, overflow: TextOverflow.ellipsis)),
            TextButton(onPressed: _onChangeCaption, child: const Text("Set")),
          ]),
          const Divider(),

          Row(children: <Widget>[
            const Text("Looped:", style: label),
            const Spacer(),
            Switch(value: _pad.looped, onChanged: (v) => setState(() => _pad.looped = v)),
          ]),
          const Divider(),

          Row(children: <Widget>[
            const Expanded(child: Text("Long sound (music, > 5 s):", style: label)),
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
            const Text("Behaviour when pressed while playing:", style: label),
            const Spacer(),
            DropdownButton<PressBehaviour>(
              value: _pad.behaviour,
              onChanged: (v) => setState(() => _pad.behaviour = v ?? PressBehaviour.restart),
              items: PressBehaviour.values
                  .map((b) => DropdownMenuItem(value: b, child: Text(pressBehaviourToString(b))))
                  .toList(),
            ),
          ]),
          const Divider(),

          Row(children: <Widget>[
            const Expanded(
              child: Text("Exclusion group:\nstarting this pad stops the others of the same group",
                  style: label),
            ),
            DropdownButton<int>(
              value: _pad.group,
              onChanged: (v) => setState(() => _pad.group = v ?? 0),
              items: List.generate(
                groupNames.length,
                (i) => DropdownMenuItem(value: i, child: Text(groupNames[i])),
              ),
            ),
          ]),
          const Divider(),

          Text("Pad Volume: ${(_pad.volume * 100).round()} %", style: label),
          Slider(
            value: _pad.volume * 100.0,
            min: 0,
            max: 100,
            divisions: 20,
            label: (_pad.volume * 100.0).round().toString(),
            onChanged: (double value) => setState(() => _pad.volume = value / 100.0),
          ),
          const Divider(),

          const Text("Pad Color:", style: label),
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

          const Text("Pad Text Color:", style: label),
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
