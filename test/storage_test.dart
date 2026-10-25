import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/pad_tile.dart';
import 'package:opensampler/sample_store.dart';
import 'package:opensampler/settings.dart';
import 'package:opensampler/storage_cleaner.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('os_store');
    documentDirectory = Directory('${root.path}/docs')..createSync();
    SampleStore.directory.createSync(recursive: true);
  });
  tearDown(() => root.deleteSync(recursive: true));

  File sound(String name, int size) =>
      File('${SampleStore.directory.path}/$name')..writeAsBytesSync(List.filled(size, 1));

  Settings project(String file, List<String> samples) {
    final s = Settings.temp(file, 2, 2)..file = File('${documentDirectory.path}/$file.json');
    for (int i = 0; i < samples.length; i++) {
      s.padSettings[i].sample = '${SampleStore.directory.path}/${samples[i]}';
    }
    return s;
  }

  test('finds sounds used by no project, deletes only those (and temp files)', () async {
    final a = sound('a.mp3', 1000), b = sound('b.mp3', 2000), c = sound('c.mp3', 3000), d = sound('d.mp3', 500);
    final part = sound('e.mp3.part', 700);
    await project('Match', ['a.mp3']).save();
    await project('temp', ['b.mp3']).save(); // the working project counts too
    final current = project('Courant', ['d.mp3']); // on screen, not saved yet
    final cache = Directory('${root.path}/cache/exports')..createSync(recursive: true);
    File('${cache.path}/old.zip').writeAsBytesSync(List.filled(4000, 0));

    final r = await StorageCleaner.analyze(current: current, cacheDir: Directory('${root.path}/cache'));
    expect(r.safe, true);
    expect(r.soundCount, 4);
    expect(r.soundBytes, 6500);
    expect(r.unused.map((f) => f.path), [c.path]);
    expect(r.unusedBytes, 3000);
    expect(r.temporaryBytes, 700 + 4000);

    final freed = await StorageCleaner.clean(r);
    expect(freed, 3000 + 700 + 4000);
    expect(c.existsSync(), false);
    expect(part.existsSync(), false);
    expect(cache.existsSync(), false);
    expect([a, b, d].every((f) => f.existsSync()), true);
  });

  test('an unreadable project blocks any deletion', () async {
    final c = sound('c.mp3', 3000);
    File('${documentDirectory.path}/casse.json').writeAsStringSync('{ pas du json');
    final r = await StorageCleaner.analyze();
    expect(r.safe, false);
    expect(r.unreadableProjects, ['casse.json']);
    expect(await StorageCleaner.clean(r), 0);
    expect(c.existsSync(), true);
  });

  test('size formatting', () {
    expect(StorageCleaner.formatBytes(1536 * 1024 * 1024), '1,5 Go');
    expect(StorageCleaner.formatBytes(350 * 1024 * 1024), '350 Mo');
    expect(StorageCleaner.formatBytes(1536 * 1024 * 1024, fr: false), '1.5 GB');
  });

  testWidgets('auto-fit text: shorter caption gets a bigger size, never overflows', (tester) async {
    const scaler = TextScaler.noScaling;
    const base = TextStyle();
    final big = AutoFitText.fitSize('Buzzer', 110, 70, scaler, base);
    final small = AutoFitText.fitSize('Musique d\'entrée des joueurs 2026', 110, 70, scaler, base);
    expect(big, greaterThan(small));
    expect(small, greaterThanOrEqualTo(AutoFitText.minSize));
    expect(big, lessThanOrEqualTo(AutoFitText.maxSize));
  });
}
