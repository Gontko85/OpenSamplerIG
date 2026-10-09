//==============================================================================
//    pad_tile.dart
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:flutter/material.dart';

import 'sample_engine.dart';
import 'settings.dart';

//==============================================================================

/// A single pad: colour, caption, progress bar, remaining time, state outline.
class PadTile extends StatelessWidget {
  final PadSettings settings;
  final PadVoice? voice;
  final double? fontSize;
  final bool showRemaining;
  final bool stageLock;
  final VoidCallback onTrigger;
  final VoidCallback onEdit;

  const PadTile({
    super.key,
    required this.settings,
    required this.voice,
    required this.fontSize,
    required this.showRemaining,
    required this.stageLock,
    required this.onTrigger,
    required this.onEdit,
  });

  static String formatDuration(Duration d) {
    final int s = (d.inMilliseconds / 1000).ceil();
    final int m = s ~/ 60;
    final int r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final v = voice;
    final VoiceState state = v?.state ?? VoiceState.idle;
    final bool active = state != VoiceState.idle;
    final double? progress = active ? v?.progress : null;
    final bool dark = settings.color.computeLuminance() < 0.45;

    // Progress fill: lighter on dark pads, darker on light pads.
    final Color fill = dark ? Colors.white.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.22);

    Color? outline;
    switch (state) {
      case VoiceState.playing:
        outline = Colors.white;
        break;
      case VoiceState.fading:
        outline = Colors.white54;
        break;
      case VoiceState.paused:
        outline = Colors.amber;
        break;
      case VoiceState.idle:
        outline = null;
        break;
    }

    final TextStyle captionStyle = TextStyle(
      color: settings.textColor,
      fontSize: fontSize,
      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
    );
    final TextStyle smallStyle = TextStyle(
      color: settings.textColor.withValues(alpha: 0.9),
      fontSize: 12,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w600,
    );

    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        // Progress fill, left to right.
        if (progress != null)
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              heightFactor: 1,
              child: ColoredBox(color: fill),
            ),
          ),
        // Thin bar at the bottom, always readable even with a busy fill.
        if (progress != null)
          Align(
            alignment: Alignment.bottomLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(height: 4, color: settings.textColor.withValues(alpha: 0.85)),
            ),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              settings.caption,
              textAlign: TextAlign.center,
              style: captionStyle,
              overflow: TextOverflow.fade,
            ),
          ),
        ),
        // Exclusion group badge.
        if (settings.group > 0)
          Positioned(
            left: 5,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                border: Border.all(color: settings.textColor.withValues(alpha: 0.7)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(groupNames[settings.group], style: smallStyle.copyWith(fontSize: 10)),
            ),
          ),
        // Loop / paused / missing indicators.
        Positioned(
          right: 4,
          top: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (settings.looped && settings.hasSample)
                Icon(Icons.repeat, size: 14, color: settings.textColor.withValues(alpha: 0.7)),
              if (state == VoiceState.paused) Icon(Icons.pause, size: 16, color: settings.textColor),
              if (v?.missing ?? false) const Icon(Icons.error, size: 16, color: Colors.redAccent),
            ],
          ),
        ),
        // Remaining time.
        if (showRemaining && active && v?.remaining != null)
          Positioned(
            right: 5,
            bottom: 7,
            child: Text(
              settings.looped ? formatDuration(v!.position) : '-${formatDuration(v!.remaining!)}',
              style: smallStyle,
            ),
          ),
      ],
    );

    final decoration = BoxDecoration(
      color: settings.color,
      borderRadius: BorderRadius.circular(6),
      border: outline != null ? Border.all(color: outline, width: 3) : null,
      boxShadow: state == VoiceState.playing
          ? [BoxShadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 10, spreadRadius: 1)]
          : null,
    );

    final Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (stageLock) {
      // Stage mode: trigger on finger down (no tap-up delay), several pads at once,
      // and no long press, so nothing can be reconfigured by accident.
      return Listener(behavior: HitTestBehavior.opaque, onPointerDown: (_) => onTrigger(), child: body);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTrigger,
        onLongPress: onEdit,
        enableFeedback: false,
        child: body,
      ),
    );
  }
}

//==============================================================================
