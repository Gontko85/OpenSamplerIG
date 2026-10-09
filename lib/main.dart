//==============================================================================
//    main.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'pad_screen.dart';
import 'settings.dart';

//==============================================================================

late SharedPreferences preferences;
late Directory documentDirectory;
late PackageInfo packageInfo;

//==============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  preferences = await SharedPreferences.getInstance();
  documentDirectory = await getApplicationDocumentsDirectory();
  packageInfo = await PackageInfo.fromPlatform();
  loadLanguage();

  // Let all pads mix together: without this, every new sound would request
  // exclusive audio focus and Android would pause the pads already playing.
  await AudioPlayer.global.setAudioContext(
    AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {AVAudioSessionOptions.mixWithOthers},
      ),
    ),
  );

  final settings = await loadSettings();

  runApp(
    MaterialApp(
      title: 'Open Sampler IG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      darkTheme: ThemeData(brightness: Brightness.dark, colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      home: PadScreen(settings),
    ),
  );
}

//==============================================================================

Future<Settings> loadSettings() async {
  String? last = preferences.getString(GlobalPrefs.lastFileKey);

  if (last == null || last.isEmpty) {
    last = '${documentDirectory.path}/temp.json';
  }

  final settingsFile = File(last);

  if (await settingsFile.exists()) {
    try {
      final json = await settingsFile.readAsString();
      return Settings.fromJson(settingsFile, json);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  return defaultSettings();
}

//==============================================================================
