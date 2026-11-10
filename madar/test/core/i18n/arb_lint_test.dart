// Lints every string part file (lib/core/i18n/arb_parts/*.json) – including
// other areas' parts – for the mistakes that break a bilingual RTL app:
// a missing English text (the merge would silently show Arabic), mismatched
// placeholders, incomplete Arabic plurals (zero/one/two/few/many/other),
// and digits typed straight into the text (they would ignore the user's
// Arabic-Indic / Western choice – digits belong in placeholders).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import 'icu.dart';

typedef _Entry = ({String file, String key, String ar, String? en, Set<String> placeholders});

List<_Entry> _entries() {
  final files =
      Directory('lib/core/i18n/arb_parts').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      for (final e in (jsonDecode(f.readAsStringSync()) as Map<String, dynamic>).entries)
        (
          file: f.uri.pathSegments.last,
          key: e.key,
          ar: (e.value as Map)['ar'] as String? ?? '',
          en: (e.value as Map)['en'] as String?,
          placeholders: {...?((e.value as Map)['placeholders'] as Map?)?.keys.cast<String>()},
        ),
  ];
}

final _western = RegExp('[0-9]');

/// Latin words that merely contain a digit – format and product names such as
/// MP3 or H264 – are names, not numbers.
final _latinWord = RegExp('[A-Za-z0-9]*[A-Za-z][A-Za-z0-9]*');
final _easternDigits = RegExp('[٠-٩۰-۹]');
final _arabicLetters = RegExp('[ء-ي]');

/// English strings that are deliberately written in Arabic (the language
/// picker names each language in its own script).
const _arabicInEnglish = {'settingsLanguageArabic'};

bool _has(IcuChoice p, String a, String b) => p.branches.containsKey(a) || p.branches.containsKey(b);

void main() {
  final entries = _entries();

  test('the part files hold strings', () {
    expect(entries.length, greaterThan(500));
  });

  test('every key is unique across the part files', () {
    final seen = <String, String>{};
    for (final e in entries) {
      expect(seen[e.key], isNull, reason: '${e.key} in ${e.file} and ${seen[e.key]}');
      seen[e.key] = e.file;
    }
  });

  test('every string has an Arabic and an English text', () {
    for (final e in entries) {
      expect(e.ar.trim(), isNotEmpty, reason: '${e.file} ${e.key}: no Arabic');
      expect(e.en, isNotNull, reason: '${e.file} ${e.key}: no English – the app would show Arabic in English');
      expect(e.en!.trim(), isNotEmpty, reason: '${e.file} ${e.key}: empty English');
    }
  });

  test('every message is well-formed ICU', () {
    for (final e in entries) {
      for (final s in [e.ar, e.en!]) {
        expect(() => parseIcu(s), returnsNormally, reason: '${e.file} ${e.key}: $s');
      }
    }
  });

  test('Arabic and English use exactly the declared placeholders', () {
    for (final e in entries) {
      final ar = icuArguments(parseIcu(e.ar));
      final en = icuArguments(parseIcu(e.en!));
      expect(ar, e.placeholders, reason: '${e.file} ${e.key} (ar)');
      // English may drop a pre-formatted number its grammar does not need
      // (e.g. "=1{a day}"), but never invent one.
      expect(e.placeholders.containsAll(en), isTrue, reason: '${e.file} ${e.key} (en uses $en)');
    }
  });

  test('Arabic plurals cover one, two, few, many and other', () {
    for (final e in entries) {
      for (final p in icuPlurals(parseIcu(e.ar))) {
        final where = '${e.file} ${e.key}';
        expect(p.branches.containsKey('other'), isTrue, reason: '$where: no other');
        expect(_has(p, '=1', 'one'), isTrue, reason: '$where: no =1/one (Arabic singular)');
        expect(_has(p, '=2', 'two'), isTrue, reason: '$where: no =2/two (Arabic dual)');
        // When the number is spelled out before a counted noun, 3–10 take
        // the plural and 11–99 the accusative singular: both are needed.
        final counted = p.branches.values.any((b) => icuArguments(b).isNotEmpty);
        if (counted) {
          expect(p.branches.containsKey('few'), isTrue, reason: '$where: no few (3–10)');
          expect(p.branches.containsKey('many'), isTrue, reason: '$where: no many (11–99)');
        }
      }
    }
  });

  test('English plurals cover one and other', () {
    for (final e in entries) {
      for (final p in icuPlurals(parseIcu(e.en!))) {
        expect(p.branches.containsKey('other'), isTrue, reason: '${e.file} ${e.key}');
        expect(_has(p, '=1', 'one'), isTrue, reason: '${e.file} ${e.key}');
      }
    }
  });

  test('no digits typed into the text (they would ignore the digit setting)', () {
    for (final e in entries) {
      for (final t in icuTexts(parseIcu(e.ar))) {
        expect(_western.hasMatch(t.replaceAll(_latinWord, '')), isFalse, reason: '${e.file} ${e.key} (ar): "$t"');
      }
      for (final t in icuTexts(parseIcu(e.en!))) {
        expect(_easternDigits.hasMatch(t), isFalse, reason: '${e.file} ${e.key} (en): "$t"');
      }
    }
  });

  test('no Arabic letters in English strings', () {
    for (final e in entries) {
      if (_arabicInEnglish.contains(e.key)) continue;
      expect(_arabicLetters.hasMatch(e.en!), isFalse, reason: '${e.file} ${e.key}: ${e.en}');
    }
  });

  group('Arabic plural forms in the generated localisations', () {
    final ar = lookupL10n(const Locale('ar'));
    final en = lookupL10n(const Locale('en'));

    test('tasks: zero, one, two, few (3–10), many (11–99), other (100–102)', () {
      final expected = {
        0: 'لا مهام بعد',
        1: 'مهمة واحدة',
        2: 'مهمتان',
        3: '3 مهام',
        10: '10 مهام',
        11: '11 مهمة',
        99: '99 مهمة',
        100: '100 مهمة',
        101: '101 مهمة',
        102: '102 مهمة',
        103: '103 مهام',
        111: '111 مهمة',
      };
      for (final e in expected.entries) {
        expect(ar.homeTasksCount(e.key), e.value, reason: '${e.key}');
      }
      expect(en.homeTasksCount(1), '1 task');
      expect(en.homeTasksCount(2), '2 tasks');
      expect(en.homeTasksCount(0), 'No tasks yet');
    });

    test('duration units agree with the number (دقيقة / دقيقتين / دقائق / دقيقة)', () {
      expect(ar.interactionDurationMinutes(1), 'دقيقة');
      expect(ar.interactionDurationMinutes(2), 'دقيقتين');
      expect(ar.interactionDurationMinutes(5), '5 دقائق');
      expect(ar.interactionDurationMinutes(15), '15 دقيقة');
      expect(ar.interactionDurationMinutes(120), '120 دقيقة');
    });

    test('a length limit agrees with its number (حرف / حرفان / أحرف / حرفًا / حرف)', () {
      expect(ar.interactionFieldTooLong(1), 'الحدّ الأقصى حرف واحد');
      expect(ar.interactionFieldTooLong(2), 'الحدّ الأقصى حرفان');
      expect(ar.interactionFieldTooLong(10), 'الحدّ الأقصى 10 أحرف');
      expect(ar.interactionFieldTooLong(80), 'الحدّ الأقصى 80 حرفًا');
      expect(ar.interactionFieldTooLong(200), 'الحدّ الأقصى 200 حرف');
      expect(en.interactionFieldTooLong(80), 'Keep it to 80 characters or fewer');
    });

    test('a unit shown after a formatted number follows the plural rules', () {
      expect(ar.designUnitDays(1), 'يوم');
      expect(ar.designUnitDays(2), 'يومان');
      expect(ar.designUnitDays(7), 'أيام');
      expect(ar.designUnitDays(30), 'يومًا');
      expect(ar.designUnitDays(365), 'يومًا'); // 365 ends in 65: 11–99 → many
      expect(ar.designUnitDays(300), 'يوم');
      expect(en.designUnitDays(1), 'day');
      expect(en.designUnitDays(7), 'days');
    });
  });
}
