import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../prayer/domain/hijri.dart';
import '../../prayer/presentation/prayer_labels.dart';
import '../domain/last_ten_nights.dart';
import '../domain/ramadan_planner.dart';
import '../domain/ramadan_notification_ids.dart';

/// Localised texts of «رمضان» (the notifications, their channel, the screens)
/// with numbers in the user's digit style.
///
/// Built outside the widget tree too - the background isolate writes its "not
/// saved" notice in the language the notification was written in - so it never
/// reads a [BuildContext].
class RamadanTexts {
  RamadanTexts(this.l10n, this.fmt) {
    _ensureDateSymbols();
  }

  factory RamadanTexts.forLanguage(String languageCode, {DigitStyle digits = DigitStyle.auto}) => RamadanTexts(
    lookupL10n(Locale(languageCode == 'ar' ? 'ar' : 'en')),
    MadarFormatter(languageCode: languageCode, digits: digits),
  );

  factory RamadanTexts.of(BuildContext context) => RamadanTexts(L10n.of(context), MadarFormatter.of(context));

  static bool _dateSymbols = false;

  static void _ensureDateSymbols() {
    if (_dateSymbols) return;
    _dateSymbols = true;
    initializeDateFormatting();
  }

  final L10n l10n;
  final MadarFormatter fmt;

  // Numbers with their unit, in the user's digits ------------------------------

  String minutes(int n) => fmt.localizeDigits(l10n.ramadanMinutesCount(n));
  String days(int n) => fmt.localizeDigits(l10n.ramadanDaysCount(n));
  String pages(int n) => fmt.localizeDigits(l10n.ramadanPagesCount(n));
  String nights(int n) => fmt.localizeDigits(l10n.ramadanNightsCount(n));
  String rakaat(int n) => fmt.localizeDigits(l10n.ramadanRakaatCount(n));
  String number(int n) => fmt.formatInt(n, grouping: false);

  // Dates -------------------------------------------------------------------

  String weekday(DateTime day) => DateFormat('EEEE', fmt.languageCode).format(day);
  String gregorian(DateTime day) => fmt.formatDate(day, style: MadarDateStyle.dayMonth);
  String hijriDayMonth(HijriDate h) => l10n.hijriDayMonth(h, fmt);
  String hijriFull(HijriDate h) => l10n.hijriDate(h, fmt);

  /// «الاثنين · ٨ فبراير · ١ رمضان».
  String when(DateTime day, HijriDate h) => l10n.fastRemWhenDates(weekday(day), gregorian(day), hijriDayMonth(h));

  // Notifications -----------------------------------------------------------

  String title(PlannedRamadanReminder p) => switch (p.kind) {
    RamadanReminderKind.suhoor => l10n.ramadanNotifSuhoorTitle,
    RamadanReminderKind.iftar => l10n.ramadanNotifIftarTitle,
    RamadanReminderKind.taraweeh => l10n.ramadanNotifTaraweehTitle,
    RamadanReminderKind.lastTenNight => l10n.ramadanNotifLastTenTitle(number(p.number)),
    RamadanReminderKind.khatmah => l10n.ramadanTitle,
  };

  /// [clock] is the moment the reminder is about, already in the place's
  /// wall-clock time (the schedule's zone).
  String body(PlannedRamadanReminder p, DateTime clock) => switch (p.kind) {
    RamadanReminderKind.suhoor => l10n.ramadanNotifSuhoorBody(minutes(p.minutesBefore), fmt.formatTime(clock)),
    RamadanReminderKind.iftar => l10n.ramadanNotifIftarBody(minutes(p.minutesBefore), fmt.formatTime(clock)),
    RamadanReminderKind.taraweeh => l10n.ramadanNotifTaraweehBody(number(p.number)),
    RamadanReminderKind.lastTenNight =>
      LastTenNights.isOddSought(p.number)
          ? l10n.ramadanNotifLastTenOddBody(number(p.number))
          : l10n.ramadanNotifLastTenBody(number(p.number)),
    RamadanReminderKind.khatmah => '',
  };

  String get actionPrayed => l10n.ramadanNotifPrayed;
  String get channelGroup => l10n.ramadanChannelGroup;
  String get channelName => l10n.ramadanChannelName;
  String get channelDescription => l10n.ramadanChannelHint;
  String get failedTitle => l10n.ramadanFailedTitle;
  String get failedBody => l10n.ramadanFailedBody;
  String get runwayTitle => l10n.ramadanRunwayTitle;
  String get runwayBody => l10n.ramadanRunwayBody;
}
