//==============================================================================
//    native_files.dart — save / share a big file without loading it in memory
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'package:flutter/services.dart';

/// Thin wrapper over the Android side (MainActivity.kt): the file is copied
/// natively, from disk to disk, in small chunks.
class NativeFiles {
  static const _channel = MethodChannel('opensampler/files');

  /// Opens the Android "save as" dialog, then copies [path] there.
  /// Returns false when the user cancelled.
  static Future<bool> saveFile(String path, String name, {String mime = 'application/zip'}) async {
    final ok = await _channel.invokeMethod<bool>('saveFile', {'path': path, 'name': name, 'mime': mime});
    return ok ?? false;
  }

  /// Opens the Android share sheet (Quick Share, Drive, Bluetooth, e-mail…).
  static Future<void> shareFile(String path, {String mime = 'application/zip', String title = ''}) async {
    await _channel.invokeMethod<bool>('shareFile', {'path': path, 'mime': mime, 'title': title});
  }
}
