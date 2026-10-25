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

  /// Stable identity of the pad (kept when it moves; used by the match rundowns).
  String id = newPadId();

  /// Playlist: more tracks after [sample]. Each press plays the next one.
  List<String> extraTracks = [];

  /// Playlist order: false = in order, true = random (no repeat before all were played).
  bool shuffle = false;

  PadSettings(int index) {
    caption = "${index + 1}";
  }

  /// Exact copy, same identity (used when the whole project is copied).
  PadSettings.copy(PadSettings s)
    : id = s.id,
      extraTracks = List.of(s.extraTracks),
      shuffle = s.shuffle,
      sample = s.sample,
      caption = s.caption,
      color = s.color.withAlpha(255),
      textColor = s.textColor.withAlpha(255),
      looped = s.looped,
      long = s.long,
      behaviour = s.behaviour,
      volume = s.volume,
      group = s.group,
      durationMs = s.durationMs;

  /// Copy with a new identity (a second, independent pad).
  PadSettings duplicate() => PadSettings.copy(this)..id = newPadId();

  PadSettings.fromJson(Map<String, dynamic> map) {
    final String? savedId = map["id"] as String?;
    if (savedId != null && savedId.isNotEmpty) id = savedId;
    extraTracks = [
      for (final t in (map["tracks"] as List<dynamic>? ?? const []))
        if (t is String && t.isNotEmpty) t,
    ];
    shuffle = (map["shuffle"] as bool?) ?? false;
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
    "id": id,
    if (extraTracks.isNotEmpty) "tracks": extraTracks,
    if (shuffle) "shuffle": shuffle,
  };

  bool get hasSample => sample.isNotEmpty;

  /// Every sound file of the pad (one, or all the tracks of a playlist).
  List<String> get tracks => hasSample ? [sample, ...extraTracks] : const [];

  bool get isPlaylist => hasSample && extraTracks.isNotEmpty;

  /// Removes the sound(s): back to a blank pad.
  void clearSound() {
    sample = "";
    extraTracks = [];
    shuffle = false;
    durationMs = 0;
  }
}

int _idCounter = 0;

/// Short unique id, e.g. "lq3k9x-4f".
String newPadId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${(_idCounter++ & 0xFFF).toRadixString(36)}';

//==============================================================================

/// One step of a match rundown: a pad to play, and an optional note.
class RundownStep {
  String padId;
  String note;

  /// Pad name when the step was created / last seen (shown if the pad is gone).
  String caption;

  RundownStep(this.padId, {this.note = '', this.caption = ''});

  RundownStep.copy(RundownStep s) : padId = s.padId, note = s.note, caption = s.caption;

  factory RundownStep.fromJson(Map<String, dynamic> m) => RundownStep(
    (m['pad'] as String?) ?? '',
    note: (m['note'] as String?) ?? '',
    caption: (m['caption'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {'pad': padId, if (note.isNotEmpty) 'note': note, 'caption': caption};
}

/// A match rundown ("conducteur"): the sounds of a match, in order.
class Rundown {
  String name;
  List<RundownStep> steps;

  /// Index of the next step to play (steps.length = finished).
  int position;

  Rundown(this.name, {List<RundownStep>? steps, this.position = 0}) : steps = steps ?? [];

  Rundown.copy(Rundown r)
    : name = r.name,
      steps = r.steps.map(RundownStep.copy).toList(),
      position = r.position;

  factory Rundown.fromJson(Map<String, dynamic> m) {
    final r = Rundown(
      (m['name'] as String?) ?? '',
      steps: [
        for (final s in (m['steps'] as List<dynamic>? ?? const []))
          if (s is Map<String, dynamic>) RundownStep.fromJson(s),
      ],
    );
    r.position = ((m['position'] as num?) ?? 0).toInt().clamp(0, r.steps.length);
    return r;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'position': position,
    'steps': steps.map((s) => s.toJson()).toList(),
  };

  bool get finished => position >= steps.length;
}

/// A step of [rundown] resolved against the pads of [project].
extension RundownResolve on Settings {
  /// Global pad index of [step], or -1 when its pad was deleted / emptied.
  int padIndexOfStep(RundownStep step) {
    final int i = indexOfPadId(step.padId);
    return i >= 0 && padSettings[i].hasSample ? i : -1;
  }

  /// Current pad name (kept in [RundownStep.caption] for when the pad disappears).
  String stepCaption(RundownStep step) {
    final int i = indexOfPadId(step.padId);
    if (i >= 0) {
      final c = padSettings[i].caption.trim();
      if (c.isNotEmpty) step.caption = c;
    }
    return step.caption;
  }

  Rundown? get rundown => rundowns.isEmpty ? null : rundowns[currentRundown.clamp(0, rundowns.length - 1)];
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

  /// Match rundowns ("conducteurs") of the project.
  List<Rundown> rundowns = [];

  /// Rundown selected in the rundown panel.
  int currentRundown = 0;

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
      rundowns = s.rundowns.map(Rundown.copy).toList(),
      currentRundown = s.currentRundown,
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
    s.rundowns = [
      for (final r in (map['rundowns'] as List<dynamic>? ?? const []))
        if (r is Map<String, dynamic>) Rundown.fromJson(r),
    ];
    s.currentRundown = ((map['currentRundown'] as num?) ?? 0).toInt().clamp(
      0,
      s.rundowns.isEmpty ? 0 : s.rundowns.length - 1,
    );
    return s;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'x': x,
    'y': y,
    'currentPage': currentPage,
    if (rundowns.isNotEmpty) 'rundowns': rundowns.map((r) => r.toJson()).toList(),
    if (rundowns.isNotEmpty) 'currentRundown': currentRundown,
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
    final copy = padsOfPage(page).map((p) => p.duplicate()).toList();
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

  /// Index of the pad with this identity, or -1.
  int indexOfPadId(String id) => padSettings.indexWhere((p) => p.id == id);

  /// Indexes of the empty pads (no sound) from [page] to the last page, in order.
  List<int> emptySlotsFrom(int page) => [
    for (int i = page * padsPerPage; i < padSettings.length; i++)
      if (!padSettings[i].hasSample) i,
  ];

  /// Pads whose name (or sound file name) contains [query], in project order
  /// (page 1 first). Case and accents are ignored: "pile" finds "Pilé".
  List<int> searchPads(String query) {
    final q = foldText(query.trim());
    if (q.isEmpty) return const [];
    final List<int> found = [];
    for (int i = 0; i < padSettings.length; i++) {
      final pad = padSettings[i];
      if (!pad.hasSample && int.tryParse(pad.caption.trim()) != null) continue; // blank pad "12"
      final file = pad.tracks
          .map((t) => t.split(RegExp(r'[\\/]')).last.replaceFirst(RegExp(r'\.[^.]*$'), ''))
          .join(' ');
      if (foldText(pad.caption).contains(q) || foldText(file).contains(q)) found.add(i);
    }
    return found;
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

/// Lower case, without accents, for forgiving text search.
String foldText(String s) {
  const groups = {
    'a': 'àáâãäåā',
    'c': 'çćč',
    'e': 'èéêëēėę',
    'i': 'ìíîïīį',
    'n': 'ñń',
    'o': 'òóôõöøō',
    'u': 'ùúûüū',
    'y': 'ÿý',
    'z': 'žźż',
    'oe': 'œ',
    'ae': 'æ',
    'ss': 'ß',
  };
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    String out = ch;
    for (final e in groups.entries) {
      if (e.value.contains(ch)) {
        out = e.key;
        break;
      }
    }
    b.write(out);
  }
  return b.toString();
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
  static const String showNowPlayingKey = "showNowPlaying";
  static const String showRecentKey = "showRecent";
  static const String showRundownKey = "showRundown";

  /// Rundown panel shown above the grid.
  static bool get showRundown => preferences.getBool(showRundownKey) ?? false;
  static set showRundown(bool v) => preferences.setBool(showRundownKey, v);

  static bool get showNowPlaying => preferences.getBool(showNowPlayingKey) ?? true;
  static set showNowPlaying(bool v) => preferences.setBool(showNowPlayingKey, v);

  static bool get showRecent => preferences.getBool(showRecentKey) ?? true;
  static set showRecent(bool v) => preferences.setBool(showRecentKey, v);

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
