// The Juz' Amma reader: config list, local-only sound, the lit word.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/faith/data/kids_audio.dart';
import 'package:madar/features/kids/faith/domain/juz_amma_config.dart';
import 'package:madar/features/kids/faith/domain/word_highlight.dart';
import 'package:madar/features/kids/faith/presentation/kids_juz_amma_screen.dart';
import 'package:madar/features/kids/faith/presentation/widgets/kids_faith_ui.dart';
import 'package:madar/features/quran/data/quran_com_client.dart';
import 'package:madar/features/quran/data/quran_providers.dart';
import 'package:madar/features/recitation/data/download_transport.dart';
import 'package:madar/features/recitation/application/recitation_providers.dart' show recitationTransportProvider;
import 'package:madar/features/recitation/data/local_files.dart';
import 'package:madar/features/recitation/domain/reciters.dart';
import 'package:madar/features/kids/faith/application/faith_providers.dart';

import '../../quran/quran_test_data.dart';
import 'faith_harness.dart';

class _CountingHttp implements QuranHttp {
  int calls = 0;
  @override
  Future<(int, String)> get(Uri uri) async {
    calls++;
    throw const QuranComException(QuranComProblem.offline);
  }
}

class _CountingTransport implements DownloadTransport {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw UnsupportedError('network used');
  }
}

class _Files implements LocalRecitationFiles {
  _Files({this.missingAyah = const {}, this.basmala = true});
  final Set<int> missingAyah;
  final bool basmala;
  @override
  Future<void> prepare() async {}
  @override
  File? localFile(Reciter reciter, AyahRef ayah, {bool basmala = false}) {
    if (basmala) return this.basmala ? File('b.mp3') : null;
    return missingAyah.contains(ayah.ayah) ? null : File('${ayah.fileKey}.mp3');
  }
}

class _Player implements QuranAudio {
  final List<(AyahRange, int?, int?)> plays = [];
  @override
  Stream<QuranPlayback> get playback => const Stream.empty();
  @override
  QuranPlayback get value => QuranPlayback.idle;
  @override
  Future<void> play(AyahRange range, {int? repeatAyah, int? repeatRange}) async => plays.add((range, repeatAyah, repeatRange));
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
}

void main() {
  group('even division of the ayah (no per-word timing exists in the Quran feature)', () {
    int? lit(int words, int ms, int totalMs) => litWordIndex(wordCount: words, elapsed: Duration(milliseconds: ms), duration: Duration(milliseconds: totalMs));

    test('each word gets an equal share and the last word rests', () {
      expect([for (final ms in [0, 999, 1000, 1999, 2000, 3000, 3999, 4000, 9000]) lit(4, ms, 4000)], [0, 0, 1, 1, 2, 3, 3, 3, 3]);
    });

    test('degenerate inputs', () {
      expect(lit(0, 100, 1000), isNull);
      expect(lit(3, -1, 1000), isNull);
      expect(lit(3, 100, 0), 2);
      expect(lit(1, 5000, 1000), 0);
    });

    test('with no real duration the estimate is words x a fixed pace', () {
      expect(estimatedAyahDuration(4), Duration(milliseconds: (4 * kidsSecondsPerWord * 1000).round()));
    });

    test('a lone pause sign is glued to the word before it, never a word of its own', () {
      expect(ayahWords('ابج \u06D6 دهو زحط'), ['ابج \u06D6', 'دهو', 'زحط']);
      expect(ayahWords(''), isEmpty);
    });

    test('every ayah of juz amma splits into words that all contain a letter', () {
      final meta = QuranTestData.meta;
      final text = QuranTestData.text;
      for (var s = 78; s <= 114; s++) {
        final info = meta.surah(s);
        for (var a = 0; a < info.ayahCount; a++) {
          expect(ayahWords(text.ayahText(info.firstIndex + a)), isNotEmpty, reason: '$s:${a + 1}');
        }
      }
    });
  });

  group('the surah list is config', () {
    test('default is empty', () {
      expect(cleanJuzAmmaSurahs(const []), isEmpty);
    });

    test('only 78..114, no repeats, order kept', () {
      expect(cleanJuzAmmaSurahs(const [114, 2, 78, 114, 77, 115, 100]), [114, 78, 100]);
    });
  });

  group('local-only sound', () {
    test('nothing downloaded: not on the phone, and play refuses without touching the player', () async {
      final player = _Player();
      final a = LocalOnlyKidsAudio(files: _Files(missingAyah: {1, 2, 3, 4, 5, 6}), audio: player, reciter: () => Reciters.fallback);
      expect(await a.isSurahOnPhone(114, ayahCount: 6), isFalse);
      expect(await a.play(const AyahRange(AyahRef(114, 1), AyahRef(114, 6))), isFalse);
      expect(player.plays, isEmpty);
    });

    test('a missing basmala or a single missing ayah is enough to refuse', () async {
      final noBasmala = LocalOnlyKidsAudio(files: _Files(basmala: false), audio: _Player(), reciter: () => Reciters.fallback);
      expect(await noBasmala.isSurahOnPhone(114, ayahCount: 6), isFalse);
      final player = _Player();
      final hole = LocalOnlyKidsAudio(files: _Files(missingAyah: {4}), audio: player, reciter: () => Reciters.fallback);
      expect(await hole.play(const AyahRange(AyahRef(114, 1), AyahRef(114, 6))), isFalse);
      expect(player.plays, isEmpty);
      // ...but the ayat that ARE on the phone can be replayed on their own.
      expect(await hole.play(const AyahRange.single(AyahRef(114, 5))), isTrue);
    });

    test('everything downloaded: it plays once, with no repeats', () async {
      final player = _Player();
      final a = LocalOnlyKidsAudio(files: _Files(), audio: player, reciter: () => Reciters.fallback);
      expect(await a.isSurahOnPhone(114, ayahCount: 6), isTrue);
      expect(await a.play(const AyahRange(AyahRef(114, 1), AyahRef(114, 6))), isTrue);
      expect(player.plays.single.$2, 1);
      expect(player.plays.single.$3, 1);
    });
  });

  group('the screen', () {
    late _CountingHttp http;
    late _CountingTransport transport;
    late FakeKidsAudio audio;

    setUp(() {
      http = _CountingHttp();
      transport = _CountingTransport();
      audio = FakeKidsAudio();
    });

    Future<void> pump(WidgetTester tester, {bool unlocked = true, List<int> surahs = const [114], bool onPhone = true}) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      audio.onPhone = onPhone;
      await tester.pumpWidget(
        faithApp(
          const JuzAmmaScreen(),
          overrides: [
            ...quranOverrides(),
            kidsReligiousUnlockedProvider.overrideWithValue(unlocked),
            kidsJuzAmmaSurahsProvider.overrideWithValue(surahs),
            kidsAyahAudioProvider.overrideWithValue(audio),
            quranHttpProvider.overrideWithValue(http),
            recitationTransportProvider.overrideWithValue(transport),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    String firstWord(int surah, int ayah) {
      final meta = QuranTestData.meta;
      return ayahWords(QuranTestData.text.ayahText(meta.surah(surah).firstIndex + ayah - 1)).first;
    }

    Finder litWord() => find.byWidgetPredicate((w) => w is Container && w.child is Text && (w.decoration as BoxDecoration?)?.color == KP.sun500);

    String litText(WidgetTester tester) => (tester.widget<Container>(litWord()).child! as Text).data!;

    testWidgets('empty config => «قريبًا»', (tester) async {
      await pump(tester, surahs: const []);
      expect(find.text('قريبًا'), findsOneWidget);
    });

    testWidgets('shows the bundled Tanzil words of the configured surah', (tester) async {
      await pump(tester);
      expect(find.text('الناس'), findsOneWidget);
      expect(find.text(firstWord(114, 1)), findsWidgets);
      expect(find.text(firstWord(114, 6)), findsWidgets);
    });

    testWidgets('sound not downloaded: calm «الصوت مش محمّل», play is dead, and no network call is ever made', (tester) async {
      await pump(tester, onPhone: false);
      expect(find.textContaining('الصوت مش محمّل'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded), warnIfMissed: false);
      await tester.pump();
      expect(audio.played, isEmpty);
      expect(litWord(), findsNothing);
      expect(http.calls, 0);
      expect(transport.calls, 0);
    });

    testWidgets('the current word is lit and moves on, then follows the player to the next ayah', (tester) async {
      await pump(tester);
      expect(litWord(), findsNothing);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(audio.played.single, const AyahRange(AyahRef(114, 1), AyahRef(114, 6)));
      expect(litText(tester), firstWord(114, 1));

      final words1 = ayahWords(QuranTestData.text.ayahText(QuranTestData.meta.surah(114).firstIndex));
      await tester.pump(const Duration(milliseconds: 800)); // a little over one word
      expect(litText(tester), words1[1]);

      audio.emit(const QuranPlayback(current: AyahRef(114, 2), playing: true));
      await tester.pump();
      await tester.pump();
      expect(litText(tester), firstWord(114, 2));
      expect(http.calls + transport.calls, 0);
    });

    testWidgets('pausing freezes the lit word', (tester) async {
      await pump(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final before = litText(tester);
      audio.emit(const QuranPlayback(current: AyahRef(114, 1)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(litText(tester), before);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('«جرّب أنت» is hidden while no recognition engine exists', (tester) async {
      await pump(tester);
      expect(find.byIcon(Icons.mic_rounded), findsNothing);
    });

    testWidgets('survives text scale 1.3 on a phone', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        faithApp(
          const JuzAmmaScreen(),
          textScale: 1.3,
          overrides: [
            ...quranOverrides(),
            kidsReligiousUnlockedProvider.overrideWithValue(true),
            kidsJuzAmmaSurahsProvider.overrideWithValue(const [114, 112]),
            kidsAyahAudioProvider.overrideWithValue(audio),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pump();
      expect(find.text('الإخلاص'), findsOneWidget);
    });
  });
}
