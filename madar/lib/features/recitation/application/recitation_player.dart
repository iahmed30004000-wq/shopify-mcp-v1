import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_audio.dart';
import '../../../core/sound/prayer_mute.dart';
import '../data/local_files.dart';
import '../data/media_session.dart';
import '../data/recitation_engine.dart';
import '../data/recitation_repository.dart';
import '../domain/listening_tracker.dart';
import '../domain/recitation_queue.dart';
import '../domain/recitation_settings.dart';
import '../domain/recitation_state.dart';
import '../domain/reciters.dart';

/// Texts of the media notification (localised by the provider).
class RecitationMediaTexts {
  const RecitationMediaTexts({
    required this.title,
    required this.reciterName,
    required this.album,
    required this.labels,
  });

  /// `سورة البقرة · الآية ٢٥٥` for an entry.
  final String Function(QueueItem item) title;
  final String Function(Reciter reciter) reciterName;
  final String album;
  final RecitationMediaLabels labels;

  static final fallback = RecitationMediaTexts(
    title: (i) => i.isBasmala ? 'Surah ${i.ayah.surah} · Basmala' : 'Surah ${i.ayah.surah} · ${i.ayah.ayah}',
    reciterName: (r) => r.nameEn,
    album: 'The Noble Quran',
    labels: RecitationMediaLabels.english,
  );
}

/// The recitation controller: per-ayah playlists with repeats, gaps and the
/// basmala, streaming or from downloads, background media session, sleep
/// timer, listening log – and the app's [QuranAudio].
///
/// Nothing touches the engine, audio focus, storage or network before the
/// first [play] (an explicit user action).
///
/// Adhan: when anything but recitation itself engages the prayer mute (the
/// adhan sounding, the adhan screen, prayer quiet), playback pauses and
/// stays paused until the user resumes it. While reciting, the player holds
/// its own prayer-mute lease so the ambient bed and game sounds stay silent.
class RecitationPlayer extends ChangeNotifier implements QuranAudio, RecitationMediaControls {
  RecitationPlayer({
    required this._engineFactory,
    required this._loadSettings,
    this._focus = const NoAudioFocus(),
    LocalRecitationFiles localFiles = const NoLocalRecitationFiles(),
    this._logger,
    this._background = const NoRecitationBackground(),
    this._texts,
    PrayerMuteController? prayerMute,
    DateTime Function()? clock,
    this.windowSize = 24,
    this.lookahead = 6,
    this.idleFlushAfter = const Duration(minutes: 3),
    this.minimumSession = const Duration(seconds: 15),
    this.checkpointEvery = const Duration(minutes: 20),
  }) : _local = localFiles,
       _mute = prayerMute,
       _clock = clock ?? DateTime.now,
       _tracker = ListeningTracker(minimum: minimumSession),
       _state = const RecitationState(reciter: Reciters.fallback) {
    _mute?.addListener(_onPrayerMute);
    _foreignLeases = _foreignLeaseCount();
  }

  final RecitationEngine Function() _engineFactory;
  final Future<RecitationSettings> Function() _loadSettings;
  final RecitationAudioFocus _focus;
  final LocalRecitationFiles _local;
  final ListeningLogger? _logger;
  final RecitationBackground _background;
  final RecitationMediaTexts Function()? _texts;
  final PrayerMuteController? _mute;
  final DateTime Function() _clock;
  final ListeningTracker _tracker;

  /// Entries handed to the engine at once (more are appended as it plays).
  final int windowSize;

  /// Append when fewer than this many entries remain in the engine.
  final int lookahead;

  /// A pause this long ends the listening session (it is logged).
  final Duration idleFlushAfter;
  final Duration minimumSession;

  /// A long session is logged in parts of this length, so listening is
  /// never lost if the process dies mid-way (the next ayah starts a new
  /// part).
  final Duration checkpointEvery;

  static const _muteReason = 'quran recitation';

  /// The short, recognisable sample every reciter is previewed with
  /// (al-Ikhlas, opened by the basmala).
  static const sampleRange = AyahRange(AyahRef(112, 1), AyahRef(112, 4));

  RecitationState _state;
  QuranPlayback _lastPlayback = QuranPlayback.idle;
  final _playback = StreamController<QuranPlayback>.broadcast();

  RecitationEngine? _engine;
  final List<StreamSubscription<Object?>> _subs = [];
  int _generation = 0;
  int _windowStart = 0;
  List<EngineSource> _window = [];
  bool _loadingWindow = false;
  Future<void>? _topUpFuture;
  bool _starting = false;
  bool _logging = true;

  RecitationMediaSession? _media;
  Future<void>? _mediaStart;
  RecitationMediaInfo? _lastMedia;

  PrayerMuteLease? _lease;
  int _foreignLeases = 0;
  bool _resumeAfterInterruption = false;

  Timer? _sleepTimer;
  Timer? _idleTimer;
  bool _disposed = false;

  // ------------------------------------------------------------------ state

  /// The full recitation state (UI).
  RecitationState get state => _state;

  @override
  QuranPlayback get value => _state.toPlayback();

  /// Emits the current value on listen, then every change of ayah,
  /// repetition, playing or loading.
  @override
  Stream<QuranPlayback> get playback => Stream<QuranPlayback>.multi((c) {
    c.add(value);
    final sub = _playback.stream.listen(c.add, onError: c.addError, onDone: c.close);
    c.onCancel = sub.cancel;
  });

  /// Position within the current entry (progress rings); empty when idle.
  Stream<Duration> get position => _engine?.position ?? const Stream.empty();
  Duration get currentPosition => _engine?.currentPosition ?? Duration.zero;
  Duration? get currentDuration => _engine?.duration;

  void _emit(RecitationState next) {
    if (_disposed || next == _state) return;
    _state = next;
    notifyListeners();
    final pb = next.toPlayback();
    if (pb != _lastPlayback) {
      _lastPlayback = pb;
      _playback.add(pb);
    }
    _pushMedia();
  }

  // ------------------------------------------------------------------ play

  /// [QuranAudio.play]. With no counts the user's repeat defaults from the
  /// recitation settings apply; given counts are taken as asked, a missing
  /// one being 1 (`repeatRange` ≤ 0 repeats until stopped).
  @override
  Future<void> play(AyahRange range, {int? repeatAyah, int? repeatRange}) {
    final defaults = repeatAyah == null && repeatRange == null;
    return playRange(
      range,
      repeatAyah: defaults ? null : (repeatAyah ?? 1),
      repeatRange: defaults ? null : (repeatRange ?? 1),
    );
  }

  /// Plays [range]; null repeat counts and [reciter] come from the settings.
  /// [startAt] starts inside the range. [log] false keeps it out of the
  /// listening log (previews).
  Future<void> playRange(
    AyahRange range, {
    int? repeatAyah,
    int? repeatRange,
    Reciter? reciter,
    AyahRef? startAt,
    bool log = true,
  }) async {
    final gen = ++_generation;
    _cancelIdleFlush();
    await _endSession();
    RecitationSettings settings;
    try {
      settings = await _loadSettings();
    } catch (_) {
      settings = const RecitationSettings();
    }
    if (gen != _generation || _disposed) return;
    final queue = RecitationQueue.build(
      range,
      repeatAyah: repeatAyah ?? settings.repeatAyah,
      repeatRange: repeatRange ?? settings.repeatRange,
      gap: settings.gap,
      basmala: settings.basmala,
    );
    final start = startAt == null ? 0 : (queue.indexOfAyah(startAt) ?? 0);
    _logging = log;
    _starting = true;
    _emit(
      RecitationState(
        queue: queue,
        index: start,
        item: queue.itemAt(start),
        reciter: reciter ?? settings.reciter,
        loading: true,
        speed: settings.speed,
        background: _state.background,
        sleep: _state.sleep,
      ),
    );
    unawaited(_ensureBackground());
    try {
      await _focus.configure();
    } catch (_) {}
    try {
      await _local.prepare();
    } catch (_) {}
    if (gen != _generation || _disposed) return;
    try {
      final engine = _ensureEngine();
      await engine.setSpeed(settings.speed);
      await _loadWindow(start, gen);
      if (gen != _generation) return;
      await engine.play();
    } catch (e) {
      if (gen == _generation) _fail(e);
    }
  }

  /// Previews [reciter] with [sampleRange] (not logged, repeats off).
  Future<void> playSample(Reciter reciter) =>
      playRange(sampleRange, repeatAyah: 1, repeatRange: 1, reciter: reciter, log: false);

  /// Whether [reciter]'s preview is what is playing.
  bool isSampleOf(Reciter reciter) => _state.active && _state.reciter == reciter && _state.range == sampleRange;

  @override
  Future<void> pause() => _pauseFor(RecitationPause.user);

  @override
  Future<void> resume() async {
    if (!_state.active || _disposed) return;
    final gen = _generation;
    _resumeAfterInterruption = false;
    final failed = _state.error != null || _engine == null;
    _emit(_state.copyWith(pausedBy: () => null, error: () => null, loading: failed ? true : null));
    try {
      if (failed) {
        _starting = true;
        _ensureEngine();
        await _loadWindow(_state.index, gen);
        if (gen != _generation) return;
      }
      await _engine!.play();
    } catch (e) {
      if (gen == _generation) _fail(e);
    }
  }

  /// Play / pause.
  Future<void> toggle() => _state.playing || (_state.loading && _state.pausedBy == null) ? pause() : resume();

  @override
  Future<void> stop() async {
    _generation++;
    _starting = false;
    _cancelSleepTimer();
    _cancelIdleFlush();
    _releaseMute();
    _window = [];
    // Idle first, so the engine's own "stopped" events find nothing to show.
    _emit(_state.cleared());
    _lastMedia = null;
    _media?.update(null, _mediaTexts.labels);
    final engine = _engine;
    if (engine != null) {
      try {
        await engine.stop();
      } catch (_) {}
    }
    await _endSession();
  }

  /// Next ayah (skipping the current ayah's remaining repetitions); stops
  /// after the last one.
  @override
  Future<void> next() async {
    final q = _state.queue;
    if (q == null) return;
    final target = q.nextAyahStart(_state.index);
    if (target == null) return stop();
    await _seekTo(target);
  }

  /// Back to the start of this ayah; to the previous ayah when already at
  /// its start (within 3 s).
  @override
  Future<void> previous() async {
    final q = _state.queue;
    if (q == null) return;
    final start = q.groupStartOf(_state.index);
    final atStart = _state.index == start && currentPosition < const Duration(seconds: 3);
    await _seekTo(atStart ? (q.previousAyahStart(_state.index) ?? start) : start);
  }

  /// Jumps to [ayah] (within the range, same pass).
  Future<void> seekToAyah(AyahRef ayah) async {
    final q = _state.queue;
    if (q == null) return;
    final index = q.indexOfAyah(ayah, rangePass: _state.rangePass < 1 ? 1 : _state.rangePass);
    if (index != null) await _seekTo(index);
  }

  @override
  Future<void> seekWithin(Duration position) async {
    try {
      await _engine?.seek(position);
    } catch (_) {}
  }

  /// Changes the repetitions (or gap / basmala) of what is playing, keeping
  /// the place.
  Future<void> setRepeats({int? repeatAyah, int? repeatRange, Duration? gap, bool? basmala}) async {
    final q = _state.queue;
    final item = _state.item;
    if (q == null || item == null) return;
    final nq = RecitationQueue.build(
      q.range,
      repeatAyah: repeatAyah ?? q.repeatAyah,
      repeatRange: repeatRange ?? (q.loops ? 0 : q.repeatRange),
      gap: gap ?? q.gap,
      basmala: basmala ?? q.basmala,
    );
    final pass = nq.loops || item.rangePass <= nq.repeatRange ? item.rangePass : nq.repeatRange;
    var index = nq.indexOfAyah(item.ayah, rangePass: pass) ?? 0;
    final wantPass = item.ayahPass.clamp(1, nq.repeatAyah);
    var keepPosition = false;
    if (item.isAyah) {
      for (var i = index; nq.contains(i) && nq.itemAt(i).group == nq.itemAt(index).group; i++) {
        final c = nq.itemAt(i);
        if (c.isAyah && c.ayahPass == wantPass) {
          index = i;
          keepPosition = true;
          break;
        }
      }
    }
    await _reload(nq, index, _state.reciter, position: keepPosition ? currentPosition : Duration.zero);
  }

  /// Switches the reciter of what is playing (same ayah, from its start).
  Future<void> setReciter(Reciter reciter) async {
    final q = _state.queue;
    if (q == null || reciter == _state.reciter) {
      if (q == null) _emit(_state.copyWith(reciter: reciter));
      return;
    }
    await _reload(q, q.groupStartOf(_state.index), reciter);
  }

  Future<void> setSpeed(double speed) async {
    _emit(_state.copyWith(speed: speed));
    try {
      await _engine?.setSpeed(speed);
    } catch (_) {}
  }

  /// Pauses after [after] (null cancels).
  void setSleepTimer(Duration? after) {
    _cancelSleepTimer();
    if (after == null) {
      _emit(_state.copyWith(sleep: () => null));
      return;
    }
    final at = _clock().add(after);
    _sleepTimer = Timer(after, () {
      _emit(_state.copyWith(sleep: () => null));
      unawaited(_pauseFor(RecitationPause.sleepTimer));
    });
    _emit(_state.copyWith(sleep: () => SleepTimer.at(at, length: after)));
  }

  /// Pauses when the ayah being recited ends.
  void setSleepAfterAyah() {
    _cancelSleepTimer();
    _emit(_state.copyWith(sleep: () => const SleepTimer.afterAyah()));
  }

  // ------------------------------------------------------------- internals

  RecitationEngine _ensureEngine() {
    final existing = _engine;
    if (existing != null) return existing;
    final engine = _engine = _engineFactory();
    void ignore(Object _) {}
    _subs.addAll([
      engine.index.listen(_onEngineIndex, onError: ignore),
      engine.status.listen(_onEngineStatus, onError: ignore),
      engine.failures.listen(_fail, onError: ignore),
      _focus.interruptions.listen(_onInterruption, onError: ignore),
      _focus.becomingNoisy.listen((_) => unawaited(_pauseFor(RecitationPause.noisy)), onError: ignore),
    ]);
    return engine;
  }

  EngineSource _sourceFor(Reciter reciter, QueueItem item) {
    if (item.isGap) return EngineSource.silence(item.gap);
    final ayah = item.audioAyah!;
    final file = _local.localFile(reciter, ayah, basmala: item.isBasmala);
    if (file != null) return EngineSource.file(file.path);
    return EngineSource.url(EveryAyah.urlFor(reciter, ayah));
  }

  Future<void> _loadWindow(int start, int gen, {Duration position = Duration.zero}) async {
    final q = _state.queue;
    if (q == null) return;
    await _topUpFuture;
    if (gen != _generation) return;
    final reciter = _state.reciter;
    final sources = [for (final item in q.slice(start, start + windowSize)) _sourceFor(reciter, item)];
    _loadingWindow = true;
    try {
      _windowStart = start;
      _window = sources;
      await _engine!.setSources(sources, initialPosition: position);
    } finally {
      _loadingWindow = false;
    }
    if (gen == _generation) _onEngineIndex(_engine!.currentIndex ?? 0);
  }

  Future<void> _reload(RecitationQueue queue, int index, Reciter reciter, {Duration position = Duration.zero}) async {
    final gen = ++_generation;
    final wasPlaying = _state.playing || (_state.loading && _state.pausedBy == null);
    _emit(_state.copyWith(queue: queue, index: index, item: queue.itemAt(index), reciter: reciter));
    if (_engine == null) return;
    try {
      await _loadWindow(index, gen, position: position);
      if (gen == _generation && wasPlaying) await _engine!.play();
    } catch (e) {
      if (gen == _generation) _fail(e);
    }
  }

  Future<void> _seekTo(int target) async {
    final q = _state.queue;
    if (q == null || !q.contains(target) || _engine == null) return;
    final local = target - _windowStart;
    if (local >= 0 && local < _window.length) {
      _advance(target, local);
      try {
        await _engine!.seek(Duration.zero, index: local);
      } catch (e) {
        _fail(e);
      }
    } else {
      await _reload(q, target, _state.reciter);
    }
  }

  void _topUp() {
    if (_topUpFuture != null || _loadingWindow) return;
    final q = _state.queue;
    if (q == null) return;
    final next = _windowStart + _window.length;
    if (!q.contains(next)) return;
    final reciter = _state.reciter;
    final sources = [for (final item in q.slice(next, next + windowSize)) _sourceFor(reciter, item)];
    final gen = _generation;
    _window = [..._window, ...sources];
    _topUpFuture = _engine!
        .addSources(sources)
        .catchError((Object e) {
          if (gen == _generation) _fail(e);
        })
        .whenComplete(() => _topUpFuture = null);
  }

  void _onEngineIndex(int? local) {
    if (local == null || _loadingWindow) return;
    final q = _state.queue;
    if (q == null || local < 0 || local >= _window.length) return;
    final logical = _windowStart + local;
    if (!q.contains(logical)) return;
    if (logical != _state.index || _state.localFile != !_window[local].isRemote) _advance(logical, local);
    if (local >= _window.length - lookahead) _topUp();
  }

  void _advance(int logical, int local) {
    final q = _state.queue!;
    final previous = _state.item;
    final item = q.itemAt(logical);
    final moved = logical != _state.index;
    _emit(_state.copyWith(index: logical, item: item, localFile: !_window[local].isRemote));
    final now = _clock();
    if (item.isAyah && _tracker.listenedAt(now) >= checkpointEvery) {
      final audible = _state.playing && !_state.loading;
      unawaited(_endSession());
      if (audible) _tracker.setAudible(true, now);
    }
    if (item.isAyah) _tracker.heard(item.ayah, _state.reciter.id, now);
    _tracker.setAudible(_state.playing && !_state.loading && !item.isGap, now);
    if (moved && previous != null && previous.isAyah && (_state.sleep?.afterAyah ?? false)) {
      _emit(_state.copyWith(sleep: () => null));
      unawaited(_pauseFor(RecitationPause.sleepTimer));
    }
  }

  void _onEngineStatus(EngineStatus s) {
    if (_state.queue == null || _disposed) return;
    if (s.processing == EngineProcessing.completed) {
      unawaited(_complete());
      return;
    }
    if (s.playing && s.processing == EngineProcessing.ready) _starting = false;
    final loading = s.processing == EngineProcessing.loading || s.processing == EngineProcessing.buffering || _starting;
    _emit(
      _state.copyWith(
        playing: s.playing,
        loading: loading,
        pausedBy: s.playing ? () => null : null,
        error: s.playing ? () => null : null,
      ),
    );
    final audible = s.playing && !loading && !(_state.item?.isGap ?? false);
    _tracker.setAudible(audible, _clock());
    if (s.playing) {
      _cancelIdleFlush();
      _acquireMute();
    } else {
      _releaseMute();
      _scheduleIdleFlush();
    }
  }

  Future<void> _complete() async {
    ++_generation;
    _starting = false;
    _releaseMute();
    _cancelIdleFlush();
    _cancelSleepTimer();
    _window = [];
    _emit(_state.cleared().copyWith(sleep: () => null));
    _lastMedia = null;
    _media?.update(null, _mediaTexts.labels);
    await _endSession();
    try {
      await _engine?.stop();
    } catch (_) {}
  }

  void _fail(Object e) {
    if (!_state.active || _disposed) return;
    final local = e is EngineFailure ? (e.index ?? -1) : _state.index - _windowStart;
    final remote = local >= 0 && local < _window.length ? _window[local].isRemote : true;
    final message = e is EngineFailure ? (e.message ?? '') : '$e';
    final RecitationError error;
    if (message.contains('404') || (e is EngineFailure && e.notFound)) {
      error = RecitationError.notFound;
    } else if (e is SocketException || e is HttpException || remote) {
      error = RecitationError.network;
    } else {
      error = RecitationError.playback;
    }
    _starting = false;
    _emit(_state.copyWith(playing: false, loading: false, pausedBy: () => RecitationPause.error, error: () => error));
    _releaseMute();
    final engine = _engine;
    if (engine != null) unawaited(engine.pause().catchError((Object _) {}));
  }

  Future<void> _pauseFor(RecitationPause reason) async {
    if (!_state.active) return;
    _starting = false;
    _emit(_state.copyWith(playing: false, loading: false, pausedBy: () => reason));
    _tracker.setAudible(false, _clock());
    _releaseMute();
    _scheduleIdleFlush();
    try {
      await _engine?.pause();
    } catch (_) {}
  }

  // ------------------------------------------------ prayer mute and focus

  int _foreignLeaseCount() => _mute?.reasons.where((r) => r != _muteReason).length ?? 0;

  void _onPrayerMute() {
    final foreign = _foreignLeaseCount();
    final rising = foreign > _foreignLeases;
    _foreignLeases = foreign;
    if (!rising || !_state.active) return;
    final sounding = _state.playing || (_state.loading && _state.pausedBy == null);
    if (sounding || _state.pausedBy == RecitationPause.interruption) {
      // Never resumed by itself – only when the user asks.
      _resumeAfterInterruption = false;
      unawaited(_pauseFor(RecitationPause.prayer));
    }
  }

  void _onInterruption(({bool begin, bool transient}) e) {
    if (!_state.active) return;
    if (e.begin) {
      if (_state.playing || _state.loading) {
        _resumeAfterInterruption = e.transient;
        unawaited(_pauseFor(RecitationPause.interruption));
      }
    } else if (_resumeAfterInterruption && _state.pausedBy == RecitationPause.interruption) {
      _resumeAfterInterruption = false;
      unawaited(resume());
    }
  }

  void _acquireMute() => _lease ??= _mute?.acquire(_muteReason);

  void _releaseMute() {
    _lease?.release();
    _lease = null;
  }

  // -------------------------------------------------------- media session

  RecitationMediaTexts get _mediaTexts => _texts?.call() ?? RecitationMediaTexts.fallback;

  Future<void> _ensureBackground() => _mediaStart ??= () async {
    try {
      final session = await _background.start();
      if (session == null || _disposed) return;
      _media = session;
      session.attach(this);
      _emit(_state.copyWith(background: true));
      _pushMedia(force: true);
    } catch (_) {}
  }();

  void _pushMedia({bool force = false}) {
    final media = _media;
    if (media == null) return;
    final item = _state.item;
    if (!_state.active || item == null) return;
    final texts = _mediaTexts;
    final q = _state.queue!;
    final info = RecitationMediaInfo(
      id: 'quran/${_state.reciter.id}/${item.ayah}${item.isBasmala ? '/basmala' : ''}',
      title: texts.title(item),
      reciter: texts.reciterName(_state.reciter),
      album: texts.album,
      playing: _state.playing,
      loading: _state.loading,
      position: currentPosition,
      duration: currentDuration,
      speed: _state.speed,
      hasNext: q.nextAyahStart(_state.index) != null,
      hasPrevious: true,
    );
    if (!force && info == _lastMedia) return;
    _lastMedia = info;
    try {
      media.update(info, texts.labels);
    } catch (_) {}
  }

  // --------------------------------------------------------- session log

  void _scheduleIdleFlush() {
    _idleTimer?.cancel();
    if (_tracker.isEmpty) return;
    _idleTimer = Timer(idleFlushAfter, () => unawaited(_endSession()));
  }

  void _cancelIdleFlush() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
  }

  Future<void> _endSession() async {
    final summary = _tracker.flush(_clock());
    final logger = _logger;
    if (summary == null || !_logging || logger == null) return;
    try {
      await logger.log(summary);
    } catch (e) {
      debugPrint('Recitation: could not log the listening session ($e)');
    }
  }

  /// Logs the session so far (the app going away).
  Future<void> flushSession() => _endSession();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _mute?.removeListener(_onPrayerMute);
    _releaseMute();
    _cancelSleepTimer();
    _cancelIdleFlush();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    final engine = _engine;
    if (engine != null) unawaited(engine.dispose().catchError((Object _) {}));
    unawaited(_playback.close());
    super.dispose();
  }
}
