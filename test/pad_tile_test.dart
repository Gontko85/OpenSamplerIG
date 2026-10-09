import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/pad_tile.dart';
import 'package:opensampler/sample_engine.dart';
import 'package:opensampler/settings.dart';

Future<void> _loadFonts() async {
  const dir = '/opt/sdk/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

void main() {
  testWidgets('pad states render', (tester) async {
    documentDirectory = Directory.systemTemp.createTempSync('os_test');
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 1300);
    tester.view.devicePixelRatio = 2.5;

    PadSettings pad(String c, Color col, {int group = 0, bool loop = false, Color text = Colors.black}) =>
        PadSettings(0)
          ..caption = c
          ..color = col
          ..textColor = text
          ..group = group
          ..looped = loop
          ..sample = '/x.mp3';

    final items = <(PadSettings, PadVoice?)>[];
    void add(PadSettings p, VoiceState s, int posS, int totS, {bool missing = false}) {
      final v = PadVoice(0, p)..missing = missing;
      v.debugSet(s, Duration(seconds: posS), Duration(seconds: totS));
      items.add((p, v));
    }

    add(pad('Entrée joueurs', const Color(0xFF039BE5), group: 1), VoiceState.playing, 42, 125);
    add(pad('Musique temps mort', const Color(0xFF43A047), group: 1), VoiceState.idle, 0, 90);
    add(pad('Panier !', const Color(0xFFFDD835)), VoiceState.playing, 1, 3);
    add(pad('Ambiance', const Color(0xFF424242), loop: true, text: Colors.white), VoiceState.playing, 20, 60);
    add(pad('Hymne', const Color(0xFFE53935), text: Colors.white), VoiceState.paused, 70, 100);
    add(pad('Fin de match', const Color(0xFF8E24AA), text: Colors.white), VoiceState.fading, 170, 180);
    add(pad('Fichier perdu', const Color(0xFF9E9E9E)), VoiceState.idle, 0, 10, missing: true);
    items.add((PadSettings(7), null));
    add(pad('Défense !', const Color(0xFFFB8C00), group: 2), VoiceState.idle, 0, 4);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color.fromARGB(255, 60, 60, 60),
        appBar: AppBar(title: const Text('Match NM1'), actions: const [
          Icon(Icons.lock_open), SizedBox(width: 16), Icon(Icons.volume_off_rounded), SizedBox(width: 16), Icon(Icons.more_vert), SizedBox(width: 8)
        ]),
        body: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: List.generate(3, (r) => Expanded(
                  child: Row(
                    children: List.generate(3, (c) {
                      final it = items[r * 3 + c];
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: PadTile(
                            settings: it.$1,
                            voice: it.$2,
                            fontSize: 18,
                            showRemaining: true,
                            stageLock: false,
                            onTrigger: () {},
                            onEdit: () {},
                          ),
                        ),
                      );
                    }),
                  ),
                )),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/pads.png'));
  });
}
