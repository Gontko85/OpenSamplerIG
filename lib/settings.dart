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

/// A project: one grid size (x × y) shared by one or more pages of pads.
///
/// All pads of all pages live in one flat list, page after page, so that a
/// pad keeps the same audio player when the user switches page: music started
/// on page 1 keeps playing (and keeps its progress) while page 2 is shown.
class Settings {
  String name;
  File file;
  int x;
  int y;

  /// Pads of every page, page after page ([padsPerPage] pads each).
  List<PadSettings> padSettings;

  /// Page names (at least one page).
  List<String> pageNames;

  /// Page shown when the project was last saved.
  int currentPage = 0;

  /// Grid size the flat list is currently laid out with (see [validate]).
  int _layoutN;

  Settings.temp(this.name, this.x, this.y)
    : file = File('${documentDirectory.path}/temp.json'),
      padSettings = List.generate(x * y, (i) => PadSettings(i)),
      pageNames = [''],
      _layoutN = x * y;

  Settings.copy(Settings s)
    : name = s.name,
      file = s.file,
      x = s.x,
      y = s.y,
      padSettings = s.padSettings.map((p) => PadSettings.copy(p)).toList(),
      pageNames = List.of(s.pageNames),
      currentPage = s.currentPage,
      _layoutN = s._layoutN;

  factory Settings.fromJson(File file, String json) {
    final Map<String, dynamic> map = jsonDecode(json) as Map<String, dynamic>;
    final int x = (map['x'] as num).toInt();
    final int y = (map['y'] as num).toInt();
    final int n = x * y;
    final s = Settings.temp((map['name'] as String?) ?? "Open Sampler", x, y);
    s.file = file;

    List<PadSettings> readPads(List<dynamic>? pads) => List.generate(n, (i) {
      if (pads != null && i < pads.length && pads[i] is Map<String, dynamic>) {
        return PadSettings.fromJson(pads[i] as Map<String, dynamic>);
      }
      return PadSettings(i);
    });

    final List<dynamic>? pages = map['pages'] as List<dynamic>?;
    if (pages != null && pages.isNotEmpty) {
      s.padSettings = [];
      s.pageNames = [];
      for (final page in pages) {
        final m = (page as Map<String, dynamic>?) ?? const {};
        s.pageNames.add((m['name'] as String?) ?? '');
        s.padSettings.addAll(readPads(m['padSettings'] as List<dynamic>?));
      }
    } else {
      // Single-page project (original 2021 format and v2.0 / v2.1).
      s.padSettings = readPads(map['padSettings'] as List<dynamic>?);
    }
    s.currentPage = ((map['currentPage'] as num?) ?? 0).toInt().clamp(0, s.pageCount - 1);
    return s;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'x': x,
    'y': y,
    'currentPage': currentPage,
    'pages': List.generate(
      pageCount,
      (p) => {'name': pageNames[p], 'padSettings': padsOfPage(p).map((pad) => pad.toJson()).toList()},
    ),
    // First page also written the old way, so an older version of the app
    // can still open the project (it will only see page 1).
    'padSettings': padsOfPage(0).map((pad) => pad.toJson()).toList(),
  };

  String getJson() => jsonEncode(toJson());

  Future<void> save() async {
    await file.writeAsString(getJson(), flush: true);
  }

  //----------------------------------------------------------------------------
  // Pages

  int get padsPerPage => x * y;
  int get pageCount => pageNames.length;

  int pageOf(int globalIndex) => globalIndex ~/ padsPerPage;
  int indexInPage(int globalIndex) => globalIndex % padsPerPage;
  int globalIndex(int page, int i) => page * padsPerPage + i;

  List<PadSettings> padsOfPage(int page) => padSettings.sublist(page * padsPerPage, (page + 1) * padsPerPage);

  /// Adds an empty page at the end and returns its index.
  int addPage([String name = '']) {
    pageNames.add(name);
    padSettings.addAll(List.generate(padsPerPage, (i) => PadSettings(i)));
    return pageCount - 1;
  }

  /// Adds a copy of [page] right after it and returns the new page index.
  int duplicatePage(int page, String name) {
    final copy = padsOfPage(page).map((p) => PadSettings.copy(p)).toList();
    pageNames.insert(page + 1, name);
    padSettings.insertAll((page + 1) * padsPerPage, copy);
    return page + 1;
  }

  void removePage(int page) {
    if (pageCount <= 1) return;
    pageNames.removeAt(page);
    padSettings.removeRange(page * padsPerPage, (page + 1) * padsPerPage);
    if (currentPage >= pageCount) currentPage = pageCount - 1;
  }

  /// Moves [page] by [delta] (-1 = left, +1 = right).
  void movePage(int page, int delta) {
    final int target = page + delta;
    if (target < 0 || target >= pageCount) return;
    final name = pageNames.removeAt(page);
    pageNames.insert(target, name);
    final pads = padsOfPage(page);
    padSettings.removeRange(page * padsPerPage, (page + 1) * padsPerPage);
    padSettings.insertAll(target * padsPerPage, pads);
  }

  /// Display name of a page ("Page 2" when not named).
  String pageLabel(int page, String Function(int) fallback) =>
      pageNames[page].trim().isEmpty ? fallback(page + 1) : pageNames[page];

  //----------------------------------------------------------------------------

  /// Re-lays out every page after the grid size (x, y) changed: each page
  /// keeps its first pads, and gets blank pads if the grid grew.
  void validate() {
    final int newN = x * y;
    final int oldN = _layoutN;
    if (newN == oldN && padSettings.length == newN * pageCount) return;

    final List<PadSettings> out = [];
    for (int p = 0; p < pageCount; p++) {
      for (int i = 0; i < newN; i++) {
        final int src = p * oldN + i;
        out.add(i < oldN && src < padSettings.length ? padSettings[src] : PadSettings(i));
      }
    }
    padSettings = out;
    _layoutN = newN;
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
