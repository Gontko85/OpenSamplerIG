//==============================================================================
//    settings.dart
//    Released under EUPL 1.2
//    Copyright Cherry Tree Studio 2021
//    Modifications Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'main.dart';

//==============================================================================

enum PressBehaviour { stop, pause, restart }

String pressBehaviourToString(PressBehaviour mode) {
  switch (mode) {
    case PressBehaviour.stop:
      return "Stop";
    case PressBehaviour.pause:
      return "Pause";
    case PressBehaviour.restart:
      return "Restart";
  }
}

PressBehaviour pressBehaviourFromString(String? string) {
  switch (string) {
    case "Stop":
      return PressBehaviour.stop;
    case "Pause":
      return PressBehaviour.pause;
    case "Restart":
      return PressBehaviour.restart;
  }
  return PressBehaviour.restart;
}

/// Exclusion groups: 0 = none, 1..4 = A..D.
const List<String> groupNames = ["None", "A", "B", "C", "D"];

//==============================================================================

class PadSettings {
  String sample = "";
  String caption = "";
  Color color = Colors.grey;
  Color textColor = Colors.black;
  bool looped = false;
  bool long = false;
  PressBehaviour behaviour = PressBehaviour.restart;
  double volume = 1.0;

  /// Exclusion group (0 = none). Starting a pad stops the other pads of its group.
  int group = 0;

  /// Cached sample duration in milliseconds (0 = unknown).
  int durationMs = 0;

  PadSettings(int index) {
    caption = "${index + 1}";
  }

  PadSettings.copy(PadSettings s)
      : sample = s.sample,
        caption = s.caption,
        color = s.color.withAlpha(255),
        textColor = s.textColor.withAlpha(255),
        looped = s.looped,
        long = s.long,
        behaviour = s.behaviour,
        volume = s.volume,
        group = s.group,
        durationMs = s.durationMs;

  PadSettings.fromJson(Map<String, dynamic> map) {
    sample = (map["sample"] as String?) ?? "";
    caption = (map["caption"] as String?) ?? "";
    final int? colorVal = map["color"] as int?;
    color = (colorVal != null ? Color(colorVal) : Colors.grey).withAlpha(255);
    final int? textColorVal = map["textColor"] as int?;
    textColor = (textColorVal != null ? Color(textColorVal) : Colors.black).withAlpha(255);
    long = (map["long"] as bool?) ?? false;
    looped = (map["looped"] as bool?) ?? false;
    volume = ((map["volume"] as num?) ?? 1.0).toDouble().clamp(0.0, 1.0);
    behaviour = pressBehaviourFromString(map["behaviour"] as String?);
    group = ((map["group"] as num?) ?? 0).toInt().clamp(0, groupNames.length - 1);
    durationMs = ((map["durationMs"] as num?) ?? 0).toInt();
  }

  Map<String, dynamic> toJson() => {
        "sample": sample,
        "caption": caption,
        "color": color.toARGB32(),
        "textColor": textColor.toARGB32(),
        "looped": looped,
        "volume": volume,
        "long": long,
        "behaviour": pressBehaviourToString(behaviour),
        "group": group,
        "durationMs": durationMs,
      };

  bool get hasSample => sample.isNotEmpty;
}

//==============================================================================

class Settings {
  String name;
  File file;
  int x;
  int y;
  List<PadSettings> padSettings;

  Settings.temp(this.name, this.x, this.y)
      : file = File('${documentDirectory.path}/temp.json'),
        padSettings = List.generate(x * y, (i) => PadSettings(i));

  Settings.copy(Settings s)
      : name = s.name,
        file = s.file,
        x = s.x,
        y = s.y,
        padSettings = s.padSettings.map((p) => PadSettings.copy(p)).toList();

  factory Settings.fromJson(File file, String json) {
    final Map<String, dynamic> map = jsonDecode(json) as Map<String, dynamic>;
    final int x = (map['x'] as num).toInt();
    final int y = (map['y'] as num).toInt();
    final s = Settings.temp((map['name'] as String?) ?? "Open Sampler", x, y);
    s.file = file;
    final List<dynamic> pads = (map['padSettings'] as List<dynamic>?) ?? [];
    for (int i = 0; i < x * y; i++) {
      if (i < pads.length && pads[i] is Map<String, dynamic>) {
        s.padSettings[i] = PadSettings.fromJson(pads[i] as Map<String, dynamic>);
      }
    }
    return s;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'x': x,
        'y': y,
        'padSettings': padSettings.map((p) => p.toJson()).toList(),
      };

  String getJson() => jsonEncode(toJson());

  Future<void> save() async {
    await file.writeAsString(getJson(), flush: true);
  }

  void validate() {
    final int n = x * y;
    if (n > padSettings.length) {
      for (int i = padSettings.length; i < n; i++) {
        padSettings.add(PadSettings(i));
      }
    } else if (n < padSettings.length) {
      padSettings.removeRange(n, padSettings.length);
    }
  }
}

Settings defaultSettings() => Settings.temp("Open Sampler", 3, 3);

//==============================================================================
// Global (app-wide) preferences.

class GlobalPrefs {
  static const String lastFileKey = "lastProject";
  static const String fontSizeKey = "fontSize";
  static const String fadeMsKey = "fadeOutMs";
  static const String showRemainingKey = "showRemaining";
  static const String keepScreenOnKey = "keepScreenOn";
  static const String stageLockKey = "stageLock";

  static String get fontSize => preferences.getString(fontSizeKey) ?? "Default";
  static set fontSize(String v) => preferences.setString(fontSizeKey, v);

  static int get fadeMs => preferences.getInt(fadeMsKey) ?? 1000;
  static set fadeMs(int v) => preferences.setInt(fadeMsKey, v);

  static bool get showRemaining => preferences.getBool(showRemainingKey) ?? true;
  static set showRemaining(bool v) => preferences.setBool(showRemainingKey, v);

  static bool get keepScreenOn => preferences.getBool(keepScreenOnKey) ?? true;
  static set keepScreenOn(bool v) => preferences.setBool(keepScreenOnKey, v);

  static bool get stageLock => preferences.getBool(stageLockKey) ?? false;
  static set stageLock(bool v) => preferences.setBool(stageLockKey, v);
}

//==============================================================================
