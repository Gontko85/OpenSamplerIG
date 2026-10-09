import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/l10n.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/pad_screen.dart';
import 'package:opensampler/pad_settings_screen.dart';
import 'package:opensampler/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFonts() async {
  const dir = '/opt/sdk/flutter/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
    roboto.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$dir/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

Settings _demo() {
  final s = Settings.temp('Match NM1', 3, 4);
  final names = ['Entrée joueurs', 'Temps mort', 'Panier !', 'Ambiance', 'Hymne', 'Fin de match'];
  final colors = [0xFF039BE5, 0xFF43A047, 0xFFFDD835, 0xFF424242, 0xFFE53935, 0xFF8E24AA];
  for (int i = 0; i < names.length; i++) {
    s.padSettings[i]
      ..caption = names[i]
      ..color = Color(colors[i])
      ..textColor = i >= 3 ? Colors.white : Colors.black;
  }
  s.padSettings[0].group = 1;
  s.padSettings[1].group = 1;
  s.pageNames[0] = 'Match';
  s.addPage('Mi-temps');
  s.addPage('Animations');
  return s;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'language': 'fr'});
    preferences = await SharedPreferences.getInstance();
    documentDirectory = Directory.systemTemp.createTempSync('os_scr');
    loadLanguage();
  });

  for (final lang in ['fr', 'en']) {
    testWidgets('main screen $lang', (tester) async {
      setLanguage(lang);
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = const Size(1080, 2000);
      tester.view.devicePixelRatio = 2.75;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
        home: PadScreen(_demo()),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/main_$lang.png'));
    });
  }

  testWidgets('pad settings fr', (tester) async {
    setLanguage('fr');
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.75;
    final s = _demo();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      home: PadSettingsScreen(0, 0, 0, s),
    ));
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/pad_settings_fr.png'));
  });
}
