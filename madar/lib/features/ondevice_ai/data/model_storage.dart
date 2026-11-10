/// Where the optional weights live: the app's **private** files directory
/// (`<support dir>/ondevice_models/`), never the APK and never shared storage.
/// The real ports the downloader goes through; tests use a temporary folder.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../reading/data/download_ports.dart';
import 'model_download_manager.dart' show ModelFileSink;
import 'ondevice_probe_client.dart';
import '../../recitation/data/network_probe.dart';

/// Parts under `<root>/<id>/part-N`, the joined file at `<root>/<id>.bin`.
/// A part is written to a temporary name and renamed, so a crash never leaves
/// half a part that looks finished.
class DirectoryModelSink implements ModelFileSink {
  /// [rootDir] is resolved lazily (the app's files directory is an async
  /// lookup) and once per call, so a test can point it at a temporary folder.
  DirectoryModelSink(this.rootDir);

  final Future<Directory> Function() rootDir;

  /// Model ids contain «/» (`tarteel-ai/whisper-base-ar-quran`): keep one flat,
  /// safe folder name.
  static String safe(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<Directory> _dir(String id) async => Directory(p.join((await rootDir()).path, safe(id)));
  Future<File> _part(String id, int i) async => File(p.join((await _dir(id)).path, 'part-$i'));
  Future<File> _final(String id) async => File(p.join((await rootDir()).path, '${safe(id)}.bin'));

  @override
  Future<int?> partLength(String id, int index) async {
    final f = await _part(id, index);
    return await f.exists() ? await f.length() : null;
  }

  @override
  Future<void> writePart(String id, int index, Uint8List bytes) async {
    await (await _dir(id)).create(recursive: true);
    final target = await _part(id, index);
    final tmp = File('${target.path}.tmp');
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(target.path);
    } on FileSystemException catch (e) {
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      // ENOSPC
      if (e.osError?.errorCode == 28) throw const StorageFullException();
      rethrow;
    }
  }

  @override
  Stream<List<int>> readPart(String id, int index) async* {
    yield* (await _part(id, index)).openRead();
  }

  @override
  Future<void> deletePart(String id, int index) async {
    final f = await _part(id, index);
    if (await f.exists()) await f.delete();
  }

  @override
  Future<String> finalize(String id, int partCount) async {
    await (await rootDir()).create(recursive: true);
    final target = await _final(id);
    final tmp = File('${target.path}.tmp');
    final out = tmp.openWrite();
    try {
      for (var i = 0; i < partCount; i++) {
        await out.addStream((await _part(id, i)).openRead());
      }
      await out.flush();
    } finally {
      await out.close();
    }
    await tmp.rename(target.path);
    final dir = await _dir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
    return target.path;
  }

  @override
  Future<void> discard(String id) async {
    final dir = await _dir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
    final target = await _final(id);
    for (final f in [target, File('${target.path}.tmp')]) {
      if (await f.exists()) await f.delete();
    }
  }

  @override
  Future<bool> finalExists(String id) async => (await _final(id)).exists();
}

/// The saved progress, one small JSON file per model.
class FileDownloadStateStore implements DownloadStateStore {
  FileDownloadStateStore(this.rootDir);

  final Future<Directory> Function() rootDir;

  Future<File> _file(String id) async =>
      File(p.join((await rootDir()).path, '${DirectoryModelSink.safe(id)}.state.json'));

  @override
  Future<DownloadState?> load(String id) async {
    try {
      final f = await _file(id);
      if (!await f.exists()) return null;
      final json = jsonDecode(await f.readAsString());
      if (json is! Map) return null;
      return DownloadState.fromJson(json.cast<String, Object?>());
    } catch (_) {
      // A damaged note is a download that starts over, never a crash.
      return null;
    }
  }

  @override
  Future<void> save(DownloadState state) async {
    await (await rootDir()).create(recursive: true);
    final target = await _file(state.id);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(jsonEncode(state.toJson()), flush: true);
    await tmp.rename(target.path);
  }

  @override
  Future<void> delete(String id) async {
    final f = await _file(id);
    if (await f.exists()) await f.delete();
  }
}

/// Free space from the same probe call the capability check uses (the app's
/// files directory). A phone that did not answer is read as «no room».
class ProbeFreeSpace implements FreeSpaceProbe {
  ProbeFreeSpace(this._probe);

  final OnDeviceProbe _probe;

  @override
  Future<int> freeBytes() async => (await _probe.probe()).freeStorageBytes ?? 0;
}

/// Wi-Fi or not, from the recitation feature's interface heuristic (no
/// plugin, the safe side when unsure): anything that is not Wi-Fi reads as
/// «other», so a Wi-Fi-only download waits instead of using mobile data.
class WifiConnectivityProbe implements ConnectivityProbe {
  const WifiConnectivityProbe([this._network = const InterfaceNetworkProbe()]);

  final NetworkProbe _network;

  @override
  Future<NetworkKind> current() async => await _network.onWifi() ? NetworkKind.wifi : NetworkKind.other;
}
