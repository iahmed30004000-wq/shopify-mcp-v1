import 'package:flutter/material.dart';

import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_catalog.dart';
import '../domain/wird_engine.dart';
import '../domain/wird_plan.dart';

/// Texts about ayat, ranges, amounts and plans in the UI language (digits
/// through [MadarFormatter], so Arabic shows Arabic-Indic numerals). Used by
/// the screens and by the reminder texts built outside the widget tree.
class WirdTexts {
  WirdTexts(this.l, this.fmt, this.catalog) : arabic = l.localeName.startsWith('ar');

  factory WirdTexts.of(BuildContext context, QuranCatalog catalog) =>
      WirdTexts(L10n.of(context), MadarFormatter.of(context), catalog);

  final L10n l;
  final MadarFormatter fmt;
  final QuranCatalog catalog;
  final bool arabic;

  String surah(int surah) => catalog.surahName(surah, arabic: arabic);

  String number(int n) => fmt.formatInt(n, grouping: false);

  /// `البقرة ٢٥٥`.
  String ayah(AyahRef a) => l.wirdAyahRef(surah(a.surah), number(a.ayah));

  /// `البقرة ١٤٢–٢٠٢`, or `البقرة ٢٥٢ – آل عمران ٩٢` across surahs.
  String range(AyahRange r) {
    if (r.first == r.last) return ayah(r.first);
    if (r.first.surah == r.last.surah) {
      return l.wirdRangeSameSurah(surah(r.first.surah), number(r.first.ayah), number(r.last.ayah));
    }
    return l.wirdRangeCross(ayah(r.first), ayah(r.last));
  }

  /// `ص ٢٢–٤١`.
  String pages(AyahRange r) {
    final a = catalog.pageOf(r.first), b = catalog.pageOf(r.last);
    return a == b ? l.wirdPageSingle(number(a)) : l.wirdPageRange(number(a), number(b));
  }

  /// `٢٠ صفحة`, `صفحتان`, `٢٠٫١ صفحة`, `جزء واحد`, `١٠ آيات`.
  String amount(WirdUnit unit, double units) {
    final rounded = unit == WirdUnit.ayat ? units.roundToDouble() : (units * 10).roundToDouble() / 10;
    final whole = (rounded - rounded.roundToDouble()).abs() < 1e-9;
    if (whole) {
      final n = rounded.round();
      return fmt.localizeDigits(switch (unit) {
        WirdUnit.pages => l.wirdUnitPages(n),
        WirdUnit.juz => l.wirdUnitJuz(n),
        WirdUnit.hizb => l.wirdUnitHizb(n),
        WirdUnit.ayat => l.wirdUnitAyat(n),
      });
    }
    final s = fmt.formatNumber(rounded, maxDecimals: 1);
    return switch (unit) {
      WirdUnit.pages => l.wirdUnitPagesDecimal(s),
      WirdUnit.juz => l.wirdUnitJuzDecimal(s),
      WirdUnit.hizb => l.wirdUnitHizbDecimal(s),
      WirdUnit.ayat => fmt.localizeDigits(l.wirdUnitAyat(units.round())),
    };
  }

  String days(int n) => fmt.localizeDigits(l.wirdDays(n));

  String template(WirdTemplate t) => switch (t) {
    WirdTemplate.khatma => l.wirdTemplateKhatma,
    WirdTemplate.pages => l.wirdTemplatePages,
    WirdTemplate.juz => l.wirdTemplateJuz,
    WirdTemplate.hizb => l.wirdTemplateHizb,
    WirdTemplate.ayat => l.wirdTemplateAyat,
  };

  /// `ختمة في ٣٠ يومًا، ٢٠٫١ صفحة يوميًا` / `صفحتان يوميًا`.
  String summary(WirdPlan p) {
    final days = p.khatmaDays;
    if (days != null) return l.wirdSummaryKhatma(this.days(days), amount(WirdUnit.pages, p.amountPerDay));
    return l.wirdSummaryDaily(amount(p.unit, p.amountPerDay));
  }

  /// A name for a new plan.
  String defaultName(WirdTemplate t, {required int khatmaDays, required double amount}) => t == WirdTemplate.khatma
      ? l.wirdDefaultNameKhatma(days(khatmaDays))
      : l.wirdDefaultNameDaily(this.amount(t.unit, amount));

  String window(PrayerWindow? w) => wirdWindowLabel(l, w);

  /// Today's behind / ahead line (null when on schedule); [short] for
  /// compact cards.
  String? pace(WirdPlanState s, {bool short = false}) {
    final t = s.target;
    final unit = s.plan.unit;
    final threshold = unit == WirdUnit.ayat ? 1.0 : 0.25;
    if (t.behind >= threshold && !t.met) {
      final a = amount(unit, t.behind);
      if (short) return l.wirdBehindShort(a);
      return s.plan.meta.catchUp == WirdCatchUp.spread ? l.wirdBehindSpread(a) : l.wirdBehindAll(a);
    }
    if (t.ahead >= threshold) {
      return short ? l.wirdAheadShort(amount(unit, t.ahead)) : l.wirdAhead(amount(unit, t.ahead));
    }
    return null;
  }
}

/// `بعد العصر` / `After Asr`, `وقت الضحى`, `أي وقت`.
String wirdWindowLabel(L10n l, PrayerWindow? w) => switch (w) {
  null || PrayerWindow.anytime => l.wirdWindowAnytime,
  PrayerWindow.fajr => l.wirdWindowAfter(l.prayerFajr),
  PrayerWindow.duha => l.wirdWindowDuha,
  PrayerWindow.dhuhr => l.wirdWindowAfter(l.prayerDhuhr),
  PrayerWindow.asr => l.wirdWindowAfter(l.prayerAsr),
  PrayerWindow.maghrib => l.wirdWindowAfter(l.prayerMaghrib),
  PrayerWindow.isha => l.wirdWindowAfter(l.prayerIsha),
};

/// Colour-free label of a day's status (screen readers, legends).
String wirdDayStatusLabel(L10n l, WirdDayStatus s) => switch (s) {
  WirdDayStatus.met => l.wirdLegendMet,
  WirdDayStatus.partial => l.wirdLegendPartial,
  WirdDayStatus.missed => l.wirdLegendMissed,
  WirdDayStatus.rest => l.wirdLegendRest,
  WirdDayStatus.paused => l.wirdLegendPaused,
  WirdDayStatus.pending => l.wirdTodayTitle,
};
