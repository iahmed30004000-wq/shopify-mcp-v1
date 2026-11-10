import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../prayer/domain/hijri.dart';
import '../../prayer/presentation/prayer_labels.dart';
import '../domain/fasting_models.dart';
import '../domain/fasting_planner.dart';

/// Localised texts of «صيامي» (the notification, its channel, the screen)
/// with numbers in the user's digit style.
///
/// Built outside the widget tree too - the background isolate writes its
/// "not saved" notice in the language the notification was written in - so
/// it never reads a [BuildContext].
class FastingTexts {
  FastingTexts(this.l10n, this.fmt) {
    _ensureDateSymbols();
  }

  factory FastingTexts.forLanguage(String languageCode, {DigitStyle digits = DigitStyle.auto}) => FastingTexts(
    lookupL10n(Locale(languageCode == 'ar' ? 'ar' : 'en')),
    MadarFormatter(languageCode: languageCode, digits: digits),
  );

  factory FastingTexts.of(BuildContext context) => FastingTexts(L10n.of(context), MadarFormatter.of(context));

  static bool _dateSymbols = false;

  static void _ensureDateSymbols() {
    if (_dateSymbols) return;
    _dateSymbols = true;
    initializeDateFormatting();
  }

  final L10n l10n;
  final MadarFormatter fmt;

  // Names -------------------------------------------------------------------

  String kind(FastKind k) => switch (k) {
    FastKind.arafah => l10n.fastKindArafah,
    FastKind.ashura => l10n.fastKindAshura,
    FastKind.tasua => l10n.fastKindTasua,
    FastKind.dhuHijjahTen => l10n.fastKindTen,
    FastKind.sixShawwal => l10n.fastKindSix,
    FastKind.whiteDay => l10n.fastKindWhite,
    FastKind.monday => l10n.fastKindMonday,
    FastKind.thursday => l10n.fastKindThursday,
    FastKind.muharramMore => l10n.fastKindMuharram,
    FastKind.shabanMore => l10n.fastKindShaban,
  };

  /// «الاثنين» / "Monday".
  String weekday(DateTime day) => DateFormat('EEEE', fmt.languageCode).format(day);

  /// «١٦ ربيع الآخر» / "16 Rabiʿ al-Akhir".
  String hijriDayMonth(HijriDate h) => l10n.hijriDayMonth(h, fmt);

  /// «١٦ ربيع الآخر ١٤٤٨ هـ».
  String hijriFull(HijriDate h) => l10n.hijriDate(h, fmt);

  String gregorian(DateTime day) => fmt.formatDate(day, style: MadarDateStyle.dayMonth);

  /// «الاثنين · ٢٣ نوفمبر · ٤ جمادى الآخرة».
  String when(DateTime day, HijriDate h) =>
      l10n.fastRemWhenDates(weekday(day), gregorian(day), hijriDayMonth(h));

  // Notification ------------------------------------------------------------

  String title(FastKind k) => l10n.fastRemNotifTitle(kind(k));

  /// «بكرة الاثنين، ٤ جمادى الآخرة: ناوي تصوم؟», then the other fasts that
  /// fall on the same day, then a short line when Isha could not be worked
  /// out for that evening.
  String body(PlannedFastReminder p) {
    final r = p.reminder;
    final first = r.kind.isNudge
        ? l10n.fastRemNotifNudgeBody(weekday(r.day), hijriDayMonth(r.hijri))
        : l10n.fastRemNotifBody(weekday(r.day), hijriDayMonth(r.hijri));
    return [
      first,
      if (r.alsoKinds.isNotEmpty) l10n.fastRemNotifAlso(r.alsoKinds.map(kind).join(l10n.commonFactSeparator)),
      if (p.usedFallback) l10n.fastRemNotifFallback(fmt.formatTime(p.at)),
    ].join('\n');
  }

  String get actionYes => l10n.fastRemActionYes;
  String get actionNo => l10n.fastRemActionNo;
  String get channelGroup => l10n.fastRemTitle;
  String get channelName => l10n.fastRemChannelName;
  String get channelDescription => l10n.fastRemChannelHint;
  String get failedTitle => l10n.fastRemFailedTitle;
  String get failedBody => l10n.fastRemFailedBody;
  String get runwayTitle => l10n.fastRemRunwayTitle;
  String get runwayBody => l10n.fastRemRunwayBody;
}
