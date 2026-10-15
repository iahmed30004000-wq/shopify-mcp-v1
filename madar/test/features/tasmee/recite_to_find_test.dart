// «شازام القرآن»: recite a phrase and be told where it is – offline, over
// the app's own verified text, and honest when it cannot say.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import '../quran/quran_test_data.dart';
import 'tasmee_fixtures.dart';

void main() {
  late ReciteIndex index;

  setUpAll(() {
    final meta = QuranTestData.meta;
    final text = QuranTestData.text;
    index = ReciteIndex.build([
      for (var i = 0; i < meta.ayahCount; i++) (meta.refAt(i), text.ayahText(i)),
    ]);
  });

  /// The phrase exactly as the verified text writes it.
  String phraseOf(AyahRef ref, {int from = 0, int? take}) {
    final words = verifiedWords(targetOfAyah(ref));
    final slice = words.skip(from);
    return (take == null ? slice : slice.take(take)).join(' ');
  }

  group('the index', () {
    test('it covers the whole Hafs text', () {
      expect(index.ayahCount, QuranTestData.meta.ayahCount);
      expect(index.wordCount, greaterThan(70000));
      expect(index.gramCount, greaterThan(20000));
      expect(index.gram, 2);
    });
  });

  group('a phrase that is in one ayah only', () {
    test('it names the surah and the ayah, and it is sure', () {
      // 1:5 «إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِينُ».
      final result = index.find(phraseOf(const AyahRef(1, 5)));
      expect(result.confidence, ReciteConfidence.sure);
      expect(result.total, 1);
      final place = result.only;
      expect(place, isNotNull);
      expect(place!.ref, const AyahRef(1, 5));
      expect(place.matchedWords, 4);
    });

    test('the ranges it gives are code units of the original ayah text', () {
      final ref = const AyahRef(1, 7);
      final result = index.find(phraseOf(ref));
      final place = result.only!;
      final text = ayahText(ref);
      final words = verifiedWords(targetOfAyah(ref));
      expect(place.ranges, hasLength(words.length));
      for (var i = 0; i < place.ranges.length; i++) {
        final (start, end) = place.ranges[i];
        expect(text.substring(start, end), words[i]);
      }
      expect(place.firstWord, 0);
      expect(place.lastWord, words.length - 1);
    });

    test('a phrase from the middle of a long ayah is found at its real word offsets', () {
      final ref = const AyahRef(2, 255);
      final words = verifiedWords(targetOfAyah(ref));
      final result = index.find(words.skip(6).take(6).join(' '));
      final place = result.places.first;
      expect(place.ref, ref);
      expect(place.firstWord, 6);
      final text = ayahText(ref);
      expect(text.substring(place.ranges.first.$1, place.ranges.last.$2), contains(words[6]));
    });
  });

  group('a phrase that is in several ayat', () {
    test('it offers them all and refuses to pick one', () {
      // The refrain of ar-Rahman, «فَبِأَىِّ آلَآءِ رَبِّكُمَا تُكَذِّبَانِ».
      final result = index.find(phraseOf(const AyahRef(55, 13)));
      expect(result.confidence, ReciteConfidence.several);
      expect(result.total, greaterThan(20));
      expect(result.only, isNull, reason: 'the engine must not guess one of many');
      expect(result.places.length, greaterThan(1));
      expect(result.places.every((p) => p.ref.surah == 55), isTrue);
      expect(result.places.map((p) => p.ref).contains(const AyahRef(55, 13)), isTrue);
    });

    test('the list is capped but the true total is still told', () {
      final result = index.find(phraseOf(const AyahRef(55, 13)), limit: 5);
      expect(result.places, hasLength(5));
      expect(result.total, greaterThan(5));
    });
  });

  group('a phrase that is in no ayah', () {
    test('it says it found nothing instead of offering the closest thing', () {
      final result = index.find('الطابة على الشجرة الكبيرة بالحديقة');
      expect(result.confidence, ReciteConfidence.none);
      expect(result.places, isEmpty);
      expect(result.only, isNull);
      expect(result.isEmpty, isTrue);
    });
  });

  group('a phrase that is too short', () {
    test('two words are everywhere, so it refuses to place them', () {
      final result = index.find(phraseOf(const AyahRef(1, 5), take: 2));
      expect(result.confidence, ReciteConfidence.tooShort);
      expect(result.places, isEmpty);
      expect(ReciteIndex.minWords, 3);
    });
  });

  group('a phrase with the recogniser noise in it', () {
    test('a word it was unsure about is dropped, and the ayah is still found', () {
      final ref = const AyahRef(1, 7);
      final words = verifiedWords(targetOfAyah(ref));
      final heard = <HeardWord>[];
      var clock = Duration.zero;
      void say(String word, double confidence) {
        heard.add(HeardWord(heard: word, at: clock, until: clock + const Duration(milliseconds: 500), confidence: confidence));
        clock += const Duration(milliseconds: 600);
      }

      for (var i = 0; i < words.length; i++) {
        if (i == 4) say('خششش', 0.08); // noise, and the model knows it
        say(words[i], 0.93);
      }
      final result = index.findHeard(heard);
      expect(result.words, hasLength(words.length), reason: 'the unsure word never reaches the index');
      expect(result.confidence, ReciteConfidence.sure);
      expect(result.only!.ref, ref);
    });

    test('a confidently mis-heard word lowers the score but does not lose the ayah', () {
      final ref = const AyahRef(1, 7);
      final words = [...verifiedWords(targetOfAyah(ref))];
      words[3] = 'مالك'; // a real word, in the wrong place
      final result = index.find(words.join(' '));
      expect(result.places.first.ref, ref);
      expect(result.places.first.score, lessThan(1.0));
      expect(result.places.first.score, greaterThan(0.5));
    });

    test('a partial hypothesis is never searched for', () {
      final words = verifiedWords(targetOfAyah(const AyahRef(1, 5)));
      final heard = [
        for (var i = 0; i < words.length; i++)
          HeardWord(heard: words[i], at: Duration(milliseconds: 600 * i), confidence: 0.9),
        const HeardWord(heard: 'ربنا', at: Duration(milliseconds: 5000), confidence: 0.9, isFinal: false),
      ];
      final result = index.findHeard(heard);
      expect(result.words, hasLength(words.length));
      expect(result.only!.ref, const AyahRef(1, 5));
    });
  });

  group('the Uthmani and the everyday spelling are the same phrase', () {
    test('a phrase typed the ordinary way resolves to the same one verse', () {
      final uthmani = index.find(phraseOf(const AyahRef(1, 5)));
      final plain = index.find('إياك نعبد وإياك نستعين');
      expect(plain.confidence, ReciteConfidence.sure);
      expect(plain.only!.ref, uthmani.only!.ref);
      expect(plain.only!.ranges, uthmani.only!.ranges);
    });
  });
}
