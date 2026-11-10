// THE RELIGIOUS GUARD (Part 15, absolute rule): no verse, no hadith, no
// ruling from the model's memory. The Quran text comes from the app's
// bundled Tanzil Uthmani file; the hadith / ruling cases are formulas with
// made-up content (these tests never write a real hadith).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ondevice_ai/domain/religious_guard.dart';

import '../quran/quran_test_data.dart';

final RegExp _marks = RegExp('[ً-ٰٟۖ-ۭـ]');

void main() {
  late ReligiousOutputGuard guard;
  late List<String> ayat;

  setUpAll(() {
    final text = QuranTestData.text;
    final meta = QuranTestData.meta;
    guard = ReligiousOutputGuard(QuranVerseIndex.fromQuran(text, meta));
    ayat = [for (var i = 0; i < text.length; i++) text.ayahText(i)];
  });

  String ayahOf(int surah, int ayah) {
    final s = QuranTestData.meta.surahs[surah - 1];
    return ayat[s.firstIndex + ayah - 1];
  }

  GuardKind? kindOf(String text) => guard.check(text).kind;

  group('Quran: a run of 4 or more consecutive words of the bundled text', () {
    test('a whole verse, as the Uthmani text', () {
      final v = guard.check('الآية هي: ${ayahOf(2, 255)}');
      expect(v.allowed, isFalse);
      expect(v.kind, GuardKind.quran);
    });

    test('the same verse written without diacritics (everyday spelling)', () {
      final plain = ayahOf(112, 1).replaceAll(_marks, '');
      expect(kindOf('تقصد: $plain'), GuardKind.quran);
    });

    test('a verse quoted in the middle of a normal sentence', () {
      final words = ayahOf(2, 255).split(' ');
      final quote = words.take(8).join(' ');
      expect(kindOf('كتبت لك اليوم $quote وبعدها نمت'), GuardKind.quran);
    });

    test('a run that crosses from one verse into the next', () {
      final a = ayahOf(2, 10).split(' ');
      final b = ayahOf(2, 11).split(' ');
      final crossing = [...a.sublist(a.length - 2), ...b.take(2)].join(' ');
      expect(kindOf(crossing), GuardKind.quran);
    });

    test('exactly 4 words is a verse, 3 words are not', () {
      final w = ayahOf(2, 255).split(' ');
      expect(kindOf(w.take(4).join(' ')), GuardKind.quran);
      // Three words and then something that is not the next word.
      expect(guard.check('${w.take(3).join(' ')} بنطلون كحلي').allowed, isTrue);
    });

    test('a verse split into pieces by other words is not a run', () {
      final w = ayahOf(2, 255).split(' ');
      final spaced = [w[0], 'اشتريت', w[1], 'خبزا', w[2], 'وحليبا', w[3]].join(' ');
      expect(guard.check(spaced).allowed, isTrue);
    });

    test('the ornate verse brackets alone are enough', () {
      expect(kindOf('\u{FD3E}كلام\u{FD3F}'), GuardKind.quran);
    });

    test('introducers of a verse are refused even with the verse cut off', () {
      expect(kindOf('قال الله تعالى في كتابه'), GuardKind.quran);
      expect(kindOf('قال تعالى: ...'), GuardKind.quran);
      expect(kindOf('يقول الله تعالى'), GuardKind.quran);
      expect(kindOf('Allah says in the Quran that patience is good'), GuardKind.quran);
      expect(kindOf('The Quran says to be kind'), GuardKind.quran);
    });

    test('a verse in every one of the 114 surahs is caught (the first words of each)', () {
      var missed = 0;
      for (final s in QuranTestData.meta.surahs) {
        final w = ayahOf(s.number, s.ayahCount >= 2 ? 2 : 1).split(' ');
        if (w.length < 4) continue; // too short to be a run of 4 on its own
        if (guard.check(w.join(' ')).allowed) missed++;
      }
      expect(missed, 0);
    });
  });

  group('hadith: attribution formulas (made-up content)', () {
    for (final t in [
      'قال رسول الله شيئا عن الصبر',
      'وقال النبي كلاما ما',
      'قال الرسول عليه الصلاة والسلام كذا وكذا',
      'يقول رسول الله كذا',
      'عن النبي أنه فعل كذا',
      'عن رسول الله كذا',
      'رواه البخاري',
      'اخرجه مسلم في صحيحه',
      'متفق عليه',
      'قال ﷺ كلاما',
      'عن أبي هريرة رضي الله عنه أنه قال كذا',
      'عن عائشة رضي الله عنها قالت كذا',
      'قالت عائشة رضي الله عنها كذا',
      'النبي صلى الله عليه وسلم قال كذا',
      'هذا حديث صحيح',
      'في الحديث الشريف كذا',
      'حدثنا فلان عن فلان',
      'مذكور في صحيح البخاري',
    ]) {
      test(t, () => expect(kindOf(t), GuardKind.hadith));
    }

    for (final t in [
      'The Prophet said something about patience',
      'The Prophet (pbuh) said that',
      'the messenger of allah said',
      'Narrated by Abu Hurairah that',
      'narrated that he did',
      'It is in Sahih Bukhari',
      'this was reported by Muslim',
      'According to the hadith, you should',
      'In a hadith we are told',
    ]) {
      test(t, () => expect(kindOf(t), GuardKind.hadith));
    }
  });

  group('rulings', () {
    for (final t in [
      'هذا حلال',
      'هذا حرام',
      'والحرام بيّن',
      'بالحلال',
      'يجوز لك أن تفعل ذلك',
      'لا يجوز أن تفعل ذلك',
      'ما يجوز هيك',
      'يحرم عليك',
      'هذا مكروه',
      'الفتوى في هذه المسألة',
      'أفتى الشيخ بكذا',
      'الحكم الشرعي لهذا',
      'هذا جائز شرعا',
    ]) {
      test(t, () => expect(kindOf(t), GuardKind.ruling));
    }

    for (final t in [
      'This is haram',
      'that is halal',
      'it is permissible to do so',
      'This is impermissible',
      'He issued a fatwa',
      'it is forbidden to do that',
      'This is forbidden in Islam',
      'the Islamic ruling on this',
    ]) {
      test(t, () => expect(kindOf(t), GuardKind.ruling));
    }
  });

  group('mixed answers', () {
    test('a verse outranks a hadith outranks a ruling, and all are reported', () {
      final v = guard.check('${ayahOf(2, 255)} ثم قال رسول الله كذا وهذا حرام');
      expect(v.kind, GuardKind.quran);
      expect(v.flags.map((f) => f.kind).toSet(), {GuardKind.quran, GuardKind.hadith, GuardKind.ruling});
      expect(guard.check('رواه مسلم وهذا حرام').kind, GuardKind.hadith);
    });
  });

  group('clean text passes', () {
    for (final t in [
      'اليوم صرفت خمسة دنانير على القهوة وصليت العصر بالمسجد ومشيت نص ساعة.',
      'You prayed Fajr on time, walked 30 minutes and spent 5 JOD on coffee.',
      'تمرين صدر ٤×١٢ ووجع الركبة ٦ من ١٠.',
      'رنا اتصلت اليوم وسألت عن أخبارك.',
      'الميزانية: صرفت ٦٢٪ من الشهر.',
      '',
      '   ',
    ]) {
      test('"$t"', () => expect(guard.check(t).allowed, isTrue));
    }
  });

  group('documented false positives and the exceptions', () {
    test('a word that merely CONTAINS «حرام» is not flagged: حرامي، حرامية، حلالنا', () {
      for (final t in ['الحرامي هرب من الدكان', 'الحرامية دخلوا البيت', 'هاد حلالنا وإلنا', 'أسامة حرامي الشاشة']) {
        expect(guard.check(t).allowed, isTrue, reason: t);
      }
    });

    test('the idioms and place names are not flagged', () {
      expect(guard.check('يا حرام شو صار معه').allowed, isTrue);
      expect(guard.check('هاد ابن الحلال').allowed, isTrue);
      expect(guard.check('ولاد الحلال ساعدوني').allowed, isTrue);
      expect(guard.check('رحنا على المسجد الحرام').allowed, isTrue);
    });

    test('the plain word IS flagged in any other use (the strict side, documented)', () {
      expect(guard.check('اللحم حلال').allowed, isFalse);
      expect(guard.check('هذا حرام عليك').allowed, isFalse);
    });

    test('«يجوز» meaning "maybe" is flagged on purpose', () {
      expect(guard.check('يجوز يتأخر الباص').allowed, isFalse);
    });

    test('«قال الله» or «النبي» with no formula, and a name, are fine', () {
      expect(guard.check('زرت مدينة النبي الياس القديمة').allowed, isTrue);
    });

    test('English: "permitted" and "forbidden" alone are fine, "halal" is flagged', () {
      expect(guard.check('Parking is permitted here and the forbidden city is far').allowed, isTrue);
      expect(guard.check('a halal restaurant').allowed, isFalse);
    });
  });

  test('the index fails closed: it cannot be built from nothing, and a short text never throws', () {
    final empty = ReligiousOutputGuard(QuranVerseIndex.fromSurahs(const []));
    expect(empty.check('كلام عادي').allowed, isTrue);
    expect(guard.check('ا').allowed, isTrue);
    expect(QuranVerseIndex.wordsOf('  '), isEmpty);
  });
}
