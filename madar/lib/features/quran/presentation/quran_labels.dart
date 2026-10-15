import 'package:flutter/widgets.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/quran/ayah.dart';
import '../domain/quran_meta.dart';
import '../domain/tajweed.dart';

/// Localised names and labels of the Quran reader.
extension QuranLabels on L10n {
  bool get _arabic => localeName.startsWith('ar');

  /// Joins short facts: «مدنية، ٢٨٦ آية» / "Madani · 286 ayat" (a middle
  /// dot beside Arabic-Indic digits reads as a zero).
  String quranJoin(Iterable<String> parts) => parts.where((p) => p.isNotEmpty).join(_arabic ? '، ' : ' · ');

  /// `البقرة` / `Al-Baqarah`.
  String quranSurahName(SurahInfo s) => _arabic ? s.nameArabic : s.nameEnglish;

  /// `سورة البقرة` / `Surah Al-Baqarah`.
  String quranSurahFull(SurahInfo s) => quranSurahTitle(quranSurahName(s));

  /// `البقرة · الآية ٢٥٥` / `Al-Baqarah · Ayah 255`.
  String quranPlace(SurahInfo s, int ayah, MadarFormatter fmt) =>
      quranAyahOfSurah(quranSurahName(s), fmt.formatInt(ayah));

  /// `الحزب ٥` / `¼ Hizb 5` …
  String quranQuarterLabel(QuarterPosition q, MadarFormatter fmt) {
    final h = fmt.formatInt(q.hizb);
    return switch (q.quarter) {
      1 => quranHizbLabel(h),
      2 => quranQuarter1(h),
      3 => quranQuarter2(h),
      _ => quranQuarter3(h),
    };
  }

  /// `[البقرة: ٢٥٥]` / `(Al-Baqarah, ayah 255)`.
  String quranReference(SurahInfo s, AyahRef ref, MadarFormatter fmt) =>
      quranShareRef(quranSurahName(s), fmt.formatInt(ref.ayah));

  String quranRuleName(TajweedRule r) => switch (r) {
    TajweedRule.hamzatWasl => quranRuleHamzatWasl,
    TajweedRule.lamShamsiyyah => quranRuleLamShamsiyyah,
    TajweedRule.silent => quranRuleSilent,
    TajweedRule.maddNatural => quranRuleMaddNatural,
    TajweedRule.maddPermissible => quranRuleMaddPermissible,
    TajweedRule.maddSeparated => quranRuleMaddSeparated,
    TajweedRule.maddConnected => quranRuleMaddConnected,
    TajweedRule.maddNecessary => quranRuleMaddNecessary,
    TajweedRule.qalqalah => quranRuleQalqalah,
    TajweedRule.ghunnah => quranRuleGhunnah,
    TajweedRule.ikhfa => quranRuleIkhfa,
    TajweedRule.ikhfaShafawi => quranRuleIkhfaShafawi,
    TajweedRule.iqlab => quranRuleIqlab,
    TajweedRule.idghamGhunnah => quranRuleIdghamGhunnah,
    TajweedRule.idghamShafawi => quranRuleIdghamShafawi,
    TajweedRule.idghamNoGhunnah => quranRuleIdghamNoGhunnah,
    TajweedRule.idghamMutajanisayn => quranRuleIdghamMutajanisayn,
    TajweedRule.idghamMutaqaribayn => quranRuleIdghamMutaqaribayn,
  };

  String quranRuleHint(TajweedRule r) => switch (r) {
    TajweedRule.hamzatWasl => quranRuleHamzatWaslHint,
    TajweedRule.lamShamsiyyah => quranRuleLamShamsiyyahHint,
    TajweedRule.silent => quranRuleSilentHint,
    TajweedRule.maddNatural => quranRuleMaddNaturalHint,
    TajweedRule.maddPermissible => quranRuleMaddPermissibleHint,
    TajweedRule.maddSeparated => quranRuleMaddSeparatedHint,
    TajweedRule.maddConnected => quranRuleMaddConnectedHint,
    TajweedRule.maddNecessary => quranRuleMaddNecessaryHint,
    TajweedRule.qalqalah => quranRuleQalqalahHint,
    TajweedRule.ghunnah => quranRuleGhunnahHint,
    TajweedRule.ikhfa => quranRuleIkhfaHint,
    TajweedRule.ikhfaShafawi => quranRuleIkhfaShafawiHint,
    TajweedRule.iqlab => quranRuleIqlabHint,
    TajweedRule.idghamGhunnah => quranRuleIdghamGhunnahHint,
    TajweedRule.idghamShafawi => quranRuleIdghamShafawiHint,
    TajweedRule.idghamNoGhunnah => quranRuleIdghamNoGhunnahHint,
    TajweedRule.idghamMutajanisayn => quranRuleIdghamMutajanisaynHint,
    TajweedRule.idghamMutaqaribayn => quranRuleIdghamMutaqaribaynHint,
  };

  String quranFamilyName(TajweedFamily f) => switch (f) {
    TajweedFamily.silent => quranFamilySilent,
    TajweedFamily.madd => quranFamilyMadd,
    TajweedFamily.ghunnah => quranFamilyGhunnah,
    TajweedFamily.merge => quranFamilyMerge,
    TajweedFamily.qalqalah => quranFamilyQalqalah,
  };
}

/// The end-of-ayah sign with the ayah's number in Arabic-Indic digits,
/// «۝٢٥٥» – Amiri Quran draws the digits inside the ornament. The mushaf
/// keeps its own numerals whatever the interface digits are.
String quranAyahMark(int ayah) => '۝${Digits.toArabicIndic('$ayah')}';

/// Whether the reader is laid out for Arabic.
bool quranArabicUi(BuildContext context) => Localizations.localeOf(context).languageCode == 'ar';
