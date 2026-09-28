import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/sound/soloud_sound_service.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/audio_probe.dart';

/// A recording the user attached to a dhikr (never a generated voice).
@immutable
class DhikrAudioInfo {
  const DhikrAudioInfo({
    required this.dhikrId,
    required this.storedName,
    required this.originalName,
    required this.bytes,
    required this.addedAt,
    this.duration,
  });

  final String dhikrId;

  /// File name inside the app's private audio folder.
  final String storedName;

  /// The name the file had when the user picked it.
  final String originalName;
  final int bytes;
  final Duration? duration;
  final DateTime addedAt;

  Map<String, Object?> toJson() => {
    'storedName': storedName,
    'originalName': originalName,
    'bytes': bytes,
    'durationMs': ?duration?.inMilliseconds,
    'addedAt': addedAt.toIso8601String(),
  };

  static DhikrAudioInfo? fromJson(String dhikrId, Object? json) {
    if (json is! Map) return null;
    final stored = json['storedName'], original = json['originalName'], bytes = json['bytes'];
    if (stored is! String || original is! String || bytes is! num) return null;
    final ms = json['durationMs'];
    return DhikrAudioInfo(
      dhikrId: dhikrId,
      storedName: stored,
      originalName: original,
      bytes: bytes.toInt(),
      duration: ms is num ? Duration(milliseconds: ms.toInt()) : null,
      addedAt: DateTime.tryParse('${json['addedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DhikrAudioInfo &&
      other.dhikrId == dhikrId &&
      other.storedName == storedName &&
      other.originalName == originalName &&
      other.bytes == bytes &&
      other.duration == duration &&
      other.addedAt == addedAt;

  @override
  int get hashCode => Object.hash(dhikrId, storedName, originalName, bytes, duration, addedAt);
}

/// A file the user picked.
typedef PickedAudio = ({String name, Uint8List bytes});

enum DhikrAudioProblem {
  /// Not MP3, WAV or FLAC.
  unsupported,

  /// Larger than [DhikrAudioStore.maxBytes].
  tooLarge,
}

class DhikrAudioException implements Exception {
  const DhikrAudioException(this.problem);

  final DhikrAudioProblem problem;

  @override
  String toString() => 'DhikrAudioException(${problem.name})';
}

/// Attached recordings, one per dhikr.
abstract interface class DhikrAudioStore {
  static const int maxBytes = 30 * 1024 * 1024;

  Stream<Map<String, DhikrAudioInfo>> watch();

  Future<Map<String, DhikrAudioInfo>> all();

  /// Copies [audio] into the app's storage for [dhikrId], replacing any
  /// earlier recording. Throws [DhikrAudioException].
  Future<DhikrAudioInfo> attach(String dhikrId, PickedAudio audio);

  Future<Uint8List?> read(String dhikrId);

  /// Removes [dhikrId]'s recording; returns an undo (null when none).
  Future<Future<void> Function()?> remove(String dhikrId);
}

/// Stores recordings as files in the app's private support directory
/// (`adhkar_audio/`, sandboxed and covered by Android's file-based
/// encryption); their metadata sits in the encrypted key/value store under
/// [metaKey].
class FileDhikrAudioStore implements DhikrAudioStore {
  FileDhikrAudioStore(this.kv, {Future<Directory> Function()? directory, DateTime Function()? clock})
    : _directory = directory ?? _defaultDirectory,
      _clock = clock ?? DateTime.now;

  static const String metaKey = 'adhkar.audio';

  final KeyValueRepository kv;
  final Future<Directory> Function() _directory;
  final DateTime Function() _clock;

  static Future<Directory> _defaultDirectory() async =>
      Directory(p.join((await getApplicationSupportDirectory()).path, 'adhkar_audio'));

  static Map<String, DhikrAudioInfo> _decode(Object? json) => {
    if (json is Map)
      for (final e in json.entries)
        if (e.key is String && DhikrAudioInfo.fromJson(e.key as String, e.value) != null)
          e.key as String: DhikrAudioInfo.fromJson(e.key as String, e.value)!,
  };

  @override
  Stream<Map<String, DhikrAudioInfo>> watch() => kv.watchJson(metaKey).map(_decode);

  @override
  Future<Map<String, DhikrAudioInfo>> all() async => _decode(await kv.getJson(metaKey));

  Future<void> _save(Map<String, DhikrAudioInfo> map) =>
      kv.setJson(metaKey, {for (final e in map.entries) e.key: e.value.toJson()});

  static String _safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  @override
  Future<DhikrAudioInfo> attach(String dhikrId, PickedAudio audio) async {
    if (audio.bytes.length > DhikrAudioStore.maxBytes) throw const DhikrAudioException(DhikrAudioProblem.tooLarge);
    final format = AudioProbe.sniff(audio.bytes);
    if (format == null) throw const DhikrAudioException(DhikrAudioProblem.unsupported);
    final dir = await _directory();
    await dir.create(recursive: true);
    final now = _clock();
    final storedName = '${_safe(dhikrId)}_${now.millisecondsSinceEpoch}.${format.extension}';
    await File(p.join(dir.path, storedName)).writeAsBytes(audio.bytes, flush: true);
    final map = await all();
    final previous = map[dhikrId];
    final info = DhikrAudioInfo(
      dhikrId: dhikrId,
      storedName: storedName,
      originalName: audio.name,
      bytes: audio.bytes.length,
      duration: AudioProbe.duration(audio.bytes),
      addedAt: now,
    );
    map[dhikrId] = info;
    await _save(map);
    if (previous != null) await _deleteFile(dir, previous.storedName);
    return info;
  }

  @override
  Future<Uint8List?> read(String dhikrId) async {
    final info = (await all())[dhikrId];
    if (info == null) return null;
    final file = File(p.join((await _directory()).path, info.storedName));
    return file.existsSync() ? file.readAsBytes() : null;
  }

  @override
  Future<Future<void> Function()?> remove(String dhikrId) async {
    final map = await all();
    final info = map.remove(dhikrId);
    if (info == null) return null;
    final dir = await _directory();
    final file = File(p.join(dir.path, info.storedName));
    // Keep the bytes in memory for the undo toast; the file goes now.
    final bytes = file.existsSync() ? await file.readAsBytes() : null;
    await _save(map);
    await _deleteFile(dir, info.storedName);
    return () async {
      if (bytes != null) {
        await dir.create(recursive: true);
        await File(p.join(dir.path, info.storedName)).writeAsBytes(bytes, flush: true);
      }
      final now = await all();
      now[dhikrId] = info;
      await _save(now);
    };
  }

  static Future<void> _deleteFile(Directory dir, String name) async {
    final f = File(p.join(dir.path, name));
    if (f.existsSync()) await f.delete();
  }
}

/// Opens the system picker for an audio file (MP3, WAV or FLAC). Throws
/// [DhikrAudioException] for a file that is too large.
Future<PickedAudio?> pickDhikrAudio() async {
  final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: DhikrAudioFormat.extensions);
  if (file == null) return null;
  return readPickedAudio(file);
}

/// Reads a picked file – after checking its size, so a long recording (a
/// whole lecture, hundreds of MB) is refused before it is loaded into
/// memory rather than after.
Future<PickedAudio> readPickedAudio(PlatformFile file) async {
  final length = file.lengthSync() ?? await file.length();
  if (length != null && length > DhikrAudioStore.maxBytes) throw const DhikrAudioException(DhikrAudioProblem.tooLarge);
  final bytes = await file.readAsBytes();
  if (bytes.length > DhikrAudioStore.maxBytes) throw const DhikrAudioException(DhikrAudioProblem.tooLarge);
  return (name: file.name, bytes: bytes);
}

/// Plays attached recordings.
abstract interface class DhikrAudioPlayer {
  /// Starts [bytes] (the recording of [dhikrId]); false when nothing plays.
  Future<bool> play(String dhikrId, Uint8List bytes);

  void stop();

  Future<void> dispose();
}

/// Plays through the app's flutter_soloud engine on the prayer bus (never
/// muted by the prayer mute; audible even with interface sounds off,
/// because the user pressed play). Silent when the engine is unavailable.
class SoloudDhikrAudioPlayer implements DhikrAudioPlayer {
  SoloudDhikrAudioPlayer(this.sound);

  final SoundService sound;
  SoundClip? _clip;
  String? _clipKey;
  int? _voice;

  @override
  Future<bool> play(String dhikrId, Uint8List bytes) async {
    final engine = sound;
    if (engine is! SoloudSoundService) return false;
    stop();
    final key = '$dhikrId#${bytes.length}';
    if (_clipKey != key) {
      final old = _clip;
      _clip = null;
      _clipKey = null;
      if (old != null) await engine.unloadClip(old);
      _clip = await engine.loadClip('dhikr/$dhikrId', bytes);
      if (_clip == null) return false;
      _clipKey = key;
    }
    _voice = engine.playClip(_clip!, category: SoundCategory.prayer, bypassGlobalSwitch: true);
    return _voice != null;
  }

  @override
  void stop() {
    final engine = sound, voice = _voice;
    _voice = null;
    if (voice != null && engine is SoloudSoundService) engine.stopClip(voice);
  }

  @override
  Future<void> dispose() async {
    stop();
    final engine = sound, clip = _clip;
    _clip = null;
    _clipKey = null;
    if (clip != null && engine is SoloudSoundService) await engine.unloadClip(clip);
  }
}
