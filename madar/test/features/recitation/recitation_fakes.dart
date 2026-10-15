// Fakes for the recitation feature: a scripted audio engine, audio focus,
// media session, HTTP transport, listening logger and a small QuranCatalog.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_catalog.dart';
import 'package:madar/features/recitation/data/download_transport.dart';
import 'package:madar/features/recitation/data/media_session.dart';
import 'package:madar/features/recitation/data/recitation_engine.dart';
import 'package:madar/features/recitation/data/recitation_repository.dart';
import 'package:madar/features/recitation/domain/listening_tracker.dart';
import 'package:madar/features/recitation/domain/surah_ayah_counts.dart';

/// A playlist player driven by the test: [finishCurrent] ends the current
/// entry (advancing or completing), [failAt] reports an error.
class FakeEngine implements RecitationEngine {
  final _index = StreamController<int?>.broadcast();
  final _status = StreamController<EngineStatus>.broadcast();
  final _failures = StreamController<EngineFailure>.broadcast();
  final _position = StreamController<Duration>.broadcast();

  List<EngineSource> sources = [];
  int? current;
  bool playing = false;
  EngineProcessing processing = EngineProcessing.idle;
  double speed = 1;
  Duration pos = Duration.zero;
  final List<String> calls = [];
  bool disposed = false;

  /// Makes the next [setSources] throw.
  Object? failNextLoad;

  @override
  Stream<int?> get index => _index.stream;
  @override
  Stream<EngineStatus> get status => _status.stream;
  @override
  Stream<EngineFailure> get failures => _failures.stream;
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Duration get currentPosition => pos;
  @override
  Duration? get duration => const Duration(seconds: 8);
  @override
  int? get currentIndex => current;

  void _emitStatus() => _status.add(EngineStatus(playing: playing, processing: processing));

  @override
  Future<void> setSources(
    List<EngineSource> s, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
  }) async {
    calls.add('set:${s.length}@$initialIndex+${initialPosition.inMilliseconds}');
    final failure = failNextLoad;
    if (failure != null) {
      failNextLoad = null;
      throw failure;
    }
    sources = List.of(s);
    current = initialIndex;
    pos = initialPosition;
    processing = EngineProcessing.ready;
    _index.add(initialIndex);
    _emitStatus();
  }

  @override
  Future<void> addSources(List<EngineSource> s) async {
    calls.add('add:${s.length}');
    sources.addAll(s);
  }

  @override
  Future<void> play() async {
    calls.add('play');
    playing = true;
    _emitStatus();
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing = false;
    _emitStatus();
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    playing = false;
    processing = EngineProcessing.idle;
    _emitStatus();
  }

  @override
  Future<void> seek(Duration position, {int? index}) async {
    calls.add('seek:${index ?? '-'}');
    pos = position;
    if (index != null && index != current) {
      current = index;
      _index.add(index);
    }
  }

  @override
  Future<void> setSpeed(double s) async {
    calls.add('speed:$s');
    speed = s;
  }

  @override
  Future<void> dispose() async => disposed = true;

  /// The current entry ends: the next one starts, or the playlist completes.
  void finishCurrent() {
    final c = current ?? 0;
    if (c + 1 < sources.length) {
      current = c + 1;
      pos = Duration.zero;
      _index.add(current);
    } else {
      processing = EngineProcessing.completed;
      _emitStatus();
    }
  }

  void buffering(bool on) {
    processing = on ? EngineProcessing.buffering : EngineProcessing.ready;
    _emitStatus();
  }

  void failAt(int index, String message) => _failures.add(EngineFailure(index: index, message: message));
}

class FakeFocus implements RecitationAudioFocus {
  final interruptionsCtrl = StreamController<({bool begin, bool transient})>.broadcast();
  final noisyCtrl = StreamController<void>.broadcast();
  int configured = 0;

  @override
  Future<void> configure() async => configured++;
  @override
  Stream<({bool begin, bool transient})> get interruptions => interruptionsCtrl.stream;
  @override
  Stream<void> get becomingNoisy => noisyCtrl.stream;
}

class FakeMediaSession implements RecitationMediaSession {
  RecitationMediaControls? controls;
  final List<RecitationMediaInfo?> updates = [];

  @override
  void attach(RecitationMediaControls c) => controls = c;

  @override
  void update(RecitationMediaInfo? info, RecitationMediaLabels labels) => updates.add(info);
}

class FakeBackground implements RecitationBackground {
  FakeBackground([this.session]);
  final RecitationMediaSession? session;
  int starts = 0;

  @override
  Future<RecitationMediaSession?> start() async {
    starts++;
    return session;
  }
}

class RecordingLogger implements ListeningLogger {
  final List<ListeningSummary> logged = [];
  @override
  Future<void> log(ListeningSummary summary) async => logged.add(summary);
}

/// Serves deterministic bytes per URL; honours ranges; can fail mid-body,
/// ignore ranges, answer 404, or hold a response until released.
class FakeTransport implements DownloadTransport {
  FakeTransport({this.fileSize = 1000, this.chunk = 250});

  final int fileSize;
  final int chunk;
  final List<({Uri uri, int from})> requests = [];

  /// URLs answered 404.
  final Set<String> missing = {};

  /// URL → how many requests of it fail after half the body.
  final Map<String, int> cutOnce = {};

  /// Answer every request with the full file (200) ignoring ranges.
  bool ignoreRanges = false;

  /// While non-null, bodies wait on this before sending anything.
  Completer<void>? gate;
  int maxConcurrent = 0;
  int _open = 0;

  static Uint8List bytesFor(Uri uri, int size) {
    final seed = uri.path.hashCode;
    return Uint8List.fromList(List.generate(size, (i) => (seed + i * 31) & 0xff));
  }

  @override
  Future<DownloadResponse> get(Uri uri, {int from = 0}) async {
    requests.add((uri: uri, from: from));
    if (missing.contains(uri.toString())) {
      return DownloadResponse(statusCode: 404, body: const Stream.empty(), abort: () {});
    }
    final all = bytesFor(uri, fileSize);
    final partial = from > 0 && !ignoreRanges;
    final start = partial ? from : 0;
    final cut = (cutOnce[uri.toString()] ?? 0) > 0;
    if (cut) cutOnce[uri.toString()] = cutOnce[uri.toString()]! - 1;
    var aborted = false;
    final controller = StreamController<List<int>>();
    Future<void> pump() async {
      _open++;
      if (_open > maxConcurrent) maxConcurrent = _open;
      try {
        final g = gate;
        if (g != null) await g.future;
        final end = cut ? start + (fileSize - start) ~/ 2 : fileSize;
        for (var i = start; i < end && !aborted; i += chunk) {
          await Future<void>.delayed(Duration.zero);
          if (aborted) break;
          controller.add(all.sublist(i, i + chunk > end ? end : i + chunk));
        }
        if (!aborted) {
          if (cut) {
            controller.addError(const SocketException('connection reset'));
          }
        }
      } finally {
        _open--;
        if (!controller.isClosed) await controller.close();
      }
    }

    controller.onListen = () => unawaited(pump());
    return DownloadResponse(
      statusCode: partial ? 206 : 200,
      contentLength: fileSize - start,
      totalLength: partial ? fileSize : null,
      body: controller.stream,
      abort: () => aborted = true,
    );
  }

  @override
  void close() {}
}

/// A [QuranCatalog] with the real ayah counts, surah names (Tanzil
/// metadata, read from assets/quran/quran-meta.json when present) and a few
/// ayah texts.
class FakeQuranCatalog implements QuranCatalog {
  FakeQuranCatalog() {
    final meta = File('assets/quran/quran-meta.json');
    if (meta.existsSync()) {
      final json = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
      final suras = json['suras'] as List<dynamic>;
      for (var i = 0; i < suras.length; i++) {
        final row = suras[i] as List<dynamic>;
        _ar[i + 1] = row[3] as String;
        _en[i + 1] = row[4] as String;
      }
    }
  }

  final Map<int, String> _ar = {1: 'الفاتحة', 2: 'البقرة', 67: 'الملك', 112: 'الإخلاص'};
  final Map<int, String> _en = {1: 'Al-Fatihah', 2: 'Al-Baqarah', 67: 'Al-Mulk', 112: 'Al-Ikhlas'};

  // Tanzil Uthmani (CC BY 3.0), as in assets/quran/quran-uthmani.txt.
  static const _texts = {
    '1:1': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
    '2:255': 'ٱللَّهُ لَآ إِلَـٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ ۚ لَا تَأْخُذُهُۥ سِنَةٌ وَلَا نَوْمٌ ۚ لَّهُۥ مَا فِى ٱلسَّمَـٰوَٰتِ وَمَا فِى ٱلْأَرْضِ ۗ مَن ذَا ٱلَّذِى يَشْفَعُ عِندَهُۥٓ إِلَّا بِإِذْنِهِۦ ۚ يَعْلَمُ مَا بَيْنَ أَيْدِيهِمْ وَمَا خَلْفَهُمْ ۖ وَلَا يُحِيطُونَ بِشَىْءٍ مِّنْ عِلْمِهِۦٓ إِلَّا بِمَا شَآءَ ۚ وَسِعَ كُرْسِيُّهُ ٱلسَّمَـٰوَٰتِ وَٱلْأَرْضَ ۖ وَلَا يَـُٔودُهُۥ حِفْظُهُمَا ۚ وَهُوَ ٱلْعَلِىُّ ٱلْعَظِيمُ',
    '67:1': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ تَبَـٰرَكَ ٱلَّذِى بِيَدِهِ ٱلْمُلْكُ وَهُوَ عَلَىٰ كُلِّ شَىْءٍ قَدِيرٌ',
    '112:1': 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ قُلْ هُوَ ٱللَّهُ أَحَدٌ',
  };

  @override
  int get surahCount => 114;
  @override
  int ayahCount(int surah) => SurahMath.ayahCount(surah);
  @override
  String surahName(int surah, {required bool arabic}) => (arabic ? _ar : _en)[surah]!;
  @override
  bool isMakki(int surah) => surah != 2;
  @override
  int pageOf(AyahRef ayah) => 1;
  @override
  int juzOf(AyahRef ayah) => 1;
  @override
  int hizbOf(AyahRef ayah) => 1;
  @override
  AyahRef pageStart(int page) => const AyahRef(1, 1);
  @override
  AyahRef juzStart(int juz) => const AyahRef(1, 1);
  @override
  AyahRef hizbStart(int hizb) => const AyahRef(1, 1);
  @override
  AyahRef? next(AyahRef ayah) => SurahMath.next(ayah);
  @override
  AyahRef? previous(AyahRef ayah) => SurahMath.previous(ayah);
  @override
  int countInRange(AyahRange range) => SurahMath.countIn(range);

  /// The full Tanzil Uthmani text when the reader's asset is present.
  static final Map<String, String> _all = () {
    final f = File('assets/quran/quran-uthmani.txt');
    if (!f.existsSync()) return <String, String>{};
    return {
      for (final line in f.readAsLinesSync())
        if (line.split('|') case [final s, final a, final text]) '$s:$a': text,
    };
  }();

  @override
  Future<String> ayahText(AyahRef ayah) async => _texts['$ayah'] ?? _all['$ayah'] ?? '';
  @override
  Future<void> ensureLoaded() async {}
}

/// Lets queued microtasks and zero-delay timers run.
Future<void> settle([int rounds = 20]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
