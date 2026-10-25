import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opensampler/l10n.dart';
import 'package:opensampler/main.dart';
import 'package:opensampler/pad_screen.dart';
import 'package:opensampler/pad_settings_screen.dart';
import 'package:opensampler/pad_tile.dart';
import 'package:opensampler/rundown_screen.dart';
import 'package:opensampler/sample_engine.dart';
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
  _rundownEditorTest();
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
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
          home: PadScreen(_demo()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/main_$lang.png'));
    });
  }

  // Phone (393 × 760 dp, i.e. a small phone without the status bar) and tablet.
  for (final (name, size, ratio) in [
    ('phone', const Size(1080, 2090), 2.75),
    ('tablet', const Size(1600, 2560), 2.0),
  ]) {
    testWidgets('pad settings fr $name fits without scrolling', (tester) async {
      setLanguage('fr');
      await tester.runAsync(_loadFonts);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      final s = _demo();
      s.padSettings[0]
        ..sample = '/sons/Entree_des_joueurs_2026.mp3'
        ..long = true
        ..group = 1
        ..volume = 0.8;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
          home: PadSettingsScreen(
            0,
            0,
            0,
            s,
            problem: S.padProblemRefused('MEDIA_ERROR_UNKNOWN {what:1} — MEDIA_ERROR_UNSUPPORTED'),
          ),
        ),
      );
      await tester.pump();
      // No scrolling needed: the scroll view has nothing to scroll.
      final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(pos.maxScrollExtent, 0, reason: 'the pad settings must fit on one screen');
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/pad_settings_fr_$name.png'));
    });
  }

  testWidgets('search jumps to the page of the first match and frames it', (tester) async {
    setLanguage('fr');
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.75;
    final s = _demo(); // pages: Match, Mi-temps, Animations
    s.padsOfPage(2)[4]
      ..caption = 'Hymne LSVB'
      ..color = const Color(0xFF3949AB)
      ..textColor = Colors.white;
    s.padsOfPage(2)[7]
      ..caption = 'Hymne (court)'
      ..color = const Color(0xFF3949AB)
      ..textColor = Colors.white;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
        home: PadScreen(s),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'hymne');
    await tester.pump();

    PadTile cur() => tester.widgetList<PadTile>(find.byType(PadTile)).singleWhere((t) => t.highlight == 2);

    // 3 results: "Hymne" on page Match, then the two on page Animations.
    expect(find.text('1/3'), findsOneWidget);
    expect(cur().settings.caption, 'Hymne');
    expect(find.text('Entrée joueurs'), findsOneWidget, reason: 'page Match shown');

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    expect(cur().settings.caption, 'Hymne LSVB');
    expect(find.text('Entrée joueurs'), findsNothing, reason: 'jumped to page Animations');
    expect(find.text('2/3'), findsOneWidget);

    // Direct hit on another page.
    await tester.enterText(find.byType(TextField), 'lsvb');
    await tester.pump();
    expect(find.text('1/1'), findsOneWidget);
    expect(cur().settings.caption, 'Hymne LSVB');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/search_fr.png'));
  });

  testWidgets('now playing strip and recent sounds', (tester) async {
    setLanguage('fr');
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.75;
    final s = _demo(); // pages Match, Mi-temps, Animations; captions on page Match
    s.padsOfPage(2)[0]
      ..caption = 'Chorégraphie Cheers 1'
      ..color = const Color(0xFFD81B60)
      ..textColor = Colors.white;
    final engine = SampleEngine();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
        home: PadScreen(s, engine: engine),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // The screen works on its own copy of the project: use its pads.
    final pads = tester.widgetList<PadTile>(find.byType(PadTile)).map((t) => t.settings).toList();
    final shown = pads.first; // "Entrée joueurs"
    final voices = List<PadVoice?>.filled(3 * 12, null);
    PadVoice v(PadSettings p, VoiceState st, int pos, int tot, int ago) => PadVoice(0, p)
      ..debugSet(st, Duration(seconds: pos), Duration(seconds: tot))
      ..startedAt = DateTime.now().subtract(Duration(seconds: ago));
    voices[0] = v(shown, VoiceState.playing, 47, 128, 50);
    voices[4] = v(pads[4], VoiceState.paused, 64, 100, 80);
    // A pad of page Animations (index 24), not on screen.
    final state = tester.state(find.byType(PadScreen));
    final copy = (state as dynamic).debugSettings as Settings;
    voices[24] = v(copy.padSettings[24], VoiceState.playing, 12, 95, 5);
    for (int i = 0; i < 6; i++) {
      copy.padSettings[i].sample = '/sons/$i.mp3'; // real pads: captions auto-fit
    }
    engine.debugSetVoices(voices, recentPads: [copy.padSettings[24], pads[2], shown, pads[1]]);
    await tester.pump();

    expect(find.text('Chorégraphie Cheers 1'), findsNWidgets(2), reason: 'in "now playing" and in recents');
    expect(find.text('-1:23'), findsWidgets);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/now_playing_fr.png'));

    // Tapping it in the strip shows its page.
    await tester.tap(find.text('Chorégraphie Cheers 1').first);
    await tester.pump();
    expect(tester.widgetList<PadTile>(find.byType(PadTile)).any((t) => t.highlight == 2), true);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('match rundown panel plays the next step and moves on; playlist pad', (tester) async {
    setLanguage('fr');
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.75;
    preferences.setBool(GlobalPrefs.showRundownKey, true);
    final engine = _RecordingEngine();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
        home: PadScreen(_demo(), engine: engine),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(S.rundownNoneYet), findsOneWidget);

    final state = tester.state(find.byType(PadScreen));
    final copy = (state as dynamic).debugSettings as Settings;
    for (int i = 0; i < 6; i++) {
      copy.padSettings[i].sample = '/sons/$i.mp3';
    }
    copy.padSettings[3]
      ..extraTracks = ['/sons/b.mp3', '/sons/c.mp3']
      ..shuffle = true;
    final pads = copy.padSettings;
    copy.rundowns = [
      Rundown(
        'Match du samedi',
        steps: [
          RundownStep(pads[4].id, caption: 'Hymne'),
          RundownStep(pads[0].id, note: 'au coup de sifflet', caption: 'Entrée joueurs'),
          RundownStep(pads[1].id),
          RundownStep(pads[5].id),
        ],
        position: 1,
      ),
      Rundown('Mi-temps Cheers'),
    ];
    (state as dynamic).setState(() {});
    await tester.pump();
    expect(find.text('Entrée joueurs'), findsWidgets);
    expect(find.text('au coup de sifflet'), findsOneWidget);
    expect(find.text('2/4'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/rundown_fr.png'));

    // ▶ plays pad 0 and shows the next step.
    await tester.tap(find.text('au coup de sifflet'));
    await tester.pump();
    expect(engine.pressed, [0]);
    expect(copy.rundowns[0].position, 2);
    expect(find.text('3/4'), findsOneWidget);
    // A finger bounce right after does not skip a step.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(engine.pressed, [0]);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(engine.pressed, [0, 1]);

    // ◀ goes back without playing; ⏭ skips.
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.pump();
    expect(copy.rundowns[0].position, 2);
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump();
    expect(copy.rundowns[0].finished, true);
    expect(find.textContaining(S.rundownFinished), findsOneWidget);
    expect(engine.pressed, [0, 1]);

    // The step follows its pad when it is moved to another page.
    copy.movePage(0, 1);
    await tester.tap(find.textContaining(S.rundownRestart));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(engine.pressed.last, 12 + 4);
    await tester.pump(const Duration(seconds: 1));
  });
}

void _rundownEditorTest() {
  testWidgets('rundown editor lists steps with page, note and deleted pad', (tester) async {
    setLanguage('fr');
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.75;
    final s = _demo();
    for (int i = 0; i < 6; i++) {
      s.padSettings[i].sample = '/sons/$i.mp3';
    }
    s.padsOfPage(1)[0]
      ..caption = 'Chorégraphie Cheers 1'
      ..sample = '/sons/c.mp3'
      ..color = const Color(0xFFD81B60);
    final r = Rundown(
      'Match du samedi',
      steps: [
        RundownStep(s.padSettings[4].id),
        RundownStep(s.padSettings[0].id, note: 'au coup de sifflet'),
        RundownStep(s.padSettings[1].id, note: '1er temps mort'),
        RundownStep(s.padsOfPage(1)[0].id, note: 'mi-temps'),
        RundownStep('disparu', caption: 'Ancien jingle'),
      ],
    );
    s.rundowns = [r];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Roboto', colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
        home: RundownEditScreen(s, r),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('page Mi-temps · mi-temps'), findsOneWidget);
    expect(find.textContaining(S.rundownMissingPad), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/rundown_editor_fr.png'));
  });
}

class _RecordingEngine extends SampleEngine {
  final List<int> pressed = [];

  @override
  Future<void> press(int i) async => pressed.add(i);
}
