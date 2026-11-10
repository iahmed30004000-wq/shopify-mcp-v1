import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../../core/quran/ayah.dart';
import '../domain/download_models.dart';
import '../domain/reciters.dart';
import '../domain/surah_ayah_counts.dart';
import 'download_transport.dart';
import 'local_files.dart';
import 'network_probe.dart';
import 'recitation_storage.dart';

/// Offline recitations: per surah (or the whole mushaf) per reciter.
///
/// * Only ever starts because the user asked ([download]); work left over
///   when the app closed comes back paused.
/// * Resumes interrupted files with HTTP range requests (`.part` files).
/// * At most [concurrency] files at a time, across all surahs, in the order
///   they were asked for.
/// * Wi-Fi only (when [wifiOnly] says so): checked before every file; off
///   Wi-Fi the pending surahs wait until the user resumes them.
/// * Files: `<root>/<folder>/<SSSAAA>.mp3`; the basmala a surah opens with
///   is stored once per reciter as `basmala.mp3` (al-Fatihah's first ayah).
/// * Index: `<root>/downloads.json` keeps what disk cannot tell (paused /
///   failed / waiting); counts and sizes are re-read from disk on [load].
class RecitationDownloads extends ChangeNotifier implements LocalRecitationFiles {
  RecitationDownloads({
    required this.storage,
    required this.transport,
    required this.network,
    required this.wifiOnly,
    this.concurrency = 3,
    this.maxRetries = 2,
    this.retryDelay = const Duration(seconds: 2),
    DateTime Function()? clock,
    this.progressInterval = const Duration(milliseconds: 200),
  }) : _clock = clock ?? DateTime.now;

  final RecitationStorage storage;
  final DownloadTransport transport;
  final NetworkProbe network;
  final bool Function() wifiOnly;
  final int concurrency;
  final int maxRetries;
  final Duration retryDelay;
  final Duration progressInterval;
  final DateTime Function() _clock;

  static const basmalaFileName = 'basmala.mp3';
  static const _indexVersion = 1;

  final Map<String, Map<int, SurahDownload>> _index = {};
  final Map<String, int> _sharedBytes = {};
  final List<_Job> _jobs = [];
  final Set<_Task> _tasks = {};
  Future<void>? _loading;
  Future<void> _writing = Future.value();
  DateTime? _lastProgress;
  Completer<void>? _idle;
  bool _disposed = false;

  // ---------------------------------------------------------------- queries

  bool get loaded => _loading != null;

  /// [surah] of [reciterId] (status none when nothing is known).
  SurahDownload statusOf(String reciterId, int surah) =>
      _index[reciterId]?[surah] ??
      SurahDownload(reciterId: reciterId, surah: surah, filesTotal: downloadFileCount(surah));

  /// Every surah of [reciterId] that has files or pending work.
  List<SurahDownload> surahsOf(String reciterId) {
    final m = _index[reciterId];
    if (m == null) return const [];
    return [
      for (final s in m.keys.toList()..sort())
        if (m[s]!.status != DownloadStatus.none) m[s]!,
    ];
  }

  ReciterDownloads summaryOf(String reciterId) {
    var complete = 0, bytes = _sharedBytes[reciterId] ?? 0, active = 0, paused = 0;
    for (final d in _index[reciterId]?.values ?? const <SurahDownload>[]) {
      bytes += d.bytes;
      if (d.isComplete) complete++;
      if (d.status.pending) active++;
      if (d.status.resumable) paused++;
    }
    return ReciterDownloads(
      reciterId: reciterId,
      completeSurahs: complete,
      bytes: bytes,
      active: active,
      paused: paused,
    );
  }

  /// Reciters with anything on disk or pending.
  List<String> get reciterIds => [
    for (final id in {..._index.keys, ..._sharedBytes.keys})
      if (!summaryOf(id).isEmpty) id,
  ];

  /// Bytes used by all downloads.
  int get totalBytes => reciterIds.fold(0, (sum, id) => sum + summaryOf(id).bytes);

  /// Any file transfer in flight.
  bool get busy => _tasks.isNotEmpty;

  /// Completes when no file is being transferred (tests, shutdown).
  Future<void> whenIdle() {
    if (_tasks.isEmpty && !_jobs.any((j) => j.canStart)) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  @override
  Future<void> prepare() => load();

  /// The downloaded file of [ayah] (or of the reciter's basmala), if any –
  /// for playlist building.
  @override
  File? localFile(Reciter reciter, AyahRef ayah, {bool basmala = false}) {
    final root = storage.rootIfReady;
    if (root == null) return null;
    final dir = p.join(root.path, reciter.folder);
    if (basmala) {
      final shared = File(p.join(dir, basmalaFileName));
      if (shared.existsSync()) return shared;
    }
    final f = File(p.join(dir, EveryAyah.fileName(basmala ? EveryAyah.basmala : ayah)));
    return f.existsSync() ? f : null;
  }

  // ------------------------------------------------------------------ load

  /// Reads the index and re-counts files on disk (idempotent; cheap once
  /// done).
  Future<void> load() {
    if (_loadDone) return Future.value();
    return _loading ??= _load().whenComplete(() => _loadDone = true);
  }

  bool _loadDone = false;

  Future<void> _load() async {
    final root = await storage.root;
    Map<String, Object?> saved = const {};
    try {
      final f = await storage.indexFile;
      if (f.existsSync()) {
        final json = jsonDecode(await f.readAsString());
        if (json is Map && json['reciters'] is Map) saved = (json['reciters'] as Map).cast<String, Object?>();
      }
    } catch (_) {
      // A damaged index only loses paused / failed marks; disk is the truth.
    }
    for (final reciter in Reciters.all) {
      final dir = Directory(p.join(root.path, reciter.folder));
      final persisted = saved[reciter.id];
      if (!dir.existsSync() && persisted == null) continue;
      await _rescan(reciter, persisted is Map ? persisted.cast<String, Object?>() : const {});
    }
    _notify();
  }

  Future<void> _rescan(Reciter reciter, Map<String, Object?> persisted) async {
    final root = await storage.root;
    final dir = Directory(p.join(root.path, reciter.folder));
    final done = <int, int>{}, bytes = <int, int>{};
    var shared = 0;
    var hasBasmala = false;
    if (dir.existsSync()) {
      for (final e in dir.listSync()) {
        if (e is! File) continue;
        final name = p.basename(e.path);
        final size = e.lengthSync();
        if (name == basmalaFileName || name == '$basmalaFileName.part') {
          shared += size;
          if (name == basmalaFileName) hasBasmala = true;
          continue;
        }
        final m = _fileName.firstMatch(name);
        if (m == null) continue;
        final surah = int.parse(m.group(1)!);
        if (surah < 1 || surah > 114) continue;
        bytes[surah] = (bytes[surah] ?? 0) + size;
        if (m.group(3) == null) {
          done[surah] = (done[surah] ?? 0) + 1;
          if (surah == 1 && m.group(2) == '001') hasBasmala = true;
        }
      }
    }
    _sharedBytes[reciter.id] = shared;
    final map = _index.putIfAbsent(reciter.id, () => {});
    final surahs = {...done.keys, ...bytes.keys, ...persisted.keys.map(int.tryParse).whereType<int>()};
    for (final s in surahs) {
      if (s < 1 || s > 114) continue;
      final saved = SurahDownload.fromJson(reciter.id, s, persisted['$s']);
      final total = downloadFileCount(s);
      final files = (done[s] ?? 0) + (EveryAyah.surahNeedsBasmala(s) && hasBasmala ? 1 : 0);
      final ayatDone = done[s] ?? 0;
      final DownloadStatus status;
      if (ayatDone >= SurahMath.ayahCount(s) && files >= total) {
        status = DownloadStatus.complete;
      } else if (saved != null && saved.status.resumable) {
        // What the user asked for and has not finished stays resumable.
        status = saved.status;
      } else {
        status = (bytes[s] ?? 0) > 0 ? DownloadStatus.paused : DownloadStatus.none;
      }
      map[s] = SurahDownload(
        reciterId: reciter.id,
        surah: s,
        status: status,
        filesDone: ayatDone == 0 ? 0 : files,
        filesTotal: total,
        bytes: bytes[s] ?? 0,
        error: status == DownloadStatus.failed ? saved?.error : null,
      );
    }
  }

  static final _fileName = RegExp(r'^(\d{3})(\d{3})\.mp3(\.part)?$');

  // --------------------------------------------------------------- actions

  /// Downloads [surahs] of [reciter] (skipping complete ones and ones
  /// already pending). The user's explicit action.
  Future<void> download(Reciter reciter, Iterable<int> surahs) async {
    await load();
    for (final s in surahs) {
      if (s < 1 || s > 114) continue;
      final current = statusOf(reciter.id, s);
      if (current.isComplete || current.status.pending) continue;
      await _enqueue(reciter, s);
    }
    _notify();
    _persist();
    _pump();
  }

  /// The whole mushaf of [reciter].
  Future<void> downloadMushaf(Reciter reciter) => download(reciter, [for (var s = 1; s <= 114; s++) s]);

  /// Resumes a paused, waiting or failed surah.
  Future<void> resume(Reciter reciter, int surah) => download(reciter, [surah]);

  /// Resumes everything paused of [reciter] (all reciters when null).
  Future<void> resumeAll({Reciter? reciter}) async {
    await load();
    for (final r in reciter == null ? Reciters.all : [reciter]) {
      final paused = [
        for (final d in _index[r.id]?.values ?? const <SurahDownload>[])
          if (d.status.resumable) d.surah,
      ]..sort();
      if (paused.isNotEmpty) await download(r, paused);
    }
  }

  /// Pauses [surah]; its partial files stay for [resume].
  Future<void> pause(Reciter reciter, int surah) async {
    final job = _jobFor(reciter.id, surah);
    if (job == null) return;
    _stopJob(job, _Stop.pause);
    _set(reciter.id, surah, (d) => d.copyWith(status: DownloadStatus.paused, error: () => null));
    _notify();
    _persist();
  }

  /// Pauses everything in flight.
  Future<void> pauseAll() async {
    for (final job in List.of(_jobs)) {
      _stopJob(job, _Stop.pause);
      _set(job.reciter.id, job.surah, (d) => d.copyWith(status: DownloadStatus.paused));
    }
    _notify();
    _persist();
  }

  /// Stops [surah] and removes what it downloaded (as if never started).
  Future<void> cancel(Reciter reciter, int surah) async {
    final job = _jobFor(reciter.id, surah);
    if (job != null) _stopJob(job, _Stop.cancel);
    await delete(reciter, surah: surah);
  }

  /// Deletes [surah]'s files of [reciter] (all of them when null).
  Future<void> delete(Reciter reciter, {int? surah}) async {
    await load();
    final dir = await storage.reciterDir(reciter);
    if (surah == null) {
      for (final job in _jobs.where((j) => j.reciter == reciter).toList()) {
        _stopJob(job, _Stop.cancel);
      }
      await _drain(reciter);
      if (dir.existsSync()) await dir.delete(recursive: true);
      _index.remove(reciter.id);
      _sharedBytes.remove(reciter.id);
    } else {
      final job = _jobFor(reciter.id, surah);
      if (job != null) _stopJob(job, _Stop.cancel);
      await _drain(reciter, surah: surah);
      if (dir.existsSync()) {
        final prefix = surah.toString().padLeft(3, '0');
        for (final e in dir.listSync()) {
          if (e is File && p.basename(e.path).startsWith(prefix)) await e.delete();
        }
      }
      _index[reciter.id]?.remove(surah);
      // The shared basmala goes with the last surah that needs it.
      final others = _index[reciter.id]?.values.any((d) => d.hasFiles && EveryAyah.surahNeedsBasmala(d.surah));
      final basmala = File(p.join(dir.path, basmalaFileName));
      if (others != true && basmala.existsSync()) {
        await basmala.delete();
        _sharedBytes[reciter.id] = 0;
      }
    }
    _notify();
    _persist();
  }

  /// Waits until [reciter]'s cancelled tasks have let go of their files.
  Future<void> _drain(Reciter reciter, {int? surah}) async {
    final pending = [
      for (final t in _tasks)
        if (t.job.reciter == reciter && (surah == null || t.job.surah == surah)) t.done.future,
    ];
    await Future.wait(pending);
  }

  // --------------------------------------------------------------- engine

  Future<void> _enqueue(Reciter reciter, int surah) async {
    final dir = await storage.reciterDir(reciter);
    final missing = <_File>[];
    for (var a = 1; a <= SurahMath.ayahCount(surah); a++) {
      final ayah = AyahRef(surah, a);
      if (!File(p.join(dir.path, EveryAyah.fileName(ayah))).existsSync()) missing.add(_File.ayah(ayah));
    }
    if (EveryAyah.surahNeedsBasmala(surah) && localFile(reciter, AyahRef(surah, 1), basmala: true) == null) {
      missing.add(const _File.basmala());
    }
    final total = downloadFileCount(surah);
    if (missing.isEmpty) {
      _set(reciter.id, surah, (d) => d.copyWith(status: DownloadStatus.complete, filesDone: total, filesTotal: total));
      return;
    }
    _jobs.add(_Job(reciter, surah, missing));
    _set(
      reciter.id,
      surah,
      (d) => d.copyWith(
        status: DownloadStatus.queued,
        filesDone: total - missing.length,
        filesTotal: total,
        error: () => null,
      ),
    );
  }

  _Job? _jobFor(String reciterId, int surah) {
    for (final j in _jobs) {
      if (j.reciter.id == reciterId && j.surah == surah) return j;
    }
    return null;
  }

  void _stopJob(_Job job, _Stop reason) {
    job.stop = reason;
    _jobs.remove(job);
    for (final t in _tasks.where((t) => t.job == job).toList()) {
      t.cancel(reason);
    }
  }

  void _pump() {
    if (_disposed) return;
    while (_tasks.length < concurrency) {
      _Job? job;
      for (final j in _jobs) {
        if (j.canStart) {
          job = j;
          break;
        }
      }
      if (job == null) break;
      final file = job.pending.removeAt(0);
      final task = _Task(job, file);
      _tasks.add(task);
      if (statusOf(job.reciter.id, job.surah).status != DownloadStatus.downloading) {
        _set(job.reciter.id, job.surah, (d) => d.copyWith(status: DownloadStatus.downloading));
        _notify();
      }
      unawaited(_run(task));
    }
    if (_tasks.isEmpty && !_jobs.any((j) => j.canStart)) {
      _idle?.complete();
      _idle = null;
    }
  }

  Future<void> _run(_Task task) async {
    final job = task.job;
    try {
      if (wifiOnly() && !await network.onWifi()) throw const _WifiRequired();
      if (task.stopped != null) throw _Stopped(task.stopped!);
      await _fetchWithRetries(task);
      _tasks.remove(task);
      final finished = job.pending.isEmpty && !_tasks.any((t) => t.job == job);
      _set(
        job.reciter.id,
        job.surah,
        (d) => d.copyWith(filesDone: d.filesDone + 1, status: finished ? DownloadStatus.complete : d.status),
      );
      if (finished) {
        _jobs.remove(job);
        _persist();
      }
      _notify(progress: !finished);
    } on _Stopped catch (e) {
      _tasks.remove(task);
      if (e.reason == _Stop.cancel) {
        final part = await _partOf(task);
        if (part.existsSync()) {
          _addBytes(task, -part.lengthSync());
          await _deleteQuietly(part);
        }
      }
      _notify();
    } on _WifiRequired {
      _tasks.remove(task);
      for (final j in {job, ..._jobs}) {
        _stopJob(j, _Stop.pause);
        _set(j.reciter.id, j.surah, (d) => d.copyWith(status: DownloadStatus.waitingForWifi));
      }
      _notify();
      _persist();
    } on _Failed catch (e) {
      _tasks.remove(task);
      if (job.stop == null) {
        _stopJob(job, _Stop.pause);
        _set(job.reciter.id, job.surah, (d) => d.copyWith(status: DownloadStatus.failed, error: () => e.error));
        _persist();
      }
      _notify();
    } finally {
      task.done.complete();
      _pump();
    }
  }

  Future<File> _partOf(_Task task) async {
    final dir = await storage.reciterDir(task.job.reciter);
    return File(p.join(dir.path, '${task.file.fileName}.part'));
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  /// Keeps the shown sizes equal to the bytes on disk: a surah's own files,
  /// or the reciter's shared basmala.
  void _addBytes(_Task task, int delta) {
    if (delta == 0) return;
    final id = task.job.reciter.id;
    if (task.file.isBasmala) {
      _sharedBytes[id] = ((_sharedBytes[id] ?? 0) + delta).clamp(0, 1 << 52);
    } else {
      _set(id, task.job.surah, (d) => d.copyWith(bytes: (d.bytes + delta).clamp(0, 1 << 52)));
    }
  }

  Future<void> _fetchWithRetries(_Task task) async {
    var attempt = 0;
    while (true) {
      try {
        return await _fetch(task);
      } on _Stopped {
        rethrow;
      } on _Failed catch (e) {
        if (e.error != DownloadError.network || attempt >= maxRetries) rethrow;
      } on IOException {
        if (attempt >= maxRetries) throw const _Failed(DownloadError.network);
      } on TimeoutException {
        if (attempt >= maxRetries) throw const _Failed(DownloadError.network);
      }
      attempt++;
      await Future<void>.delayed(retryDelay * attempt);
      if (task.stopped != null) throw _Stopped(task.stopped!);
    }
  }

  /// Fetches one file into its `.part` (resuming from what is there) and
  /// renames it into place.
  Future<void> _fetch(_Task task) async {
    final reciter = task.job.reciter;
    final dir = await storage.reciterDir(reciter);
    if (!dir.existsSync()) await dir.create(recursive: true);
    final target = File(p.join(dir.path, task.file.fileName));
    final part = File('${target.path}.part');
    var have = part.existsSync() ? part.lengthSync() : 0;
    final response = await transport.get(EveryAyah.urlFor(reciter, task.file.source), from: have);
    if (task.stopped != null) {
      response.abort();
      throw _Stopped(task.stopped!);
    }
    task.response = response;
    final code = response.statusCode;
    if (code == HttpStatus.requestedRangeNotSatisfiable) {
      // The part is stale (the file changed, or it is already whole but was
      // never renamed): start over.
      response.abort();
      _addBytes(task, -have);
      await _deleteQuietly(part);
      throw const _Failed(DownloadError.network);
    }
    if (code != HttpStatus.ok && code != HttpStatus.partialContent) {
      response.abort();
      throw _Failed(code >= 500 || code == HttpStatus.tooManyRequests ? DownloadError.network : DownloadError.notFound);
    }
    if (!response.isPartial && have > 0) {
      // The server ignored the range: the part is rewritten from zero.
      _addBytes(task, -have);
      have = 0;
    }
    final expected = response.totalLength ?? (response.contentLength == null ? null : have + response.contentLength!);
    final sink = part.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
    var received = have;
    try {
      final done = Completer<void>();
      task.onCancel = () {
        if (!done.isCompleted) done.completeError(_Stopped(task.stopped!));
      };
      task.subscription = response.body.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          _addBytes(task, chunk.length);
          _notify(progress: true);
        },
        onError: (Object e, StackTrace s) {
          if (!done.isCompleted) done.completeError(e, s);
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      await done.future;
      await sink.flush();
    } catch (e) {
      await task.subscription?.cancel();
      response.abort();
      await sink.close();
      // The part stays on disk for the next attempt / resume.
      if (e is _Stopped || e is IOException || e is TimeoutException) rethrow;
      throw const _Failed(DownloadError.network);
    }
    await sink.close();
    if (expected != null && received != expected) {
      if (received > expected) {
        _addBytes(task, -received);
        await _deleteQuietly(part);
      }
      throw const _Failed(DownloadError.network);
    }
    try {
      await part.rename(target.path);
    } on FileSystemException {
      throw const _Failed(DownloadError.storage);
    }
  }

  // --------------------------------------------------------------- helpers

  void _set(String reciterId, int surah, SurahDownload Function(SurahDownload) change) {
    final map = _index.putIfAbsent(reciterId, () => {});
    map[surah] = change(map[surah] ?? statusOf(reciterId, surah));
  }

  void _notify({bool progress = false}) {
    if (_disposed) return;
    if (progress) {
      final now = _clock();
      final last = _lastProgress;
      if (last != null && now.difference(last) < progressInterval) return;
      _lastProgress = now;
    }
    notifyListeners();
  }

  void _persist() {
    if (_disposed) return;
    _writing = _writing.then((_) => _write()).catchError((Object _) {});
  }

  Future<void> _write() async {
    final json = {
      'v': _indexVersion,
      'reciters': {
        for (final e in _index.entries)
          if (e.value.values.any((d) => d.status != DownloadStatus.none))
            e.key: {
              for (final d in e.value.values)
                if (d.status != DownloadStatus.none) '${d.surah}': d.toJson(),
            },
      },
    };
    final f = await storage.indexFile;
    if (!f.parent.existsSync()) await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(f.path);
  }

  /// Completes once pending index writes are on disk (tests).
  Future<void> flush() => _writing;

  @override
  void dispose() {
    for (final job in List.of(_jobs)) {
      _stopJob(job, _Stop.pause);
    }
    _disposed = true;
    _idle?.complete();
    super.dispose();
  }
}

enum _Stop { pause, cancel }

class _Stopped implements Exception {
  const _Stopped(this.reason);
  final _Stop reason;
}

class _WifiRequired implements Exception {
  const _WifiRequired();
}

class _Failed implements Exception {
  const _Failed(this.error);
  final DownloadError error;
}

/// A file to fetch: an ayah, or the reciter's basmala.
@immutable
class _File {
  const _File.ayah(AyahRef this.ayah);
  const _File.basmala() : ayah = null;

  final AyahRef? ayah;

  bool get isBasmala => ayah == null;
  AyahRef get source => ayah ?? EveryAyah.basmala;
  String get fileName => isBasmala ? RecitationDownloads.basmalaFileName : EveryAyah.fileName(ayah!);
}

class _Job {
  _Job(this.reciter, this.surah, this.pending);

  final Reciter reciter;
  final int surah;
  final List<_File> pending;
  _Stop? stop;

  bool get canStart => stop == null && pending.isNotEmpty;
}

class _Task {
  _Task(this.job, this.file);

  final _Job job;
  final _File file;
  final Completer<void> done = Completer<void>();
  DownloadResponse? response;
  StreamSubscription<List<int>>? subscription;
  void Function()? onCancel;
  _Stop? stopped;

  void cancel(_Stop reason) {
    stopped ??= reason;
    unawaited(subscription?.cancel());
    response?.abort();
    onCancel?.call();
  }
}
