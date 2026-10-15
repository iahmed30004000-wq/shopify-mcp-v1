import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/adhan_sound.dart';
import '../domain/audio_length.dart';
import 'adhan_system.dart';

/// A file the user picked.
@immutable
class PickedAudio {
  const PickedAudio({required this.name, required this.read});

  /// File name as the picker reports it (with extension).
  final String name;
  final Future<Uint8List> Function() read;
}

/// Opens the system audio picker (file_picker in production).
abstract interface class AudioFilePicker {
  Future<PickedAudio?> pick();
}

class SystemAudioFilePicker implements AudioFilePicker {
  const SystemAudioFilePicker();

  @override
  Future<PickedAudio?> pick() async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    if (file == null) return null;
    return PickedAudio(name: file.name, read: file.readAsBytes);
  }
}

enum MuezzinImportError { cancelled, unsupported, tooLarge, unreadable }

/// The outcome of [MuezzinLibrary.pickAndImport].
@immutable
class MuezzinImport {
  const MuezzinImport.ok(CustomMuezzin this.muezzin) : error = null;
  const MuezzinImport.failed(MuezzinImportError this.error) : muezzin = null;

  final CustomMuezzin? muezzin;
  final MuezzinImportError? error;
}

/// The muezzin recordings the user attaches: copied into Madar's private
/// sound folder (the one `AdhanSoundProvider.kt` serves to the system), named
/// `<id>.<ext>`, with their length read from the headers.
///
/// Nothing leaves the device; the copy is the app's own (deleting the
/// original later changes nothing).
class MuezzinLibrary {
  MuezzinLibrary({
    required this.system,
    this.picker = const SystemAudioFilePicker(),
    Future<Directory> Function()? fallbackDirectory,
    DateTime Function()? clock,
    Random? random,
  }) : _fallbackDirectory = fallbackDirectory ?? _supportDirectory,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final AdhanSystem system;
  final AudioFilePicker picker;
  final Future<Directory> Function() _fallbackDirectory;
  final DateTime Function() _clock;
  final Random _random;

  /// Formats Android can play as a notification sound.
  static const extensions = {'mp3', 'wav', 'ogg', 'opus', 'm4a', 'aac', 'flac'};

  /// Larger files are refused (an adhan recording is a few MB).
  static const maxBytes = 25 * 1024 * 1024;

  static Future<Directory> _supportDirectory() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/adhan_sounds');

  Future<Directory> directory() async {
    final path = await system.soundsDirectory();
    final dir = path == null ? await _fallbackDirectory() : Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static String? extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    final ext = name.substring(dot + 1).toLowerCase();
    return extensions.contains(ext) ? ext : null;
  }

  /// A display name from a file name: extension dropped, separators as
  /// spaces, at most 40 characters.
  static String displayNameOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    var base = (dot > 0 ? fileName.substring(0, dot) : fileName).replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    base = base.replaceAll(RegExp(r'\s+'), ' ');
    if (base.length > 40) base = base.substring(0, 40).trim();
    return base;
  }

  String _newId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes([for (var i = 0; i < 12; i++) alphabet.codeUnitAt(_random.nextInt(alphabet.length))]);
  }

  /// Picks a recording and copies it in. The caller stores the returned
  /// [CustomMuezzin] in the adhan settings.
  Future<MuezzinImport> pickAndImport() async {
    final PickedAudio? picked;
    try {
      picked = await picker.pick();
    } catch (e) {
      debugPrint('MuezzinLibrary: picker failed: $e');
      return const MuezzinImport.failed(MuezzinImportError.unreadable);
    }
    if (picked == null) return const MuezzinImport.failed(MuezzinImportError.cancelled);
    return import(picked);
  }

  /// Copies [picked] into the sound folder.
  Future<MuezzinImport> import(PickedAudio picked) async {
    final ext = extensionOf(picked.name);
    if (ext == null) return const MuezzinImport.failed(MuezzinImportError.unsupported);
    final Uint8List bytes;
    try {
      bytes = await picked.read();
    } catch (_) {
      return const MuezzinImport.failed(MuezzinImportError.unreadable);
    }
    if (bytes.isEmpty) return const MuezzinImport.failed(MuezzinImportError.unreadable);
    if (bytes.length > maxBytes) return const MuezzinImport.failed(MuezzinImportError.tooLarge);
    final id = _newId();
    final fileName = '$id.$ext';
    try {
      final dir = await directory();
      await File('${dir.path}/$fileName').writeAsBytes(bytes, flush: true);
    } catch (e) {
      debugPrint('MuezzinLibrary: copy failed: $e');
      return const MuezzinImport.failed(MuezzinImportError.unreadable);
    }
    final name = displayNameOf(picked.name);
    return MuezzinImport.ok(
      CustomMuezzin(
        id: id,
        name: name.isEmpty ? id : name,
        fileName: fileName,
        length: AudioLength.of(bytes, extension: ext),
        addedAt: _clock().toUtc(),
      ),
    );
  }

  Future<File> fileOf(CustomMuezzin m) async => File('${(await directory()).path}/${m.fileName}');

  Future<Uint8List?> bytesOf(CustomMuezzin m) async {
    try {
      final f = await fileOf(m);
      return f.existsSync() ? await f.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  /// Deletes recordings no settings entry refers to any more (a delete whose
  /// undo window passed while the app was killed), older than [minAge].
  Future<int> pruneOrphans(Set<String> keepFileNames, {Duration minAge = const Duration(hours: 1)}) async {
    var removed = 0;
    try {
      final dir = await directory();
      final now = _clock();
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (keepFileNames.contains(name)) continue;
        if (now.difference(f.lastModifiedSync()) < minAge) continue;
        await f.delete();
        removed++;
      }
    } catch (e) {
      debugPrint('MuezzinLibrary: prune failed: $e');
    }
    return removed;
  }

  Future<void> delete(CustomMuezzin m) async {
    try {
      final f = await fileOf(m);
      if (f.existsSync()) await f.delete();
    } catch (e) {
      debugPrint('MuezzinLibrary: delete failed: $e');
    }
  }
}
