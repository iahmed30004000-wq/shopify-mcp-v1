import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart' show DigitStyle;
import 'center_models.dart';

/// The center's words in the UI language: group names, relative times and
/// durations (describers receive it to title each notification).
class CenterTexts {
  CenterTexts(this.l, this.fmt) {
    _ensureDateSymbols();
  }

  factory CenterTexts.of(BuildContext context) => CenterTexts(L10n.of(context), MadarFormatter.of(context));

  /// Outside the widget tree (tests, background code).
  factory CenterTexts.forLanguage(String languageCode, {DigitStyle digits = DigitStyle.auto}) => CenterTexts(
    lookupL10n(Locale(languageCode == 'ar' ? 'ar' : 'en')),
    MadarFormatter(languageCode: languageCode == 'ar' ? 'ar' : 'en', digits: digits),
  );

  final L10n l;
  final MadarFormatter fmt;

  static bool _symbols = false;

  static void _ensureDateSymbols() {
    if (_symbols) return;
    _symbols = true;
    // Compiled in: loads synchronously.
    initializeDateFormatting();
  }

  String get _locale => fmt.isArabic ? 'ar' : 'en';

  String group(NotificationGroup g) => switch (g) {
    NotificationGroup.prayer => l.ncGroupPrayer,
    NotificationGroup.adhkar => l.ncGroupAdhkar,
    NotificationGroup.medications => l.ncGroupMedications,
    NotificationGroup.health => l.ncGroupHealth,
    NotificationGroup.money => l.ncGroupMoney,
    NotificationGroup.family => l.ncGroupFamily,
    NotificationGroup.travel => l.ncGroupTravel,
    NotificationGroup.wird => l.ncGroupWird,
    NotificationGroup.customModules => l.ncGroupCustom,
    NotificationGroup.other => l.ncGroupOther,
  };

  /// A clock time in the device's zone.
  String time(DateTime instant) => fmt.formatTime(instant.toLocal());

  /// `١٠ د` / `10 min`, `١ س` / `1h` …
  String duration(Duration d) => fmt.formatDurationWords(l, d);

  /// A weekday name (`الخميس` / `Thursday`).
  String weekday(DateTime instant) => DateFormat.EEEE(_locale).format(instant.toLocal());

  /// When [at] is, relative to [now]: "in 25 min", "Today 5:48 PM",
  /// "Tomorrow 4:12 AM", "Thursday, 9:00 AM" – or, in the past, "25 min
  /// ago", "Yesterday 9:00 PM", "27 September, 9:00 AM".
  String when(DateTime at, DateTime now) {
    final diff = at.difference(now);
    final abs = diff.abs();
    if (abs < const Duration(minutes: 1)) return l.ncTimeNow;
    if (abs < const Duration(minutes: 60)) {
      final words = duration(abs);
      return diff.isNegative ? l.ncTimeAgo(words) : l.ncTimeIn(words);
    }
    final a = at.toLocal(), n = now.toLocal();
    final days = DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
    final clock = time(at);
    if (days == 0) return l.ncTimeToday(clock);
    if (days == 1) return l.ncTimeTomorrow(clock);
    if (days == -1) return l.ncTimeYesterday(clock);
    if (days > 1 && days < 7) return l.ncTimeOnDay(weekday(at), clock);
    return l.ncTimeOnDay(fmt.formatDate(a, style: MadarDateStyle.dayMonth), clock);
  }

  /// A mute's end: "5:48 PM" today, "Tomorrow 7:00 AM", "Thursday, 7:00 AM"…
  String until(DateTime end, DateTime now) {
    final a = end.toLocal(), n = now.toLocal();
    final sameDay = a.year == n.year && a.month == n.month && a.day == n.day;
    return sameDay ? time(end) : when(end, now);
  }

  String count(int n) => fmt.formatInt(n);
}
