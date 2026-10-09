//==============================================================================
//    sample_store.dart
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:io';

import 'package:path/path.dart' as p;

import 'main.dart';

//==============================================================================

/// Keeps a private copy of every sample chosen by the user.
///
/// The file picker only hands back a path in a temporary cache that Android
/// may wipe at any time, which made pads go silent. Copying the file into the
/// app's own documents folder makes the pad independent from that cache.
class SampleStore {
  static Directory get directory => Directory(p.join(documentDirectory.path, 'samples'));

  static bool isManaged(String path) => p.isWithin(directory.path, path);

  /// Stores the picked file ([name], streamed from [bytes]) in the samples
  /// folder and returns its new path. [length] lets us reuse an identical copy.
  static Future<String> import(String name, Stream<List<int>> bytes, {int? length}) async {
    final dir = directory;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final String base = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    String target = p.join(dir.path, base);

    final existing = File(target);
    if (await existing.exists()) {
      // Same name and same size: almost certainly the same sound, reuse it.
      if (length != null && await existing.length() == length) {
        return target;
      }
      final String stamp = DateTime.now().millisecondsSinceEpoch.toString();
      target = p.join(dir.path, '${p.basenameWithoutExtension(base)}_$stamp${p.extension(base)}');
    }

    final tmp = File('$target.part');
    final sink = tmp.openWrite();
    try {
      await sink.addStream(bytes);
      await sink.flush();
    } finally {
      await sink.close();
    }
    await tmp.rename(target);
    return target;
  }

  static Future<bool> exists(String path) async => path.isNotEmpty && await File(path).exists();
}

//==============================================================================
