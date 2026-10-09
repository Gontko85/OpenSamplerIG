//==============================================================================
//    project_archive.dart — export / import a project with its sounds
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  /// Builds the .zip bytes for [settings]. Missing sound files are skipped.
  static Future<Uint8List> export(Settings settings) async {
    final archive = Archive();
    final Map<String, String> entryForPath = {};
    final Set<String> usedNames = {};

    final copy = Settings.copy(settings);
    for (final pad in copy.padSettings) {
      if (!pad.hasSample) continue;
      final src = File(pad.sample);
      if (!await src.exists()) {
        pad.sample = "";
        continue;
      }

      String? entry = entryForPath[pad.sample];
      if (entry == null) {
        // Unique entry name, even if two different files share a name.
        String name = p.basename(pad.sample);
        int n = 2;
        while (usedNames.contains(name)) {
          name = '${p.basenameWithoutExtension(pad.sample)}_$n${p.extension(pad.sample)}';
          n++;
        }
        usedNames.add(name);
        entry = '$samplesDir$name';
        entryForPath[pad.sample] = entry;

        final bytes = await src.readAsBytes();
        // Audio is already compressed: store it as is (much faster).
        archive.addFile(ArchiveFile.noCompress(entry, bytes.length, bytes));
      }
      pad.sample = entry;
    }

    final Map<String, dynamic> json = copy.toJson()
      ..['format'] = 'opensampler-ig'
      ..['formatVersion'] = formatVersion;
    archive.addFile(ArchiveFile.string(projectEntry, const JsonEncoder.withIndent('  ').convert(json)));

    return ZipEncoder().encodeBytes(archive);
  }

  /// Suggested file name for the export.
  static String fileNameFor(Settings s) {
    final safe = s.name.trim().isEmpty ? 'projet' : s.name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$safe.opensampler.zip';
  }

  //----------------------------------------------------------------------------

  /// Imports an exported project. Sounds go to the app's sample store and the
  /// project is saved as a new project file (never overwriting an existing one).
  /// Returns the project and the number of sounds imported.
  static Future<(Settings, int)> import(Uint8List zipBytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } catch (_) {
      throw const FormatException('not a zip');
    }

    final projectFile = archive.findFile(projectEntry);
    if (projectFile == null) throw const FormatException('no project');

    final Map<String, dynamic> map = jsonDecode(utf8.decode(projectFile.content)) as Map<String, dynamic>;

    // Sounds first.
    final Map<String, String> storedFor = {};
    for (final f in archive.files) {
      if (!f.isFile || !f.name.startsWith(samplesDir)) continue;
      final bytes = f.content;
      final stored = await SampleStore.import(
        p.basename(f.name),
        Stream<List<int>>.value(bytes),
        length: bytes.length,
      );
      storedFor[f.name] = stored;
    }

    // Then the project, pointing at the stored sounds.
    final String baseName = ((map['name'] as String?) ?? 'Projet').trim();
    final target = await _freeProjectFile(baseName);
    final settings = Settings.fromJson(target, jsonEncode(map));
    settings.name = p.basenameWithoutExtension(target.path);
    for (final pad in settings.padSettings) {
      if (!pad.hasSample) continue;
      pad.sample = storedFor[pad.sample] ?? "";
    }
    await settings.save();
    return (settings, storedFor.length);
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
