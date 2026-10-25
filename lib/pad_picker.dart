//==============================================================================
//    pad_picker.dart — pick a pad on any page (miniature grid)
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:flutter/material.dart';

import 'l10n.dart';
import 'settings.dart';

//==============================================================================

/// Shows the pad grid in miniature to pick a target pad (on any page).
class PadPickerDialog extends StatefulWidget {
  final Settings project;

  /// Pad being edited (framed, not selectable), or -1.
  final int current;
  final String title;

  /// When true, blank pads cannot be picked (e.g. a rundown step needs a sound).
  final bool onlyWithSound;

  const PadPickerDialog({
    super.key,
    required this.project,
    required this.current,
    required this.title,
    this.onlyWithSound = false,
  });

  @override
  State<PadPickerDialog> createState() => _PadPickerDialogState();
}

class _PadPickerDialogState extends State<PadPickerDialog> {
  late int _page = widget.current >= 0 ? widget.project.pageOf(widget.current) : widget.project.currentPage;

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
                                onTap: isCurrent || (widget.onlyWithSound && !pad.hasSample)
                                    ? null
                                    : () => Navigator.pop(context, i),
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
