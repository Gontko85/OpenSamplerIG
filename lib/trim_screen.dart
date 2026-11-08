//==============================================================================
//    trim_screen.dart — start and end point of a pad's sound (no audio editor)
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'l10n.dart';
import 'sample_engine.dart';
import 'settings.dart';

//==============================================================================

/// "1:03,5" (minutes:seconds, tenths).
String formatTrimTime(int ms) {
  final int tenths = (ms / 100).round();
  final int m = tenths ~/ 600;
  final int sec = (tenths ~/ 10) % 60;
  final int t = tenths % 10;
  final String sep = S.code == 'fr' ? ',' : '.';
  return '$m:${sec.toString().padLeft(2, '0')}$sep$t';
}

/// Chooses where the sound of [pad] starts and ends. Writes [PadSettings.startMs]
/// and [PadSettings.endMs] as it goes (0 = file start / file end).
class TrimScreen extends StatefulWidget {
  final PadSettings pad;

  /// Test hook: skip the audio player (no platform channel in widget tests).
  final bool withPlayer;

  const TrimScreen(this.pad, {super.key, this.withPlayer = true});

  @override
  State<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends State<TrimScreen> {
  PadSettings get _pad => widget.pad;

  int _total = 0; // file length in ms (0 = unknown / loading)
  bool _loading = true;
  late int _start = _pad.startMs;
  late int _end = _pad.endMs;

  AudioPlayer? _player;
  StreamSubscription<Duration>? _posSub;
  bool _listening = false;
  int _pos = 0; // listening position in the file (ms)

  int get _endOrTotal => _end > 0 ? _end : _total;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    int total = _pad.durationMs;
    if (widget.withPlayer) {
      try {
        final p = AudioPlayer(playerId: 'trim_preview');
        await p.setPlayerMode(PlayerMode.mediaPlayer);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(_pad.volume);
        await p.setSource(DeviceFileSource(_pad.sample));
        if (total <= 0) total = (await p.getDuration())?.inMilliseconds ?? 0;
        _posSub = p.onPositionChanged.listen(_onPosition);
        p.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _listening = false);
        });
        _player = p;
      } catch (_) {
        if (total <= 0) total = (await SampleEngine.probeDuration(_pad.sample))?.inMilliseconds ?? 0;
      }
    }
    if (!mounted) return;
    setState(() {
      _total = total;
      if (total > 0 && _pad.durationMs <= 0) _pad.durationMs = total;
      if (_start >= total) _start = 0;
      if (_end >= total || (_end > 0 && _end <= _start)) _end = 0;
      _loading = false;
    });
  }

  void _onPosition(Duration d) {
    if (!mounted || !_listening) return;
    final int ms = d.inMilliseconds;
    if (ms >= _endOrTotal) {
      _stopListening();
      return;
    }
    setState(() => _pos = ms);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  //----------------------------------------------------------------------------

  void _write() {
    _pad.startMs = _start;
    // Too close to the file end: no end point at all.
    _pad.endMs = (_end > 0 && _end < _total - 50) ? _end : 0;
  }

  void _setStart(int ms) => setState(() {
    _start = ms.clamp(0, _endOrTotal - 200).toInt();
    if (_start < 0) _start = 0;
    _write();
  });

  void _setEnd(int ms) => setState(() {
    final int v = ms.clamp(_start + 200, _total).toInt();
    _end = v >= _total - 50 ? 0 : v;
    _write();
  });

  Future<void> _listenFrom(int ms) async {
    final p = _player;
    if (p == null) return;
    setState(() {
      _listening = true;
      _pos = ms;
    });
    await p.seek(Duration(milliseconds: ms));
    await p.resume();
  }

  Future<void> _stopListening() async {
    if (mounted) setState(() => _listening = false);
    await _player?.pause();
  }

  //----------------------------------------------------------------------------

  Widget _pointRow({required String label, required int value, required ValueChanged<int> onChanged}) {
    Widget nudge(String text, int delta) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          onPressed: () => onChanged(value + delta),
          child: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
    final String sep = S.code == 'fr' ? ',' : '.';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        child: Column(
          children: [
            Row(
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 12),
                Text(
                  formatTrimTime(value),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Tooltip(
                  message: S.trimSetHereTip,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _listening ? () => onChanged(_pos) : null,
                    icon: const Icon(Icons.push_pin_outlined, size: 18),
                    label: Text(S.trimSetHere),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                nudge('−1 s', -1000),
                nudge('−0${sep}1 s', -100),
                nudge('+0${sep}1 s', 100),
                nudge('+1 s', 1000),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(S.trimTitle),
        actions: [
          IconButton(
            tooltip: S.trimReset,
            icon: const Icon(Icons.settings_backup_restore),
            onPressed: _total > 0
                ? () => setState(() {
                    _start = 0;
                    _end = 0;
                    _write();
                  })
                : null,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _total <= 0
          ? Center(
              child: Padding(padding: const EdgeInsets.all(24), child: Text(S.trimUnknown)),
            )
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                children: [
                  Text(
                    _pad.caption,
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(S.trimHint, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  // Whole file, kept part, listening position.
                  RangeSlider(
                    min: 0,
                    max: _total.toDouble(),
                    values: RangeValues(_start.toDouble(), _endOrTotal.toDouble()),
                    onChanged: (r) {
                      if (r.start.round() != _start) _setStart(r.start.round());
                      if (r.end.round() != _endOrTotal) _setEnd(r.end.round());
                    },
                  ),
                  SizedBox(
                    height: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: LinearProgressIndicator(
                        value: _listening ? (_pos / _total).clamp(0.0, 1.0) : 0,
                        backgroundColor: Colors.transparent,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Row(
                      children: [
                        Text('0:00', style: theme.textTheme.bodySmall),
                        const Spacer(),
                        Text(
                          S.trimPlayed(formatTrimTime(_endOrTotal - _start)),
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(formatTrimTime(_total), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _pointRow(label: S.trimStart, value: _start, onChanged: _setStart),
                  _pointRow(label: S.trimEnd, value: _endOrTotal, onChanged: _setEnd),
                  const SizedBox(height: 14),
                  if (_listening)
                    Text(
                      formatTrimTime(_pos),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _player == null ? null : () => _listenFrom(_start),
                        icon: const Icon(Icons.play_arrow),
                        label: Text(S.trimListenStart),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _player == null
                            ? null
                            : () => _listenFrom((_endOrTotal - 4000).clamp(_start, _endOrTotal)),
                        icon: const Icon(Icons.fast_forward),
                        label: Text(S.trimListenEnd),
                      ),
                      if (_listening)
                        OutlinedButton.icon(
                          onPressed: _stopListening,
                          icon: const Icon(Icons.stop),
                          label: Text(S.trimStop),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

//==============================================================================
