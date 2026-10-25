//==============================================================================
//    project_archive.dart — export / import a project with its sounds
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'main.dart';
import 'sample_store.dart';
import 'settings.dart';

//==============================================================================

/// Archive layout (a plain .zip, readable on a computer too):
/// ```
///   opensampler-project.json   the project, sample paths rewritten to "samples/<file>"
///   samples/<file>             every sound used by the project
/// ```
class ProjectArchive {
  static const String projectEntry = 'opensampler-project.json';
  static const String samplesDir = 'samples/';
  static const int formatVersion = 1;

  //----------------------------------------------------------------------------

  /// Writes the export of [settings] to the file [zipPath].
  ///
  /// Everything is streamed: each sound is copied from disk into the zip in
  /// small chunks, so memory use does not depend on the size of the project
  /// (a project of several GB exports fine). Missing sound files are skipped.
  /// [onProgress] receives (sounds done, sounds total).
  static Future<int> exportToFile(
    Settings settings,
    String zipPath, {
    void Function(int done, int total)? onProgress,
  }) async {
    final copy = Settings.copy(settings);
    final Map<String, String> entryForPath = {};
    final Set<String> usedNames = {};

    // 1. Decide the entry name of every sound (and drop missing files),
    //    including all the tracks of playlist pads.
    Future<String?> entryFor(String path) async {
      final known = entryForPath[path];
      if (known != null) return known;
      if (!await File(path).exists()) return null;
      // Unique entry name, even if two different files share a name.
      String name = p.basename(path);
      int n = 2;
      while (usedNames.contains(name)) {
        name = '${p.basenameWithoutExtension(path)}_$n${p.extension(path)}';
        n++;
      }
      usedNames.add(name);
      return entryForPath[path] = '$samplesDir$name';
    }

    for (final pad in copy.padSettings) {
      if (!pad.hasSample) continue;
      final List<String> tracks = [];
      for (final t in pad.tracks) {
        final e = await entryFor(t);
        if (e != null) tracks.add(e);
      }
      if (tracks.isEmpty) {
        pad.clearSound();
        continue;
      }
      pad.sample = tracks.first;
      pad.extraTracks = tracks.sublist(1);
    }

    // 2. Stream everything into the zip file, one sound at a time.
    final out = File(zipPath);
    await out.parent.create(recursive: true);
    if (await out.exists()) await out.delete();
    final output = OutputFileStream(zipPath);
    final encoder = ZipEncoder();
    try {
      encoder.startEncode(output, level: 0);

      final Map<String, dynamic> json = copy.toJson()
        ..['format'] = 'opensampler-ig'
        ..['formatVersion'] = formatVersion;
      encoder.add(ArchiveFile.string(projectEntry, const JsonEncoder.withIndent('  ').convert(json)));

      int done = 0;
      final int total = entryForPath.length;
      onProgress?.call(0, total);
      for (final e in entryForPath.entries) {
        final input = InputFileStream(e.key);
        // Audio is already compressed: store it as is (fast, no extra memory).
        final file = ArchiveFile.stream(e.value, input)..compression = CompressionType.none;
        encoder.add(file, autoClose: true);
        done++;
        onProgress?.call(done, total);
        // Let the UI breathe (progress dialog) between two sounds.
        await Future<void>.delayed(Duration.zero);
      }
      encoder.endEncode();
    } finally {
      await output.close();
    }
    return entryForPath.length;
  }

  /// Suggested file name for the export.
  static String fileNameFor(Settings s) {
    final safe = s.name.trim().isEmpty ? 'projet' : s.name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$safe.opensampler.zip';
  }

  //----------------------------------------------------------------------------

  /// Imports an exported project from the zip file at [zipPath]. Sounds are
  /// extracted one by one straight to disk (no big memory use) into the app's
  /// sample store, and the project is saved as a new project file (never
  /// overwriting an existing one). Returns the project and the number of sounds.
  static Future<(Settings, int)> importFromFile(
    String zipPath, {
    void Function(int done, int total)? onProgress,
  }) async {
    final input = InputFileStream(zipPath);
    try {
      final Archive archive;
      try {
        archive = ZipDecoder().decodeStream(input);
      } catch (_) {
        throw const FormatException('not a zip');
      }

      final projectFile = archive.findFile(projectEntry);
      if (projectFile == null) throw const FormatException('no project');
      final Map<String, dynamic> map = jsonDecode(utf8.decode(projectFile.content)) as Map<String, dynamic>;

      final tmpDir = await Directory(p.join(documentDirectory.path, '.import_tmp')).create(recursive: true);
      final sounds = archive.files.where((f) => f.isFile && f.name.startsWith(samplesDir)).toList();
      final Map<String, String> storedFor = {};
      int done = 0;
      onProgress?.call(0, sounds.length);
      try {
        for (final f in sounds) {
          final tmpPath = p.join(tmpDir.path, 'part_$done');
          final out = OutputFileStream(tmpPath);
          try {
            f.writeContent(out);
          } finally {
            await out.close();
          }
          f.clear(); // free the decoder's buffer for this entry
          storedFor[f.name] = await SampleStore.adopt(File(tmpPath), p.basename(f.name));
          done++;
          onProgress?.call(done, sounds.length);
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      }

      // Then the project, pointing at the stored sounds.
      final String baseName = ((map['name'] as String?) ?? 'Projet').trim();
      final target = await _freeProjectFile(baseName);
      final settings = Settings.fromJson(target, jsonEncode(map));
      settings.name = p.basenameWithoutExtension(target.path);
      for (final pad in settings.padSettings) {
        if (!pad.hasSample) continue;
        final tracks = [
          for (final t in pad.tracks)
            if (storedFor[t] != null) storedFor[t]!,
        ];
        if (tracks.isEmpty) {
          pad.clearSound();
        } else {
          pad.sample = tracks.first;
          pad.extraTracks = tracks.sublist(1);
        }
      }
      await settings.save();
      return (settings, storedFor.length);
    } finally {
      await input.close();
    }
  }

  static Future<File> _freeProjectFile(String name) async {
    final safe = (name.isEmpty ? 'Projet' : name).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    File f = File(p.join(documentDirectory.path, '$safe.json'));
    int n = 2;
    while (await f.exists()) {
      f = File(p.join(documentDirectory.path, '$safe ($n).json'));
      n++;
    }
    return f;
  }
}

//==============================================================================
