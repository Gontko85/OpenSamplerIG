//==============================================================================
//    audio_repair.dart — turn "fake MP3" files into real MP3, losslessly
//    Released under EUPL 1.2
//    Copyright IG Littoral Labs 2026
//==============================================================================

import 'dart:io';
import 'dart:typed_data';

//==============================================================================

/// Some ".mp3" files are really MPEG Program Streams (the .mpg / DVD video
/// container) holding MP3 audio: video editors and converters produce them.
/// PC players read them anyway, but Android refuses them (red badge on the pad).
///
/// [AudioRepair] detects them and extracts the audio packets into a plain MP3
/// file. Nothing is re-encoded: the sound is bit-for-bit the same.
class AudioRepair {
  /// True when the file starts like an MPEG Program Stream (pack start code).
  static Future<bool> isMpegProgramStream(String path) async {
    final f = File(path);
    if (!await f.exists()) return false;
    final raf = await f.open();
    try {
      final b = await raf.read(4);
      return b.length == 4 && b[0] == 0 && b[1] == 0 && b[2] == 1 && b[3] == 0xBA;
    } finally {
      await raf.close();
    }
  }

  /// Repairs the file in place if needed. Returns true when it was repaired.
  /// Leaves the file untouched (and returns false) when it is not a program
  /// stream, or when no audio could be extracted.
  static Future<bool> repairIfNeeded(String path) async {
    if (!await isMpegProgramStream(path)) return false;
    final tmp = File('$path.repair');
    try {
      final written = await extractAudio(path, tmp.path);
      if (written <= 0) {
        if (await tmp.exists()) await tmp.delete();
        return false;
      }
      await tmp.rename(path);
      return true;
    } catch (_) {
      if (await tmp.exists()) await tmp.delete();
      return false;
    }
  }

  /// Copies the payload of the first audio stream (PES ids 0xC0–0xDF) of the
  /// program stream [src] into [dst]. Streams through the file in chunks, so
  /// memory use stays small whatever the size. Returns the bytes written.
  static Future<int> extractAudio(String src, String dst) async {
    final reader = _Reader(await File(src).open());
    final sink = File(dst).openWrite();
    int written = 0;
    int? audioId;
    try {
      while (true) {
        // Find the next start code 00 00 01 xx.
        final int? code = await reader.nextStartCode();
        if (code == null || code == 0xB9) break; // end of file / program end

        if (code == 0xBA) {
          // Pack header: MPEG-1 (12 bytes in all) or MPEG-2 (14 + stuffing).
          final first = await reader.peek(1);
          if (first.isEmpty) break;
          if ((first[0] & 0xC0) == 0x40) {
            final h = await reader.read(10);
            if (h.length < 10) break;
            await reader.skip(h[9] & 0x07);
          } else {
            await reader.skip(8);
          }
          continue;
        }

        if (code < 0xB9) continue; // not a system-level code: keep scanning

        // Every other code has a 16-bit length: system header, padding, PES…
        final lenBytes = await reader.read(2);
        if (lenBytes.length < 2) break;
        final int length = (lenBytes[0] << 8) | lenBytes[1];

        final bool isAudio = code >= 0xC0 && code <= 0xDF;
        if (!isAudio || (audioId != null && code != audioId)) {
          await reader.skip(length);
          continue;
        }
        audioId ??= code;

        final packet = await reader.read(length);
        if (packet.length < length) {
          // Truncated last packet: keep what we have of it.
          final p = _payloadOffset(packet);
          if (p != null && p < packet.length) {
            sink.add(packet.sublist(p));
            written += packet.length - p;
          }
          break;
        }
        final p = _payloadOffset(packet);
        if (p == null || p > packet.length) continue;
        sink.add(Uint8List.sublistView(packet, p));
        written += packet.length - p;
      }
    } finally {
      await sink.close();
      await reader.close();
    }
    return written;
  }

  /// Offset of the audio data inside a PES packet (after its header), for
  /// both MPEG-2 and MPEG-1 style headers. Null if the header is malformed.
  static int? _payloadOffset(Uint8List d) {
    if (d.isEmpty) return null;
    // MPEG-2 PES header: '10' marker bits, then flags, then header length.
    if ((d[0] & 0xC0) == 0x80) {
      if (d.length < 3) return null;
      return 3 + d[2];
    }
    // MPEG-1 PES header.
    int i = 0;
    while (i < d.length && d[i] == 0xFF && i < 16) {
      i++; // stuffing
    }
    if (i >= d.length) return null;
    if ((d[i] & 0xC0) == 0x40) i += 2; // STD buffer size
    if (i >= d.length) return null;
    if ((d[i] & 0xF0) == 0x20) return i + 5; // PTS
    if ((d[i] & 0xF0) == 0x30) return i + 10; // PTS + DTS
    if (d[i] == 0x0F) return i + 1; // no timestamps
    return null;
  }
}

//==============================================================================

/// Small buffered reader over a file, with start-code scanning.
class _Reader {
  final RandomAccessFile _raf;
  Uint8List _buf = Uint8List(0);
  int _pos = 0;
  bool _eof = false;
  static const int _chunk = 256 * 1024;

  _Reader(this._raf);

  Future<void> _fill(int need) async {
    while (_buf.length - _pos < need && !_eof) {
      final more = await _raf.read(_chunk);
      if (more.isEmpty) {
        _eof = true;
        break;
      }
      final rest = _buf.length - _pos;
      final nb = Uint8List(rest + more.length);
      nb.setRange(0, rest, _buf, _pos);
      nb.setRange(rest, nb.length, more);
      _buf = nb;
      _pos = 0;
    }
  }

  Future<Uint8List> peek(int n) async {
    await _fill(n);
    final end = (_pos + n).clamp(0, _buf.length);
    return Uint8List.sublistView(_buf, _pos, end);
  }

  Future<Uint8List> read(int n) async {
    final b = Uint8List.fromList(await peek(n));
    _pos += b.length;
    return b;
  }

  Future<void> skip(int n) async {
    while (n > 0) {
      await _fill(1);
      final avail = _buf.length - _pos;
      if (avail <= 0) return;
      final s = n < avail ? n : avail;
      _pos += s;
      n -= s;
    }
  }

  /// Advances past the next 00 00 01 and returns the code byte, or null at EOF.
  Future<int?> nextStartCode() async {
    while (true) {
      await _fill(4);
      if (_buf.length - _pos < 4) return null;
      final end = _buf.length - 3;
      for (int i = _pos; i < end; i++) {
        if (_buf[i] == 0 && _buf[i + 1] == 0 && _buf[i + 2] == 1) {
          _pos = i + 4;
          return _buf[i + 3];
        }
      }
      _pos = end; // keep the last 3 bytes: a code may straddle two chunks
      if (_eof) return null;
      await _fill(_chunk);
    }
  }

  Future<void> close() => _raf.close();
}

//==============================================================================
