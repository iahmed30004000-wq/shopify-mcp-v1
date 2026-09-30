import 'dart:isolate';
import 'dart:typed_data';

import '../../core/audio.dart';
import '../../core/era.dart';
import '../../core/era_skin.dart';
import '../music/composers.dart';
import '../music/stingers.dart';
import '../sfx/sfx_synth.dart';
import '../synth/renderer.dart';

/// Where rendered audio comes from. The default renders on background
/// isolates ([IsolateCueSource]); tests inject a fast fake.
abstract interface class CueSource {
  Future<RenderedCue> renderCue(ScoreStyle style, MusicMood mood, int seed);
  Future<StingerKit> renderStingers(ScoreStyle style, int seed);
  Future<Map<String, Uint8List>> renderSfx(Era era, int seed);
}

/// Composes and renders off the UI isolate (`Isolate.run`; the result's
/// byte buffers move back without copying).
final class IsolateCueSource implements CueSource {
  const IsolateCueSource();

  /// Each stem renders on its own isolate (they are independent until the
  /// final levelling), so a cue is ready about as fast as its busiest stem.
  @override
  Future<RenderedCue> renderCue(ScoreStyle style, MusicMood mood, int seed) => Isolate.run(() async {
    final watch = Stopwatch()..start();
    final score = composeCue(style, mood, seed);
    final stems = await Future.wait([
      for (var i = 0; i < score.stems.length; i++)
        Isolate.run(() => CueRenderer().renderStem(composeCue(style, mood, seed), i, seed: seed), debugName: 'cinema-stem-$i'),
    ]);
    return CueRenderer().finish(score, stems, seed: seed, renderMs: watch.elapsedMilliseconds);
  }, debugName: 'cinema-cue-${mood.name}');

  @override
  Future<StingerKit> renderStingers(ScoreStyle style, int seed) =>
      Isolate.run(() => renderStingerKit(style, seed: seed), debugName: 'cinema-stingers');

  @override
  Future<Map<String, Uint8List>> renderSfx(Era era, int seed) =>
      Isolate.run(() => SfxSynth(era, seed: seed).renderKit(), debugName: 'cinema-sfx');
}

/// Renders on the calling isolate (previews, benchmarks).
final class InlineCueSource implements CueSource {
  const InlineCueSource();

  @override
  Future<RenderedCue> renderCue(ScoreStyle style, MusicMood mood, int seed) async =>
      CueRenderer().render(composeCue(style, mood, seed), seed: seed);

  @override
  Future<StingerKit> renderStingers(ScoreStyle style, int seed) async => renderStingerKit(style, seed: seed);

  @override
  Future<Map<String, Uint8List>> renderSfx(Era era, int seed) async => SfxSynth(era, seed: seed).renderKit();
}

/// Process-wide memo of rendered audio, shared by every game: a restart or
/// a second game of the same era does not render its effects, stingers or
/// already-heard cues again. LRU-bounded by [budgetBytes] of WAV data.
final class CachingCueSource implements CueSource {
  CachingCueSource(this.inner, {this.budgetBytes = 12 << 20});

  /// The source every standard director and bank use.
  static final CachingCueSource shared = CachingCueSource(const IsolateCueSource());

  final CueSource inner;
  final int budgetBytes;
  final Map<String, (Future<Object>, int)> _entries = {};
  int _clock = 0;

  int get cachedBytes => _sizes.values.fold(0, (a, b) => a + b);
  final Map<String, int> _sizes = {};

  Future<T> _memo<T extends Object>(String key, Future<T> Function() make, int Function(T) size) {
    final hit = _entries[key];
    if (hit != null) {
      _entries[key] = (hit.$1, ++_clock);
      return hit.$1.then((v) => v as T);
    }
    final f = make();
    _entries[key] = (f, ++_clock);
    f.then(
      (v) {
        _sizes[key] = size(v);
        _trim();
      },
      onError: (Object _) {
        _entries.remove(key);
        _sizes.remove(key);
      },
    );
    return f;
  }

  void _trim() {
    while (cachedBytes > budgetBytes && _sizes.length > 1) {
      final oldest = _sizes.keys.reduce((a, b) => _entries[a]!.$2 <= _entries[b]!.$2 ? a : b);
      _entries.remove(oldest);
      _sizes.remove(oldest);
    }
  }

  /// Drops everything (tests, memory pressure).
  void clear() {
    _entries.clear();
    _sizes.clear();
  }

  static String _styleKey(ScoreStyle s) =>
      '${s.style.name}/${s.tempo}/${s.swing}/${s.rootMidi}/${s.minor}/${s.lofi}/${s.crackle}';

  @override
  Future<RenderedCue> renderCue(ScoreStyle style, MusicMood mood, int seed) =>
      _memo('cue/${_styleKey(style)}/${mood.name}/$seed', () => inner.renderCue(style, mood, seed), (c) => c.bytes);

  @override
  Future<StingerKit> renderStingers(ScoreStyle style, int seed) =>
      _memo('stingers/${_styleKey(style)}/$seed', () => inner.renderStingers(style, seed), (k) => k.bytes);

  @override
  Future<Map<String, Uint8List>> renderSfx(Era era, int seed) =>
      _memo('sfx/${era.name}/$seed', () => inner.renderSfx(era, seed), (m) => m.values.fold(0, (a, b) => a + b.length));
}
