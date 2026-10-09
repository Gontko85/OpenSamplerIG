import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/project_archive.dart';
import 'package:opensampler/settings.dart';

void main() {
  test('export then import keeps pads and sounds', () async {
    documentDirectory = Directory.systemTemp.createTempSync('os_arch');
    final src = Directory.systemTemp.createTempSync('os_src');
    final a = File('${src.path}/intro.mp3')..writeAsBytesSync(List.generate(5000, (i) => i % 251));
    final b = File('${src.path}/buzzer.wav')..writeAsBytesSync(List.generate(300, (i) => i % 7));

    final s = Settings.temp('Match NM1', 2, 2);
    s.padSettings[0]
      ..sample = a.path
      ..caption = 'Intro'
      ..group = 1
      ..looped = true;
    s.padSettings[1]
      ..sample = b.path
      ..caption = 'Buzzer';
    s.padSettings[2]
      ..sample = a.path // same file used twice -> stored once
      ..caption = 'Intro bis';
    s.padSettings[3]
      ..sample = '${src.path}/missing.mp3' // missing file -> pad emptied, export still works
      ..caption = 'Perdu';

    final zip = await ProjectArchive.export(s);
    expect(ProjectArchive.fileNameFor(s), 'Match NM1.opensampler.zip');

    final (imported, count) = await ProjectArchive.import(zip);
    expect(count, 2);
    expect(imported.name, 'Match NM1');
    expect(imported.padSettings[0].caption, 'Intro');
    expect(imported.padSettings[0].group, 1);
    expect(imported.padSettings[0].looped, true);
    expect(File(imported.padSettings[0].sample).readAsBytesSync(), a.readAsBytesSync());
    expect(File(imported.padSettings[1].sample).readAsBytesSync(), b.readAsBytesSync());
    expect(imported.padSettings[2].sample, imported.padSettings[0].sample);
    expect(imported.padSettings[3].sample, '');
    expect(imported.file.existsSync(), true);

    // Importing again never overwrites: new project name.
    final (again, _) = await ProjectArchive.import(zip);
    expect(again.name, 'Match NM1 (2)');
  });

  test('rejects a random zip / random file', () async {
    documentDirectory = Directory.systemTemp.createTempSync('os_arch2');
    expect(() => ProjectArchive.import(Uint8ListHelper.junk()), throwsA(isA<FormatException>()));
  });
}

class Uint8ListHelper {
  static dynamic junk() => File('/etc/hostname').readAsBytesSync();
}
