// Stress test: a big project must export / import without loading it in memory.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/project_archive.dart';
import 'package:opensampler/settings.dart';

int peakRssMb() {
  final line = File('/proc/self/status').readAsLinesSync().firstWhere((l) => l.startsWith('VmHWM'));
  return int.parse(RegExp(r'(\d+)').firstMatch(line)!.group(1)!) ~/ 1024;
}

void main() {
  test('300 MB project exports and imports with bounded memory (1.2 GB and 4.5 GB checked by hand)', () async {
    final root = Directory.systemTemp.createTempSync('os_big');
    documentDirectory = Directory('${root.path}/docs')..createSync();
    final src = Directory('${root.path}/src')..createSync();

    // 4 pages × 64 pads, 60 distinct 5 MB "songs" (random = incompressible).
    final rnd = Random(1);
    final chunk = Uint8List(5 * 1024 * 1024);
    for (int i = 0; i < chunk.length; i++) {
      chunk[i] = rnd.nextInt(256);
    }
    final s = Settings.temp('Gros projet', 8, 8);
    s.addPage('B');
    s.addPage('C');
    s.addPage('D');
    for (int i = 0; i < 60; i++) {
      chunk[0] = i; // make every file different
      final f = File('${src.path}/morceau_$i.mp3')..writeAsBytesSync(chunk);
      s.padSettings[i].sample = f.path;
      s.padSettings[i].caption = 'Morceau $i';
    }

    final before = peakRssMb();
    final zip = '${root.path}/export.zip';
    final n = await ProjectArchive.exportToFile(s, zip);
    final afterExport = peakRssMb();
    expect(n, 60);
    final zipSize = File(zip).lengthSync() ~/ (1024 * 1024);

    final (imported, count) = await ProjectArchive.importFromFile(zip);
    final afterImport = peakRssMb();
    expect(count, 60);
    expect(imported.pageCount, 4);
    expect(File(imported.padSettings[59].sample).lengthSync(), chunk.length);
    expect(File(imported.padSettings[59].sample).readAsBytesSync()[0], 59);

    // ignore: avoid_print
    print('zip: $zipSize MB · peak RSS before $before MB, after export $afterExport MB, after import $afterImport MB');
    expect(afterExport - before, lessThan(120), reason: 'export must not load the project in memory');
    expect(afterImport - before, lessThan(120), reason: 'import must not load the project in memory');
    root.deleteSync(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
