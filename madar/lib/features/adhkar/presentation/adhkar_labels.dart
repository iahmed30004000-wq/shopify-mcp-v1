import 'package:flutter/material.dart';

import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../data/adhkar_providers.dart' show AdhkarDaySummary;
import '../domain/adhkar_models.dart';
import '../domain/tasbeeh.dart';

/// Localised names, hints and icons of the adhkar sets.
extension AdhkarLabels on L10n {
  String adhkarCategoryName(AdhkarCategoryId c) => switch (c) {
    AdhkarCategoryId.morning => adhkarCategoryMorning,
    AdhkarCategoryId.evening => adhkarCategoryEvening,
    AdhkarCategoryId.afterPrayer => adhkarCategoryAfterPrayer,
    AdhkarCategoryId.sleep => adhkarCategorySleep,
    AdhkarCategoryId.waking => adhkarCategoryWaking,
  };

  String adhkarCategoryShort(AdhkarCategoryId c) => switch (c) {
    AdhkarCategoryId.morning => adhkarShortMorning,
    AdhkarCategoryId.evening => adhkarShortEvening,
    AdhkarCategoryId.afterPrayer => adhkarShortAfterPrayer,
    AdhkarCategoryId.sleep => adhkarShortSleep,
    AdhkarCategoryId.waking => adhkarShortWaking,
  };

  String adhkarCategoryHint(AdhkarCategoryId c) => switch (c) {
    AdhkarCategoryId.morning => adhkarCategoryMorningHint,
    AdhkarCategoryId.evening => adhkarCategoryEveningHint,
    AdhkarCategoryId.afterPrayer => adhkarCategoryAfterPrayerHint,
    AdhkarCategoryId.sleep => adhkarCategorySleepHint,
    AdhkarCategoryId.waking => adhkarCategoryWakingHint,
  };

  String adhkarSuggestion(AdhkarCategoryId c, Prayer prayer) => switch (c) {
    AdhkarCategoryId.morning => adhkarSuggestMorning,
    AdhkarCategoryId.evening => adhkarSuggestEvening,
    AdhkarCategoryId.afterPrayer => adhkarSuggestAfterPrayer(adhkarPrayerName(prayer)),
    AdhkarCategoryId.sleep => adhkarSuggestSleep,
    AdhkarCategoryId.waking => adhkarSuggestWaking,
  };

  /// The line about the moment: the set that fits it, or that it is said.
  String adhkarMoment(AdhkarDaySummary s) {
    if (s.setsDone == AdhkarCategoryId.values.length) return adhkarSuggestAllDone;
    if (!s.suggestedDone) return adhkarSuggestion(s.suggested, s.suggestedPrayer);
    return s.suggested == AdhkarCategoryId.afterPrayer
        ? adhkarSuggestAfterPrayerDone(adhkarPrayerName(s.suggestedPrayer))
        : adhkarSuggestDone(s.suggested.name);
  }

  String adhkarPrayerName(Prayer p) => switch (p) {
    Prayer.fajr => prayerFajr,
    Prayer.dhuhr => prayerDhuhr,
    Prayer.asr => prayerAsr,
    Prayer.maghrib => prayerMaghrib,
    _ => prayerIsha,
  };

  /// A surah's name (the five the bundled adhkar quote; others by number).
  String adhkarSurahName(int surah, MadarFormatter fmt) => switch (surah) {
    2 => adhkarSurah2,
    3 => adhkarSurah3,
    112 => adhkarSurah112,
    113 => adhkarSurah113,
    114 => adhkarSurah114,
    _ => adhkarSurahNumber(fmt.formatInt(surah)),
  };

  /// «سورة البقرة: ٢٨٥–٢٨٦».
  String adhkarQuranReference(DhikrQuranSegment q, MadarFormatter fmt) {
    final ayahs = q.firstAyah == q.lastAyah
        ? fmt.formatInt(q.firstAyah, grouping: false)
        : '${fmt.formatInt(q.firstAyah, grouping: false)}–${fmt.formatInt(q.lastAyah, grouping: false)}';
    return adhkarQuranRef(adhkarSurahName(q.surah, fmt), ayahs);
  }

  /// English meaning of a built-in tasbeeh phrase (null for user phrases).
  String? adhkarPhraseGloss(TasbeehPhrase p) => switch (p.id) {
    'subhanallah' => adhkarPhraseSubhanallah,
    'alhamdulillah' => adhkarPhraseAlhamdulillah,
    'allahuakbar' => adhkarPhraseAllahuakbar,
    'tahlil' => adhkarPhraseTahlil,
    'istighfar' => adhkarPhraseIstighfar,
    'subhanallahWaBihamdihi' => adhkarPhraseSubhanallahWaBihamdihi,
    'subhanallahilAzim' => adhkarPhraseSubhanallahilAzim,
    'hawqala' => adhkarPhraseHawqala,
    'salawat' => adhkarPhraseSalawat,
    _ => null,
  };
}

/// The icon of a set.
IconData adhkarCategoryIcon(AdhkarCategoryId c) => switch (c) {
  AdhkarCategoryId.morning => Icons.wb_sunny_rounded,
  AdhkarCategoryId.evening => Icons.nights_stay_rounded,
  AdhkarCategoryId.afterPrayer => Icons.mosque_rounded,
  AdhkarCategoryId.sleep => Icons.bedtime_rounded,
  AdhkarCategoryId.waking => Icons.wb_twilight_rounded,
};
