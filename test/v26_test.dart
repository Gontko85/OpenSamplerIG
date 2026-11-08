import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/copy_to_project.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/sample_engine.dart';
import 'package:opensampler/settings.dart';
import 'package:opensampler/trim_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Settings _reload(Settings s) => Settings.fromJson(File('x.json'), s.getJson());

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    documentDirectory = Directory.systemTemp.createTempSync('os_v26');
  });

  group('start / end point', () {
    test('JSON round trip, played length, copies, old projects', () {
      final s = Settings.temp('P', 2, 1);
      final pad = s.padSettings[0]
        ..sample = '/s/a.mp3'
        ..durationMs = 60000
        ..startMs = 12500
        ..endMs = 45000;
      expect(pad.isTrimmed, true);
      expect(pad.playedMs, 32500);
      final back = _reload(s).padSettings[0];
      expect((back.startMs, back.endMs), (12500, 45000));
      expect(PadSettings.copy(pad).startMs, 12500);
      expect(pad.duplicate().endMs, 45000);

      // Untrimmed pads write no keys (older versions read them as before).
      final json = jsonDecode(s.getJson()) as Map<String, dynamic>;
      final pads = (json['pages'] as List).first['padSettings'] as List;
      expect((pads[1] as Map).containsKey('start'), false);
      expect(_reload(Settings.temp('Q', 1, 1)).padSettings[0].startMs, 0);

      // Only a start point: plays to the file end.
      pad.endMs = 0;
      expect(pad.playedMs, 47500);
      expect(pad.isTrimmed, true);
    });

    test('an end before the start is ignored; playlists and blank pads are never trimmed', () {
      final m = {'sample': '/s/a.mp3', 'start': 5000, 'end': 3000};
      final pad = PadSettings.fromJson(m);
      expect(pad.startMs, 5000);
      expect(pad.endMs, 0);

      pad.extraTracks = ['/s/b.mp3'];
      expect(pad.isTrimmed, false);
      pad.clearSound();
      expect((pad.startMs, pad.endMs), (0, 0));
      expect(pad.isTrimmed, false);
    });

    test('formatTrimTime', () {
      expect(formatTrimTime(0), '0:00,0');
      expect(formatTrimTime(63500), '1:03,5');
      expect(formatTrimTime(599990), '10:00,0');
    });

    testWidgets('engine: stops at the end point, or loops back to the start point', (tester) async {
      final engine = SampleEngine();
      final pad = PadSettings(0)
        ..sample = '/s/a.mp3'
        ..durationMs = 60000
        ..startMs = 10000
        ..endMs = 20000;
      final v = PadVoice(0, pad)
        ..debugSet(VoiceState.playing, const Duration(seconds: 9), const Duration(seconds: 10));
      expect(v.usesMediaPlayer, true, reason: 'SoundPool cannot start in the middle of a file');
      expect(v.startAt, const Duration(seconds: 10));
      engine.debugSetVoices([v]);
      engine.tick();
      expect(v.state, VoiceState.playing);

      v.debugSet(VoiceState.playing, const Duration(seconds: 10), const Duration(seconds: 10));
      engine.tick();
      expect(v.state, VoiceState.idle);

      pad.looped = true;
      v.debugSet(VoiceState.playing, const Duration(milliseconds: 10200), const Duration(seconds: 10));
      engine.tick();
      expect(v.state, VoiceState.playing);
      expect(v.position < const Duration(seconds: 1), true, reason: 'back to the start point');
      engine.dispose();
    });
  });

  group('lower the music', () {
    testWidgets('lowers the sounds playing, not the idle ones, then brings them back', (tester) async {
      final engine = SampleEngine()..duckLevel = 0.3;
      final playing = PadVoice(0, PadSettings(0)..sample = '/s/a.mp3')
        ..debugSet(VoiceState.playing, Duration.zero, const Duration(seconds: 60));
      final idle = PadVoice(1, PadSettings(1)..sample = '/s/b.mp3');
      engine.debugSetVoices([playing, idle]);

      engine.setDucked(true);
      expect(engine.ducked, true);
      await tester.pump(const Duration(milliseconds: 400));
      expect(playing.duckGain, closeTo(0.3, 0.001));
      expect(idle.duckGain, 1.0);
      expect(playing.liveVolume, closeTo(0.3, 0.001));

      engine.setDucked(false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(playing.duckGain, 1.0);
      expect(engine.ducked, false);
      engine.dispose();
    });
  });

  group('copy a pad to another project', () {
    test('lists the other saved projects, copies with a new id, keeps the sound file', () async {
      final dir = documentDirectory;
      final a = Settings.temp('Match', 2, 2)..file = File('${dir.path}/Match.json');
      final b = Settings.temp('Gala', 2, 2)..file = File('${dir.path}/Gala.json');
      b.addPage('Entracte');
      await a.save();
      await b.save();
      await File('${dir.path}/temp.json').writeAsString(a.getJson());

      final others = await otherProjects(a.file);
      expect(others.map((f) => f.uri.pathSegments.last), ['Gala.json']);

      final pad = a.padSettings[1]
        ..caption = 'Hymne'
        ..sample = '/sons/hymne.mp3'
        ..startMs = 3000;
      final dest = Settings.fromJson(b.file, await b.file.readAsString());
      await copyPadInto(dest, 6, pad);

      final reread = Settings.fromJson(b.file, await b.file.readAsString());
      final copied = reread.padSettings[6];
      expect(reread.pageOf(6), 1);
      expect(copied.caption, 'Hymne');
      expect(copied.sample, '/sons/hymne.mp3');
      expect(copied.startMs, 3000);
      expect(copied.id, isNot(pad.id));
      expect(reread.pageCount, 2);
    });
  });

  test('compact display is automatic by default', () {
    expect(GlobalPrefs.compactMode, CompactMode.auto);
    GlobalPrefs.compactMode = CompactMode.on;
    expect(GlobalPrefs.compactMode, CompactMode.on);
    GlobalPrefs.compactMode = CompactMode.auto;
    expect(GlobalPrefs.duckLevel, 30);
    expect(GlobalPrefs.showDuck, true);
  });
}
