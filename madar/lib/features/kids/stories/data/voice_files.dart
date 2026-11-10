import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where recordings live and how they are moved. Everything is inside the
/// app's own private folder: never the gallery, never shared storage, never
/// uploaded.
abstract interface class VoiceFiles {
  /// Full path of the final recording of story [id].
  Future<String> finalPath(String id);

  /// Full path of the file a recording of story [id] is captured into; it
  /// becomes the final one only when the recording ends well.
  Future<String> tempPath(String id);

  /// Full path of the file named [fileName] in the folder.
  Future<String> resolve(String fileName);

  Future<bool> exists(String path);

  /// Puts [from] in place of [to] (atomic where the platform allows).
  Future<void> replace(String from, String to);

  Future<void> delete(String path);

  /// Deletes every file in the folder whose name is not in [keep] (half
  /// recordings left by a crash, files of deleted stories). Returns how many.
  Future<int> sweep(Set<String> keep);
}

/// The real thing: `<application support>/kids_voice_stories/`.
class PrivateVoiceFiles implements VoiceFiles {
  PrivateVoiceFiles({Future<Directory> Function()? root}) : _root = root ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _root;
  Directory? _dir;

  static const String folderName = 'kids_voice_stories';
  static const String extension = '.m4a';

  Future<Directory> _folder() async {
    final d = _dir;
    if (d != null) return d;
    final dir = Directory(p.join((await _root()).path, folderName));
    await dir.create(recursive: true);
    return _dir = dir;
  }

  @override
  Future<String> finalPath(String id) async => p.join((await _folder()).path, '$id$extension');

  @override
  Future<String> tempPath(String id) async => p.join((await _folder()).path, '$id.rec$extension');

  @override
  Future<String> resolve(String fileName) async => p.join((await _folder()).path, p.basename(fileName));

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<void> replace(String from, String to) async {
    await File(from).rename(to);
  }

  @override
  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<int> sweep(Set<String> keep) async {
    final dir = await _folder();
    var n = 0;
    await for (final e in dir.list(followLinks: false)) {
      if (e is File && !keep.contains(p.basename(e.path))) {
        await e.delete();
        n++;
      }
    }
    return n;
  }
}
