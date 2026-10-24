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
  late final TextEditingController _caption = TextEditingController(text: _pad.caption);

  PadSettings get _pad => widget.project.padSettings[widget.index];

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

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
        _caption.text = _pad.caption;
      }
      await widget.project.save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.cannotImport(e))));
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
    _pad.caption = "${widget.project.indexInPage(widget.index) + 1}";
    _caption.text = _pad.caption;
    await widget.project.save();
    setState(() {});
  }

  Future<void> _customColor({required bool text}) async {
    Color picked = text ? _pad.textColor : _pad.color;
    final ok = await confirm(
      context,
      title: Text(text ? S.textColor : S.padColor),
      content: SingleChildScrollView(
        child: SlidePicker(
          pickerColor: picked,
          onColorChanged: (c) => picked = c.withAlpha(255),
          colorModel: ColorModel.rgb,
          enableAlpha: false,
          displayThumbColor: true,
          showParams: false,
          showIndicator: true,
        ),
      ),
    );
    if (!ok) return;
    setState(() => text ? _pad.textColor = picked : _pad.color = picked);
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
        if (!pad.hasSample && int.tryParse(pad.caption) != null) {
          pad.caption = '${widget.project.indexInPage(i) + 1}';
        }
      }
    }
    await widget.project.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(copy ? S.copied : S.swapped)));
    Navigator.pop(context, target);
  }

  //----------------------------------------------------------------------------

  static const List<Color> _palette = [
    Color(0xFF9E9E9E),
    Color(0xFF424242),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFFE53935),
    Color(0xFFD81B60),
    Color(0xFF8E24AA),
    Color(0xFF3949AB),
    Color(0xFF039BE5),
    Color(0xFF00897B),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFFFDD835),
    Color(0xFFFB8C00),
    Color(0xFF6D4C41),
    Color(0xFF26C6DA),
  ];

  static const List<Color> _textPalette = [
    Color(0xFF000000),
    Color(0xFFFFFFFF),
    Color(0xFF424242),
    Color(0xFFFDD835),
    Color(0xFFE53935),
    Color(0xFF039BE5),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = theme.textTheme.labelLarge;
    final String sampleName = _pad.hasSample ? _stripCopySuffix(p.basename(_pad.sample)) : S.none;
    const gap = SizedBox(height: 10);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.project.pageCount > 1
              ? S.padTitleOnPage(
                  widget.project.pageLabel(widget.project.pageOf(widget.index), S.pageN),
                  widget.row + 1,
                  widget.col + 1,
                )
              : S.padTitle(widget.row + 1, widget.col + 1),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: S.swapWith,
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => _arrange(copy: false),
          ),
          IconButton(
            tooltip: S.copyTo,
            icon: const Icon(Icons.copy),
            onPressed: _pad.hasSample ? () => _arrange(copy: true) : null,
          ),
        ],
      ),
      // Everything fits on one screen; scrolling only kicks in on very small phones.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Live preview = name field: type the pad name right on the pad.
              Container(
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: _pad.color, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: TextField(
                  controller: _caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _pad.textColor, fontSize: 19, fontWeight: FontWeight.w600),
                  cursorColor: _pad.textColor,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: S.padNamePrompt,
                    hintStyle: TextStyle(color: _pad.textColor.withValues(alpha: 0.5)),
                    suffixIcon: Icon(Icons.edit, size: 16, color: _pad.textColor.withValues(alpha: 0.6)),
                    suffixIconConstraints: const BoxConstraints(minWidth: 20),
                  ),
                  onChanged: (v) => _pad.caption = v,
                ),
              ),
              gap,

              // 2. Sound file.
              Row(
                children: [
                  const Icon(Icons.music_note, size: 20),
                  const SizedBox(width: 6),
                  Expanded(child: Text(sampleName, overflow: TextOverflow.ellipsis, maxLines: 1)),
                  if (_importing)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else ...[
                    if (_pad.hasSample)
                      IconButton(
                        tooltip: S.remove,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _onRemoveSample,
                      ),
                    FilledButton.tonal(onPressed: _onSelectSample, child: Text(S.select)),
                  ],
                ],
              ),
              gap,

              // 3. Loop / long sound / exclusion group on one line.
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.repeat, size: 18),
                    label: Text(S.loopShort),
                    selected: _pad.looped,
                    showCheckmark: false,
                    onSelected: (v) => setState(() => _pad.looped = v),
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.queue_music, size: 18),
                    label: Text(S.longShort),
                    tooltip: S.longSound,
                    selected: _pad.long,
                    showCheckmark: false,
                    onSelected: (v) => setState(() {
                      _pad.long = v;
                      _pad.durationMs = 0;
                    }),
                  ),
                  Tooltip(
                    message: S.group,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${S.groupShort} ', style: label),
                        DropdownButton<int>(
                          value: _pad.group,
                          isDense: true,
                          onChanged: (v) => setState(() => _pad.group = v ?? 0),
                          items: List.generate(
                            groupNames.length,
                            (i) => DropdownMenuItem(value: i, child: Text(S.groupName(i))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              gap,

              // 4. What a press does while the sound plays.
              Text(S.behaviour, style: label),
              const SizedBox(height: 4),
              SegmentedButton<PressBehaviour>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  for (final b in [PressBehaviour.restart, PressBehaviour.stop, PressBehaviour.pause])
                    ButtonSegment(value: b, label: Text(S.behaviourName(pressBehaviourToString(b)))),
                ],
                selected: {_pad.behaviour},
                onSelectionChanged: (v) => setState(() => _pad.behaviour = v.first),
              ),
              gap,

              // 5. Volume.
              Row(
                children: [
                  const Icon(Icons.volume_up, size: 20),
                  Expanded(
                    child: Slider(
                      value: _pad.volume * 100.0,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${(_pad.volume * 100.0).round()} %',
                      onChanged: (double value) => setState(() => _pad.volume = value / 100.0),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${(_pad.volume * 100).round()} %', textAlign: TextAlign.end),
                  ),
                ],
              ),

              // 6. Colours: palettes, custom colour in a dialog.
              Text(S.padColor, style: label),
              const SizedBox(height: 6),
              _ColorRow(
                colors: _palette,
                selected: _pad.color,
                onPick: (c) => setState(() => _pad.color = c),
                onCustom: () => _customColor(text: false),
              ),
              gap,
              Text(S.textColor, style: label),
              const SizedBox(height: 6),
              _ColorRow(
                colors: _textPalette,
                selected: _pad.textColor,
                onPick: (c) => setState(() => _pad.textColor = c),
                onCustom: () => _customColor(text: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//==============================================================================

/// Colour swatches + a "custom colour" button. The current colour is ringed.
class _ColorRow extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onPick;
  final VoidCallback onCustom;

  const _ColorRow({
    required this.colors,
    required this.selected,
    required this.onPick,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.primary;
    final bool isCustom = !colors.any((c) => c.toARGB32() == selected.toARGB32());
    Widget dot(Color c, bool sel, {Widget? child, VoidCallback? onTap}) => InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: sel ? ring : Colors.black26, width: sel ? 3 : 1),
        ),
        child: child,
      ),
    );
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final c in colors) dot(c, c.toARGB32() == selected.toARGB32(), onTap: () => onPick(c)),
        dot(
          isCustom ? selected : Colors.transparent,
          isCustom,
          onTap: onCustom,
          child: Icon(Icons.palette_outlined, size: 18, color: isCustom ? null : Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

//==============================================================================

/// Shows the pad grid in miniature to pick a target pad (on any page).
class _PadPickerDialog extends StatefulWidget {
  final Settings project;
  final int current;
  final String title;

  const _PadPickerDialog({required this.project, required this.current, required this.title});

  @override
  State<_PadPickerDialog> createState() => _PadPickerDialogState();
}

class _PadPickerDialogState extends State<_PadPickerDialog> {
  late int _page = widget.project.pageOf(widget.current);

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final int cols = project.x;
    final int rows = project.y;
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 17)),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (project.pageCount > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (int p = 0; p < project.pageCount; p++)
                      ChoiceChip(
                        label: Text(project.pageLabel(p, S.pageN)),
                        selected: p == _page,
                        onSelected: (_) => setState(() => _page = p),
                      ),
                  ],
                ),
              ),
            AspectRatio(
              aspectRatio: cols / rows * 1.4,
              child: Column(
                children: List.generate(
                  rows,
                  (r) => Expanded(
                    child: Row(
                      children: List.generate(cols, (c) {
                        final int i = project.globalIndex(_page, r * cols + c);
                        final pad = project.padSettings[i];
                        final bool isCurrent = i == widget.current;
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
                                          borderRadius: BorderRadius.circular(4),
                                        )
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel))],
    );
  }
}
