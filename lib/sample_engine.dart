//==============================================================================
//    sample_engine.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021 (original SamplePlayer)
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'settings.dart';

//==============================================================================

enum VoiceState { idle, playing, paused, fading }

//==============================================================================

/// One pad's audio player, plus the bookkeeping needed to draw its progress.
///
/// Position is tracked with our own clock because "low latency" players
/// (Android SoundPool) report neither position nor end of playback. For
/// "long sound" pads the clock is re-synchronised with the real position.
class PadVoice {
  final int index;
  final PadSettings settings;
  AudioPlayer? player;
  Duration? duration;
  bool missing = false;

  VoiceState state = VoiceState.idle;

  final Stopwatch _clock = Stopwatch();
  Duration _offset = Duration.zero;
  DateTime _ignorePositionUntil = DateTime.fromMillisecondsSinceEpoch(0);

  Timer? _fadeTimer;
  final List<StreamSubscription> _subs = [];

  PadVoice(this.index, this.settings);

  bool get isLowLatency => !settings.long;
  bool get isActive => state == VoiceState.playing || state == VoiceState.fading;

  Duration get position {
    Duration pos = _offset + _clock.elapsed;
    final d = duration;
    if (d != null && d > Duration.zero) {
      if (settings.looped) {
        pos = Duration(microseconds: pos.inMicroseconds % d.inMicroseconds);
      } else if (pos > d) {
        pos = d;
      }
    }
    return pos;
  }

  /// 0..1, or null when the duration is unknown.
  double? get progress {
    final d = duration;
    if (d == null || d.inMilliseconds <= 0) return null;
    return (position.inMicroseconds / d.inMicroseconds).clamp(0.0, 1.0);
  }

  Duration? get remaining {
    final d = duration;
    if (d == null || d.inMilliseconds <= 0) return null;
    final r = d - position;
    return r.isNegative ? Duration.zero : r;
  }

  /// Test helper: freeze the voice at a given state and position.
  @visibleForTesting
  void debugSet(VoiceState s, Duration pos, Duration? total) {
    state = s;
    duration = total;
    _offset = pos;
    _clock
      ..stop()
      ..reset();
  }

  void _clockRestart([Duration from = Duration.zero]) {
    _offset = from;
    _clock
      ..reset()
      ..start();
  }

  void _clockFreeze() {
    _offset = position;
    _clock
      ..stop()
      ..reset();
  }

  void _clockReset() {
    _offset = Duration.zero;
    _clock
      ..stop()
      ..reset();
  }

  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }

  Future<void> dispose() async {
    _cancelFade();
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final p = player;
    player = null;
    if (p != null) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}

//==============================================================================

class SampleEngine extends ChangeNotifier {
  List<PadVoice?> _voices = [];
  int _generation = 0;

  /// Fade-out duration used when a pad is stopped (0 = cut immediately).
  int fadeMs = 1000;

  /// Set to true when a sample duration was discovered and should be saved.
  bool settingsDirty = false;

  PadVoice? voice(int i) => (i >= 0 && i < _voices.length) ? _voices[i] : null;

  bool get anyActive => _voices.any((v) => v != null && v.state != VoiceState.idle);

  bool get anyFading => _voices.any((v) => v != null && v.state == VoiceState.fading);

  //----------------------------------------------------------------------------

  Future<void> init(Settings settings) async {
    final int gen = ++_generation;

    final old = _voices;
    _voices = List<PadVoice?>.filled(settings.padSettings.length, null);
    notifyListeners();
    for (final v in old) {
      await v?.dispose();
    }

    for (int i = 0; i < settings.padSettings.length; i++) {
      if (gen != _generation) return; // a newer init started
      final v = await _createVoice(i, settings.padSettings[i]);
      if (gen != _generation) {
        await v?.dispose();
        return;
      }
      _voices[i] = v;
    }
    notifyListeners();
  }

  /// Rebuilds a single pad without interrupting the others.
  Future<void> reloadPad(int i, PadSettings pad) async {
    if (i < 0 || i >= _voices.length) return;
    final old = _voices[i];
    _voices[i] = null;
    await old?.dispose();
    _voices[i] = await _createVoice(i, pad);
    notifyListeners();
  }

  Future<PadVoice?> _createVoice(int i, PadSettings pad) async {
    if (!pad.hasSample) return null;

    final v = PadVoice(i, pad);

    if (!await File(pad.sample).exists()) {
      v.missing = true;
      return v;
    }

    try {
      final player = AudioPlayer(playerId: 'pad_$i');
      v.player = player;
      await player.setPlayerMode(pad.long ? PlayerMode.mediaPlayer : PlayerMode.lowLatency);
      await player.setReleaseMode(pad.looped ? ReleaseMode.loop : ReleaseMode.stop);
      await player.setVolume(pad.volume);
      await player.setSource(DeviceFileSource(pad.sample));

      // Duration: cached, or read from the player, or probed with a temporary player.
      if (pad.durationMs > 0) {
        v.duration = Duration(milliseconds: pad.durationMs);
      } else {
        Duration? d;
        if (pad.long) {
          d = await player.getDuration();
        } else {
          d = await _probeDuration(pad.sample);
        }
        if (d != null && d > Duration.zero) {
          v.duration = d;
          pad.durationMs = d.inMilliseconds;
          settingsDirty = true;
        }
      }

      if (pad.long) {
        v._subs.add(player.onPlayerComplete.listen((_) => _onComplete(v)));
        v._subs.add(player.onPositionChanged.listen((pos) {
          if (v.state == VoiceState.playing || v.state == VoiceState.fading) {
            if (DateTime.now().isAfter(v._ignorePositionUntil)) {
              v._clockRestart(pos);
            }
          }
        }));
      }
    } catch (e) {
      debugPrint('Pad $i: cannot load ${pad.sample}: $e');
      await v.dispose();
      v.missing = true;
    }

    return v;
  }

  Future<Duration?> _probeDuration(String path) async {
    final probe = AudioPlayer();
    try {
      await probe.setPlayerMode(PlayerMode.mediaPlayer);
      await probe.setReleaseMode(ReleaseMode.stop);
      await probe.setSource(DeviceFileSource(path));
      return await probe.getDuration();
    } catch (_) {
      return null;
    } finally {
      try {
        await probe.dispose();
      } catch (_) {}
    }
  }

  //----------------------------------------------------------------------------

  /// A pad was tapped.
  Future<void> press(int i) async {
    final v = voice(i);
    if (v == null || v.missing || v.player == null) return;

    switch (v.state) {
      case VoiceState.idle:
        await _start(v);
        break;

      case VoiceState.fading:
        // Tapped again while it was fading out: bring it back from the start.
        v._cancelFade();
        await v.player!.setVolume(v.settings.volume);
        await _restart(v);
        break;

      case VoiceState.paused:
        await _resume(v);
        break;

      case VoiceState.playing:
        switch (v.settings.behaviour) {
          case PressBehaviour.pause:
            await _pause(v);
            break;
          case PressBehaviour.stop:
            _fadeOut(v);
            break;
          case PressBehaviour.restart:
            await _restart(v);
            break;
        }
        break;
    }
    notifyListeners();
  }

  /// Stops every pad. Fades out first; a second call during the fade cuts at once.
  Future<void> stopAll() async {
    final bool immediate = fadeMs <= 0 || anyFading;
    for (final v in _voices) {
      if (v == null || v.state == VoiceState.idle) continue;
      if (immediate || v.state == VoiceState.paused) {
        await _hardStop(v);
      } else {
        _fadeOut(v);
      }
    }
    notifyListeners();
  }

  /// Called on every animation frame while something is playing.
  void tick() {
    bool changed = false;
    for (final v in _voices) {
      if (v == null || !v.isActive) continue;
      // Low latency players never report completion: detect it from the clock.
      if (v.isLowLatency && !v.settings.looped) {
        final d = v.duration;
        if (d == null) {
          // Unknown length: we cannot follow it, leave the sound alone.
          _onComplete(v);
          changed = true;
        } else if (v._offset + v._clock.elapsed >= d) {
          _onComplete(v);
          v.player?.stop();
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  //----------------------------------------------------------------------------

  Future<void> _stopGroupMates(PadVoice v) async {
    if (v.settings.group == 0) return;
    for (final o in _voices) {
      if (o == null || identical(o, v) || o.state == VoiceState.idle) continue;
      if (o.settings.group == v.settings.group) {
        if (o.state == VoiceState.paused) {
          await _hardStop(o);
        } else if (o.state == VoiceState.playing) {
          _fadeOut(o);
        }
      }
    }
  }

  Future<void> _start(PadVoice v) async {
    await _stopGroupMates(v);
    final p = v.player!;
    await p.setVolume(v.settings.volume);
    if (v.isLowLatency) {
      await p.stop();
    } else {
      await p.seek(Duration.zero);
    }
    v._ignorePositionUntil = DateTime.now().add(const Duration(milliseconds: 300));
    await p.resume();
    v.state = VoiceState.playing;
    v._clockRestart();
  }

  Future<void> _restart(PadVoice v) async {
    await _stopGroupMates(v);
    final p = v.player!;
    v._ignorePositionUntil = DateTime.now().add(const Duration(milliseconds: 300));
    if (v.isLowLatency) {
      await p.stop();
      await p.resume();
    } else {
      await p.seek(Duration.zero);
      if (p.state != PlayerState.playing) await p.resume();
    }
    v.state = VoiceState.playing;
    v._clockRestart();
  }

  Future<void> _pause(PadVoice v) async {
    await v.player!.pause();
    v._clockFreeze();
    v.state = VoiceState.paused;
  }

  Future<void> _resume(PadVoice v) async {
    await _stopGroupMates(v);
    v._ignorePositionUntil = DateTime.now().add(const Duration(milliseconds: 300));
    await v.player!.resume();
    v.state = VoiceState.playing;
    v._clockRestart(v._offset);
  }

  void _fadeOut(PadVoice v) {
    if (fadeMs <= 0) {
      _hardStop(v).then((_) => notifyListeners());
      return;
    }
    if (v.state == VoiceState.fading) return;

    v.state = VoiceState.fading;
    final double startVol = v.settings.volume;
    final int startedAt = DateTime.now().millisecondsSinceEpoch;
    final int total = fadeMs;

    v._cancelFade();
    v._fadeTimer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      final int elapsed = DateTime.now().millisecondsSinceEpoch - startedAt;
      final double k = 1.0 - (elapsed / total);
      if (k <= 0 || v.state != VoiceState.fading) {
        t.cancel();
        if (v.state == VoiceState.fading) {
          _hardStop(v).then((_) => notifyListeners());
        }
        return;
      }
      v.player?.setVolume(startVol * k * k); // smoother on the ear than linear
    });
  }

  Future<void> _hardStop(PadVoice v) async {
    v._cancelFade();
    v.state = VoiceState.idle;
    v._clockReset();
    final p = v.player;
    if (p != null) {
      try {
        await p.stop();
        await p.setVolume(v.settings.volume);
      } catch (_) {}
    }
  }

  void _onComplete(PadVoice v) {
    if (v.state == VoiceState.idle) return;
    v._cancelFade();
    v.state = VoiceState.idle;
    v._clockReset();
    v.player?.setVolume(v.settings.volume);
    notifyListeners();
  }

  //----------------------------------------------------------------------------

  @override
  void dispose() {
    _generation++;
    for (final v in _voices) {
      v?.dispose();
    }
    _voices = [];
    super.dispose();
  }
}

//==============================================================================
