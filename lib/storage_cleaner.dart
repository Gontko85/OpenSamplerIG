//==============================================================================
//    storage_cleaner.dart — find and delete sounds no project uses any more
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:io';

import 'package:path/path.dart' as p;

import 'main.dart';
import 'sample_store.dart';
import 'settings.dart';

//==============================================================================

class StorageReport {
  /// All sound files kept by the app.
  final int soundCount;
  final int soundBytes;

  /// Sounds used by no saved project (safe to delete).
  final List<File> unused;
  final int unusedBytes;

  /// Leftovers of interrupted imports / exports (always safe to delete).
  final List<FileSystemEntity> temporary;
  final int temporaryBytes;

  /// Projects that could not be read: nothing is deleted while there is one.
  final List<String> unreadableProjects;

  const StorageReport({
    required this.soundCount,
    required this.soundBytes,
    required this.unused,
    required this.unusedBytes,
    required this.temporary,
    required this.temporaryBytes,
    required this.unreadableProjects,
  });

  int get freeableBytes => unusedBytes + temporaryBytes;
  bool get safe => unreadableProjects.isEmpty;
}

//==============================================================================

class StorageCleaner {
  /// Looks at every saved project (and [current], the one on screen) to find
  /// which sound files are still used. [cacheDir] is the app cache (exports).
  static Future<StorageReport> analyze({Settings? current, Directory? cacheDir}) async {
    // 1. Every sound referenced by a project (compared by file name inside the store).
    final Set<String> used = {};
    final List<String> unreadable = [];
    void addProject(Settings s) {
      for (final pad in s.padSettings) {
        if (pad.hasSample) used.add(p.basename(pad.sample));
      }
    }

    if (current != null) addProject(current);
    if (await documentDirectory.exists()) {
      await for (final f in documentDirectory.list(followLinks: false)) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        try {
          addProject(Settings.fromJson(f, await f.readAsString()));
        } catch (_) {
          unreadable.add(p.basename(f.path));
        }
      }
    }

    // 2. Sound files in the store.
    int count = 0, bytes = 0, unusedBytes = 0, tempBytes = 0;
    final List<File> unused = [];
    final List<FileSystemEntity> temporary = [];
    final dir = SampleStore.directory;
    if (await dir.exists()) {
      await for (final f in dir.list(followLinks: false)) {
        if (f is! File) continue;
        final int len = await f.length();
        final name = p.basename(f.path);
        if (name.endsWith('.part') || name.endsWith('.repair')) {
          temporary.add(f);
          tempBytes += len;
          continue;
        }
        count++;
        bytes += len;
        if (!used.contains(name)) {
          unused.add(f);
          unusedBytes += len;
        }
      }
    }

    // 3. Leftover temporary folders.
    for (final d in [
      Directory(p.join(documentDirectory.path, '.import_tmp')),
      if (cacheDir != null) Directory(p.join(cacheDir.path, 'exports')),
      if (cacheDir != null) File(p.join(cacheDir.path, 'import.zip')),
    ]) {
      if (!await d.exists()) continue;
      temporary.add(d);
      tempBytes += await _size(d);
    }

    return StorageReport(
      soundCount: count,
      soundBytes: bytes,
      unused: unused,
      unusedBytes: unusedBytes,
      temporary: temporary,
      temporaryBytes: tempBytes,
      unreadableProjects: unreadable,
    );
  }

  /// Deletes what [report] found. Refuses (returns 0) when a project could not
  /// be read, so that no sound of that project can be lost. Returns bytes freed.
  static Future<int> clean(StorageReport report) async {
    if (!report.safe) return 0;
    int freed = 0;
    for (final f in report.unused) {
      // Only ever inside the app's own sound folder.
      if (!p.isWithin(SampleStore.directory.path, f.path)) continue;
      try {
        final len = await f.length();
        await f.delete();
        freed += len;
      } catch (_) {}
    }
    for (final e in report.temporary) {
      try {
        final len = await _size(e);
        await e.delete(recursive: true);
        freed += len;
      } catch (_) {}
    }
    return freed;
  }

  static Future<int> _size(FileSystemEntity e) async {
    if (e is File) return e.length();
    if (e is Directory) {
      int total = 0;
      await for (final f in e.list(recursive: true, followLinks: false)) {
        if (f is File) total += await f.length();
      }
      return total;
    }
    return 0;
  }

  /// "1,2 Go" / "350 Mo" / "12 ko".
  static String formatBytes(int b, {bool fr = true}) {
    String n(double v) => fr ? v.toStringAsFixed(1).replaceAll('.', ',') : v.toStringAsFixed(1);
    if (b >= 1 << 30) return '${n(b / (1 << 30))} ${fr ? 'Go' : 'GB'}';
    if (b >= 1 << 20) return '${(b / (1 << 20)).round()} ${fr ? 'Mo' : 'MB'}';
    return '${(b / 1024).ceil()} ${fr ? 'ko' : 'KB'}';
  }
}

//==============================================================================
