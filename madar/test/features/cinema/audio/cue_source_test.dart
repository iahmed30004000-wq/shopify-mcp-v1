import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/music/stingers.dart';
import 'package:madar/features/cinema/engine/audio/runtime/cue_source.dart';
import 'package:madar/features/cinema/engine/audio/sfx/sfx_synth.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';
import 'package:madar/features/cinema/engine/core/era_skin.dart';

import 'fake_mixer.dart';

void main() {
  group('IsolateCueSource', () {
    test('renders a cue off the calling isolate, byte-identical to the inline renderer', () async {
      // The shortest cue of the catalogue: a 1930s defeat jingle.
      final style = eraScore(Era.rubberHose);
      final iso = await const IsolateCueSource().renderCue(style, MusicMood.defeat, 2);
      final inline = await const InlineCueSource().renderCue(style, MusicMood.defeat, 2);
      expect(iso.info.loopSeconds, inline.info.loopSeconds);
      expect(iso.info.introSeconds, inline.info.introSeconds);
      expect(iso.info.loops, isFalse);
      expect(iso.stems, hasLength(inline.stems.length));
      for (var i = 0; i < iso.stems.length; i++) {
        expect(_same(iso.stems[i].loop, inline.stems[i].loop), isTrue, reason: 'stem $i loop');
        expect(_same(iso.stems[i].intro, inline.stems[i].intro), isTrue, reason: 'stem $i intro');
      }
      expect(iso.bytes, greaterThan(0));
    });

    test('renders the effects kit and the stingers off the calling isolate', () async {
      final sfx = await const IsolateCueSource().renderSfx(Era.vhs, 1);
      expect(sfx.keys.toSet(), {for (final s in CinemaSound.values) sfxKey(s), for (final s in CinemaSfx.values) extraKey(s)});
      expect(sfx.values.every((w) => w.length > 44), isTrue);
      final kit = await const IsolateCueSource().renderStingers(eraScore(Era.vhs), 1);
      expect(kit.clips.keys.toSet(), Stinger.values.toSet());
      expect(kit.bytes, greaterThan(0));
    });
  });

  group('CachingCueSource', () {
    late _CountingSource inner;
    late CachingCueSource cache;
    final style = eraScore(Era.vhs);

    setUp(() {
      inner = _CountingSource();
      cache = CachingCueSource(inner, budgetBytes: 1 << 20);
    });

    test('memoises by style, mood and seed', () async {
      final a = await cache.renderCue(style, MusicMood.calm, 1);
      final b = await cache.renderCue(style, MusicMood.calm, 1);
      expect(identical(a, b), isTrue);
      expect(inner.cues, 1);
      await cache.renderCue(style, MusicMood.calm, 2);
      expect(inner.cues, 2, reason: 'another seed is another cue');
      await cache.renderCue(eraScore(Era.noir), MusicMood.calm, 1);
      expect(inner.cues, 3, reason: 'another style is another cue');
      await cache.renderStingers(style, 1);
      await cache.renderStingers(style, 1);
      expect(inner.stingers, 1);
      await cache.renderSfx(Era.vhs, 1);
      await cache.renderSfx(Era.vhs, 1);
      await cache.renderSfx(Era.noir, 1);
      expect(inner.sfx, 2);
    });

    test('trims the least recently used entries down to the budget, keeping the latest', () async {
      final one = (await cache.renderCue(style, MusicMood.calm, 1)).bytes;
      cache = CachingCueSource(inner, budgetBytes: (one * 2.5).round());
      inner.cues = 0;
      await cache.renderCue(style, MusicMood.calm, 1);
      await cache.renderCue(style, MusicMood.boss, 1);
      // Touch calm so boss is the oldest.
      await cache.renderCue(style, MusicMood.calm, 1);
      await cache.renderCue(style, MusicMood.action, 1);
      expect(inner.cues, 3);
      expect(cache.cachedBytes, lessThanOrEqualTo((one * 2.5).round()));
      await cache.renderCue(style, MusicMood.calm, 1);
      await cache.renderCue(style, MusicMood.action, 1);
      expect(inner.cues, 3, reason: 'the two most recent cues are still cached');
      await cache.renderCue(style, MusicMood.boss, 1);
      expect(inner.cues, 4, reason: 'the oldest was evicted');
    });

    test('a failed render is not remembered; clear() forgets everything', () async {
      inner.failNext = true;
      await expectLater(cache.renderCue(style, MusicMood.calm, 1), throwsStateError);
      await cache.renderCue(style, MusicMood.calm, 1);
      expect(inner.cues, 2, reason: 'the failure was retried, not served from the cache');
      expect(cache.cachedBytes, greaterThan(0));
      cache.clear();
      expect(cache.cachedBytes, 0);
      await cache.renderCue(style, MusicMood.calm, 1);
      expect(inner.cues, 3);
    });
  });
}

bool _same(Uint8List? a, Uint8List? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Counts what reaches the inner source.
class _CountingSource implements CueSource {
  final FakeCueSource _fake = FakeCueSource();
  int cues = 0, stingers = 0, sfx = 0;
  bool failNext = false;

  @override
  Future<RenderedCue> renderCue(ScoreStyle style, MusicMood mood, int seed) async {
    cues++;
    if (failNext) {
      failNext = false;
      throw StateError('render failed');
    }
    return _fake.renderCue(style, mood, seed);
  }

  @override
  Future<StingerKit> renderStingers(ScoreStyle style, int seed) {
    stingers++;
    return _fake.renderStingers(style, seed);
  }

  @override
  Future<Map<String, Uint8List>> renderSfx(Era era, int seed) {
    sfx++;
    return _fake.renderSfx(era, seed);
  }
}
