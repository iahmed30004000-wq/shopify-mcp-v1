import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/quran/ayah.dart';
import '../domain/reciters.dart';

/// Where downloaded recitations live: `<app support>/recitation/<folder>/<SSSAAA>.mp3`
/// (private to the app, not backed up), with `.part` files for interrupted
/// downloads and `downloads.json` as the index.
class RecitationStorage {
  RecitationStorage(Future<Directory> Function() root) : _resolveRoot = root;

  /// The app support directory (path_provider).
  factory RecitationStorage.appSupport() =>
      RecitationStorage(() async => Directory(p.join((await getApplicationSupportDirectory()).path, 'recitation')));

  /// A fixed directory (tests).
  factory RecitationStorage.at(Directory root) => RecitationStorage(() async => root);

  final Future<Directory> Function() _resolveRoot;
  Future<Directory>? _root;
  Directory? _resolved;

  /// Resolved once; afterwards answered with a fresh completed future (cheap,
  /// and bound to the caller's zone).
  Future<Directory> get root {
    final resolved = _resolved;
    if (resolved != null) return Future.value(resolved);
    return _root ??= _resolveRoot().then((d) => _resolved = d);
  }

  /// The root once [root] has completed (null before).
  Directory? get rootIfReady => _resolved;

  Future<Directory> reciterDir(Reciter reciter) async => Directory(p.join((await root).path, reciter.folder));

  Future<File> fileFor(Reciter reciter, AyahRef ayah) async =>
      File(p.join((await reciterDir(reciter)).path, EveryAyah.fileName(ayah)));

  Future<File> partFor(Reciter reciter, AyahRef ayah) async => File('${(await fileFor(reciter, ayah)).path}.part');

  Future<File> get indexFile async => File(p.join((await root).path, 'downloads.json'));

  /// The downloaded file of [ayah], or null.
  Future<File?> localFile(Reciter reciter, AyahRef ayah) async {
    final f = await fileFor(reciter, ayah);
    return f.existsSync() ? f : null;
  }

  /// Synchronous variant for building playlists once [root] is resolved.
  File? localFileSync(Reciter reciter, AyahRef ayah) {
    final r = _resolved;
    if (r == null) return null;
    final f = File(p.join(r.path, reciter.folder, EveryAyah.fileName(ayah)));
    return f.existsSync() ? f : null;
  }
}
