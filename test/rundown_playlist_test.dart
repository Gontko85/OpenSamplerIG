import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/project_archive.dart';
import 'package:opensampler/sample_store.dart';
import 'package:opensampler/settings.dart';
import 'package:opensampler/storage_cleaner.dart';

Settings _reload(Settings s) => Settings.fromJson(File('x.json'), s.getJson());

void main() {
  setUpAll(() => documentDirectory = Directory.systemTemp.createTempSync('os_rd'));

  group('pad ids', () {
    test('every pad gets its own id, kept by copy and JSON, new on duplicate', () {
      final s = Settings.temp('P', 2, 2);
      final ids = s.padSettings.map((p) => p.id).toSet();
      expect(ids.length, 4);
      final pad = s.padSettings[0];
      expect(PadSettings.copy(pad).id, pad.id);
      expect(pad.duplicate().id, isNot(pad.id));
      expect(_reload(s).padSettings.map((p) => p.id).toList(), s.padSettings.map((p) => p.id).toList());
      expect(Settings.copy(s).padSettings[3].id, s.padSettings[3].id);
    });

    test('duplicated page gets new ids', () {
      final s = Settings.temp('P', 2, 1);
      s.duplicatePage(0, 'B');
      expect(s.padSettings[2].id, isNot(s.padSettings[0].id));
    });
  });

  group('playlist', () {
    test('tracks, shuffle and JSON round trip', () {
      final s = Settings.temp('P', 2, 1);
      final pad = s.padSettings[0]
        ..sample = '/s/a.mp3'
        ..extraTracks = ['/s/b.mp3', '/s/c.mp3']
        ..shuffle = true;
      expect(pad.isPlaylist, true);
      expect(pad.tracks, ['/s/a.mp3', '/s/b.mp3', '/s/c.mp3']);
      expect(s.padSettings[1].isPlaylist, false);
      expect(s.padSettings[1].tracks, isEmpty);

      final back = _reload(s).padSettings[0];
      expect(back.tracks, pad.tracks);
      expect(back.shuffle, true);
      // A single-track pad writes no playlist keys (older versions read it as before).
      final json = jsonDecode(s.getJson()) as Map<String, dynamic>;
      final pads = (json['pages'] as List).first['padSettings'] as List;
      expect((pads[1] as Map).containsKey('tracks'), false);

      pad.clearSound();
      expect(pad.hasSample, false);
      expect(pad.extraTracks, isEmpty);
      expect(pad.shuffle, false);
    });

    test('search finds a pad by the name of any track', () {
      final s = Settings.temp('P', 2, 1);
      s.padSettings[1]
        ..caption = 'Musiques'
        ..sample = '/s/Intro.mp3'
        ..extraTracks = ['/s/Seven Nation Army.mp3'];
      expect(s.searchPads('seven'), [1]);
    });

    test('export / import keeps every track; cleaner counts them as used', () async {
      documentDirectory = Directory.systemTemp.createTempSync('os_pl');
      SampleStore.directory.createSync(recursive: true);
      final src = Directory.systemTemp.createTempSync('os_pl_src');
      final files = [
        for (final n in ['un', 'deux', 'trois'])
          File('${src.path}/$n.wav')..writeAsBytesSync(List.generate(400, (i) => (i * n.length) % 251)),
      ];
      final s = Settings.temp('Playlist', 2, 1);
      s.padSettings[0]
        ..caption = 'Ambiance'
        ..sample = files[0].path
        ..extraTracks = [files[1].path, files[2].path]
        ..shuffle = true;
      s.rundowns = [
        Rundown('Match', steps: [RundownStep(s.padSettings[0].id, note: 'avant match')]),
      ];
      final zip = '${src.path}/p.zip';
      await ProjectArchive.exportToFile(s, zip);
      final (imported, count) = await ProjectArchive.importFromFile(zip);
      expect(count, 3);
      final pad = imported.padSettings[0];
      expect(pad.tracks.length, 3);
      expect(pad.tracks.map((t) => File(t).existsSync()), everyElement(true));
      expect(pad.shuffle, true);
      // The rundown still points to the same pad.
      expect(imported.padIndexOfStep(imported.rundowns.single.steps.single), 0);

      // A stored file no project uses vs. the playlist tracks.
      File('${SampleStore.directory.path}/orphan.wav').writeAsBytesSync([1, 2, 3]);
      final report = await StorageCleaner.analyze(current: imported);
      expect(report.unused.map((f) => f.uri.pathSegments.last), ['orphan.wav']);
    });
  });

  group('rundown', () {
    Settings project() {
      final s = Settings.temp('Match', 2, 2);
      for (int i = 0; i < 4; i++) {
        s.padSettings[i]
          ..caption = 'Son $i'
          ..sample = '/s/$i.mp3';
      }
      s.addPage('Mi-temps');
      return s;
    }

    test('JSON round trip and position clamp', () {
      final s = project();
      s.rundowns = [
        Rundown(
          'Match',
          steps: [
            RundownStep(s.padSettings[2].id, note: 'au coup de sifflet', caption: 'Son 2'),
            RundownStep(s.padSettings[0].id, caption: 'Son 0'),
          ],
          position: 1,
        ),
        Rundown('Cheers'),
      ];
      s.currentRundown = 1;
      final back = _reload(s);
      expect(back.rundowns.length, 2);
      expect(back.rundowns[0].steps[0].note, 'au coup de sifflet');
      expect(back.rundowns[0].position, 1);
      expect(back.currentRundown, 1);
      expect(back.rundown!.name, 'Cheers');
      expect(back.padIndexOfStep(back.rundowns[0].steps[0]), 2);

      final m = jsonDecode(s.getJson()) as Map<String, dynamic>;
      (m['rundowns'] as List)[0]['position'] = 99;
      final clamped = Settings.fromJson(File('x.json'), jsonEncode(m));
      expect(clamped.rundowns[0].position, 2);
      expect(clamped.rundowns[0].finished, true);
    });

    test('old projects without rundowns still load', () {
      final s = project();
      final m = jsonDecode(s.getJson()) as Map<String, dynamic>..remove('rundowns');
      final back = Settings.fromJson(File('x.json'), jsonEncode(m));
      expect(back.rundowns, isEmpty);
      expect(back.rundown, isNull);
    });

    test('a step follows its pad when pads and pages move', () {
      final s = project();
      final step = RundownStep(s.padSettings[1].id);
      s.rundowns = [
        Rundown('M', steps: [step]),
      ];
      expect(s.padIndexOfStep(step), 1);

      // Swap pads 1 and 3.
      final a = s.padSettings[1];
      s.padSettings[1] = s.padSettings[3];
      s.padSettings[3] = a;
      expect(s.padIndexOfStep(step), 3);

      // Move the first page after the second one.
      s.movePage(0, 1);
      expect(s.padIndexOfStep(step), 4 + 3);
      expect(s.stepCaption(step), 'Son 1');

      // Pad emptied: step is "missing" but remembers the name.
      s.padSettings[7].clearSound();
      s.padSettings[7].caption = '';
      expect(s.padIndexOfStep(step), -1);
      expect(s.stepCaption(step), 'Son 1');

      // Page removed: still missing, no crash.
      s.removePage(1);
      expect(s.padIndexOfStep(step), -1);
    });

    test('copying a project copies its rundowns', () {
      final s = project();
      s.rundowns = [
        Rundown('M', steps: [RundownStep(s.padSettings[0].id)]),
      ];
      final c = Settings.copy(s);
      c.rundowns[0].steps.clear();
      expect(s.rundowns[0].steps.length, 1);
    });
  });
}
