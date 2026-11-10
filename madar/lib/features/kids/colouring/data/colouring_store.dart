// Where colouring lives on the phone: Madar's private folder, nothing else.
//
//   <root>/pictures/<id>/original.<ext>   the file as the parent picked it (a copy)
//   <root>/pictures/<id>/art.gray         the downscaled grey page (see [encodeArt])
//   <root>/pictures/<id>/meta.json        size, mode and the colours (a list of fills)
//   <root>/progress/<page>.json           the colours of a built-in page
//
// A picture is never referenced by its gallery path: the copy is the picture,
// so deleting the original later changes nothing, and nothing here reads or
// writes anywhere else, and nothing is uploaded.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:path/path.dart' as p;

import '../domain/flood_fill.dart';
import '../domain/vector_colouring.dart';
import 'image_import.dart';

/// How a picture became a page.
enum PictureMode { asIs, outline }

@immutable
class PictureRecord {
  const PictureRecord({
    required this.id,
    required this.createdAt,
    required this.width,
    required this.height,
    required this.mode,
    this.ops = const [],
  });

  final String id;
  final DateTime createdAt;
  final int width, height;
  final PictureMode mode;

  /// The fills painted so far (empty = untouched).
  final List<FillOp> ops;

  bool get started => ops.isNotEmpty;

  PictureRecord withOps(List<FillOp> o) =>
      PictureRecord(id: id, createdAt: createdAt, width: width, height: height, mode: mode, ops: o);
}

/// The bytes of a grey page: `MKA1`, width and height (uint32 big endian), then
/// one byte per pixel.
Uint8List encodeArt(LineArt art) {
  final out = Uint8List(12 + art.grey.length);
  out.setAll(0, const [0x4D, 0x4B, 0x41, 0x31]);
  final bd = ByteData.sublistView(out);
  bd.setUint32(4, art.width);
  bd.setUint32(8, art.height);
  out.setAll(12, art.grey);
  return out;
}

/// The inverse of [encodeArt]; null for anything that is not a valid page.
LineArt? decodeArt(Uint8List bytes) {
  if (bytes.length < 13 || bytes[0] != 0x4D || bytes[1] != 0x4B || bytes[2] != 0x41 || bytes[3] != 0x31) return null;
  final bd = ByteData.sublistView(bytes);
  final w = bd.getUint32(4), h = bd.getUint32(8);
  if (w == 0 || h == 0 || w > 4096 || h > 4096 || bytes.length != 12 + w * h) return null;
  return LineArt(w, h, Uint8List.sublistView(bytes, 12));
}

class ColouringStore {
  ColouringStore(this.root, {Random? random, DateTime Function()? clock})
    : _random = random ?? Random.secure(),
      _clock = clock ?? DateTime.now;

  /// The private folder everything lives under.
  final Directory root;
  final Random _random;
  final DateTime Function() _clock;

  Directory get _pictures => Directory(p.join(root.path, 'pictures'));
  Directory get _progress => Directory(p.join(root.path, 'progress'));
  Directory _dir(String id) => Directory(p.join(_pictures.path, id));

  static final RegExp _idPattern = RegExp(r'^[a-z0-9]{6,32}$');

  String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes([for (var i = 0; i < 12; i++) alphabet.codeUnitAt(_random.nextInt(alphabet.length))]);
  }

  /// Every saved picture, oldest first. A damaged folder is skipped, never an
  /// error.
  Future<List<PictureRecord>> pictures() async {
    if (!_pictures.existsSync()) return const [];
    final out = <PictureRecord>[];
    for (final e in _pictures.listSync().whereType<Directory>()) {
      final rec = await _readMeta(p.basename(e.path));
      if (rec != null) out.add(rec);
    }
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  Future<PictureRecord?> _readMeta(String id) async {
    if (!_idPattern.hasMatch(id)) return null;
    final f = File(p.join(_dir(id).path, 'meta.json'));
    try {
      if (!f.existsSync() || !File(p.join(_dir(id).path, 'art.gray')).existsSync()) return null;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final ops = <FillOp>[for (final o in (j['ops'] as List? ?? const [])) ?FillOp.fromJson(o)];
      return PictureRecord(
        id: id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int, isUtc: true),
        width: j['w'] as int,
        height: j['h'] as int,
        mode: PictureMode.values.byName(j['mode'] as String),
        ops: ops,
      );
    } catch (_) {
      return null;
    }
  }

  /// Copies the picked file and its page into the private folder.
  Future<PictureRecord> addPicture(ImportCandidate candidate, LineArt art, PictureMode mode) async {
    final id = _newId();
    final dir = _dir(id)..createSync(recursive: true);
    try {
      await File(p.join(dir.path, 'original.${candidate.kind.extension}'))
          .writeAsBytes(candidate.originalBytes, flush: true);
      await _atomicWrite(File(p.join(dir.path, 'art.gray')), encodeArt(art));
      final rec = PictureRecord(id: id, createdAt: _clock().toUtc(), width: art.width, height: art.height, mode: mode);
      await _writeMeta(rec);
      return rec;
    } catch (_) {
      // No half-made pictures: a failed import leaves nothing behind.
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      rethrow;
    }
  }

  Future<void> _writeMeta(PictureRecord r) => _atomicWrite(
    File(p.join(_dir(r.id).path, 'meta.json')),
    utf8.encode(
      jsonEncode({
        'v': 1,
        'createdAt': r.createdAt.millisecondsSinceEpoch,
        'w': r.width,
        'h': r.height,
        'mode': r.mode.name,
        'ops': [for (final o in r.ops) o.toJson()],
      }),
    ),
  );

  /// The grey page of [id], or null if it is missing or damaged.
  Future<LineArt?> loadArt(String id) async {
    if (!_idPattern.hasMatch(id)) return null;
    final f = File(p.join(_dir(id).path, 'art.gray'));
    if (!f.existsSync()) return null;
    return decodeArt(await f.readAsBytes());
  }

  /// Saves the colours of a picture (the whole list of fills).
  Future<void> savePictureOps(String id, List<FillOp> ops) async {
    final rec = await _readMeta(id);
    if (rec == null) return;
    await _writeMeta(rec.withOps(ops));
  }

  /// Parent-only: removes the copy, the page and the colours.
  Future<void> deletePicture(String id) async {
    if (!_idPattern.hasMatch(id)) return;
    final d = _dir(id);
    if (d.existsSync()) d.deleteSync(recursive: true);
  }

  // ---- built-in pages -------------------------------------------------------

  File _progressFile(String pageId) =>
      File(p.join(_progress.path, '${pageId.replaceAll(RegExp(r'[^a-z0-9_]'), '')}.json'));

  Future<List<RegionFill>> loadPageOps(String pageId) async {
    final f = _progressFile(pageId);
    try {
      if (!f.existsSync()) return const [];
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return [for (final o in (j['ops'] as List? ?? const [])) ?RegionFill.fromJson(o)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePageOps(String pageId, List<RegionFill> ops) {
    _progress.createSync(recursive: true);
    return _atomicWrite(
      _progressFile(pageId),
      utf8.encode(
        jsonEncode({
          'v': 1,
          'ops': [for (final o in ops) o.toJson()],
        }),
      ),
    );
  }

  /// Write to a temporary file and rename, so a battery dying mid-save leaves
  /// either the old file or the new one, never half of each.
  Future<void> _atomicWrite(File target, List<int> bytes) async {
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(target.path);
  }
}
