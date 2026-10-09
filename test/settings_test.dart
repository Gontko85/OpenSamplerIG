import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/settings.dart';

void main() {
  setUpAll(() {
    documentDirectory = Directory.systemTemp.createTempSync('os_test');
  });

  test('reads a project saved by the original 2021 app', () {
    // Exact shape written by the original Open Sampler (no group / duration fields, volume 1.0).
    const old = '{"name":"Match","x":2,"y":1,"padSettings":['
        '{"sample":"/data/user/0/eu.cherrytree.opensampler/cache/file_picker/intro.mp3","caption":"Intro",'
        '"color":4288585374,"textColor":4278190080,"looped":false,"volume":1.0,"long":true,"behaviour":"Stop"},'
        '{"sample":"","caption":"2","color":4288585374,"textColor":4278190080,"looped":true,"volume":0.5,"long":false,"behaviour":"Pause"}]}';
    final s = Settings.fromJson(File('x.json'), old);
    expect(s.name, 'Match');
    expect(s.padSettings.length, 2);
    expect(s.padSettings[0].caption, 'Intro');
    expect(s.padSettings[0].long, true);
    expect(s.padSettings[0].behaviour, PressBehaviour.stop);
    expect(s.padSettings[0].group, 0);
    expect(s.padSettings[1].looped, true);
    expect(s.padSettings[1].volume, 0.5);
    expect(s.padSettings[1].behaviour, PressBehaviour.pause);
  });

  test('round-trips new fields', () {
    final s = Settings.temp('T', 2, 2);
    s.padSettings[3]
      ..group = 2
      ..durationMs = 12345
      ..caption = 'Hymne';
    final back = Settings.fromJson(File('y.json'), s.getJson());
    expect(back.padSettings[3].group, 2);
    expect(back.padSettings[3].durationMs, 12345);
    expect(back.padSettings[3].caption, 'Hymne');
  });

  test('grid resize keeps existing pads', () {
    final s = Settings.temp('T', 2, 2);
    s.padSettings[0].caption = 'Keep';
    s.x = 3;
    s.y = 3;
    s.validate();
    expect(s.padSettings.length, 9);
    expect(s.padSettings[0].caption, 'Keep');
    s.x = 1;
    s.y = 1;
    s.validate();
    expect(s.padSettings.length, 1);
  });
}
