import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/audio_repair.dart';

/// "Fake MP3" = MPEG program stream (.mpg container) holding MP3 audio.
/// Fixtures are synthetic sine waves made with ffmpeg (-f mpeg / -f vob).
void main() {
  final tmp = Directory.systemTemp.createTempSync('repair');
  final ffmpeg = Process.runSync('which', ['ffmpeg']).exitCode == 0;

  String pcmMd5(String path) {
    final r = Process.runSync('bash', ['-c', 'ffmpeg -v error -i "$path" -map 0:a -f s16le - | md5sum']);
    return (r.stdout as String).substring(0, 32);
  }

  for (final (name, md5) in [
    ('fake_mp3_mpeg1_ps.mp3', 'ea4f6fac5cd7554381894963abb632f0'),
    ('fake_mp3_mpeg2_ps.mp3', 'dbb0aea66df7e23dbefd16fd2e3a2d7a'),
  ]) {
    test('repairs $name losslessly', () async {
      final f = File('${tmp.path}/$name');
      File('test/fixtures/$name').copySync(f.path);
      expect(await AudioRepair.isMpegProgramStream(f.path), true);

      expect(await AudioRepair.repairIfNeeded(f.path), true);
      expect(await AudioRepair.isMpegProgramStream(f.path), false);
      final b = f.readAsBytesSync();
      expect(b[0], 0xFF, reason: 'plain MP3 now starts with a frame sync');
      expect(b[1] & 0xE0, 0xE0);
      if (ffmpeg) expect(pcmMd5(f.path), md5, reason: 'same audio, bit for bit');

      // Second call: nothing to do.
      expect(await AudioRepair.repairIfNeeded(f.path), false);
    });
  }

  test('leaves a real MP3 and a missing file alone', () async {
    final f = File('${tmp.path}/real.mp3');
    File('test/fixtures/real.mp3').copySync(f.path);
    final before = f.readAsBytesSync();
    expect(await AudioRepair.repairIfNeeded(f.path), false);
    expect(f.readAsBytesSync(), before);
    expect(await AudioRepair.repairIfNeeded('${tmp.path}/nope.mp3'), false);
  });
}
