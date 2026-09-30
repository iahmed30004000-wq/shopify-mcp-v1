import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/domain/enums.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/settings/app_settings.dart' show DigitStyle;
import 'domain/document_reminders.dart';
import 'domain/documents.dart';
import 'domain/packing.dart';
import 'domain/trip_timeline.dart';

/// Every travel text built from values: countdowns, date ranges, expiry
/// phrases, categories, warnings and notification texts – localised, in the
/// user's digits, names bidi-isolated.
class TravelTexts {
  TravelTexts(this.l, this.fmt);

  factory TravelTexts.of(BuildContext context) => TravelTexts(L10n.of(context), MadarFormatter.of(context));

  /// For notifications (no BuildContext).
  factory TravelTexts.forLanguage(String languageCode, {DigitStyle digits = DigitStyle.auto}) {
    _ensureDateSymbols();
    final lang = languageCode == 'en' ? 'en' : 'ar';
    return TravelTexts(lookupL10n(Locale(lang)), MadarFormatter(languageCode: lang, digits: digits));
  }

  static bool _dateSymbols = false;

  static void _ensureDateSymbols() {
    if (_dateSymbols) return;
    _dateSymbols = true;
    initializeDateFormatting();
  }

  final L10n l;
  final MadarFormatter fmt;

  String n(int v) => fmt.formatInt(v);

  /// A user-typed name, isolated so its punctuation stays with it.
  String name(String s) => fmt.isolate(s);

  // ------------------------------------------------------------- trips --

  String countdown(TripCountdown c) => switch (c.kind) {
    CountdownKind.undated => l.travelCountdownUndated,
    CountdownKind.startsIn =>
      c.days <= 0
          ? l.travelCountdownToday
          : c.days == 1
          ? l.travelCountdownTomorrow
          : l.travelCountdownIn(c.days, n(c.days)),
    CountdownKind.underway =>
      c.length == null
          ? l.travelCountdownDay(n(c.dayIndex))
          : l.travelCountdownDayOf(n(c.dayIndex), n(c.length!)),
    CountdownKind.ended => l.travelCountdownEnded(c.days, n(c.days)),
    CountdownKind.finished => l.travelCountdownFinished,
  };

  String days(int count) => l.travelDays(count, n(count));

  String status(TripStatus s) => switch (s) {
    TripStatus.planned => l.travelStatusPlanned,
    TripStatus.active => l.travelStatusActive,
    TripStatus.done => l.travelStatusDone,
  };

  /// "١٢ – ١٨ أكتوبر", "٣٠ سبتمبر – ٤ أكتوبر", with the year when it is not
  /// [now]'s; "١٢ أكتوبر · بلا موعد عودة" when open-ended.
  String dateRange(DateTime? start, DateTime? end, {required DateTime now}) {
    if (start == null && end == null) return l.travelCountdownUndated;
    final s = start ?? end!;
    final style = s.year == now.year && (end == null || end.year == now.year)
        ? MadarDateStyle.dayMonth
        : MadarDateStyle.medium;
    if (end == null) return '${fmt.formatDate(s, style: style)}${l.commonFactSeparator}${l.travelOpenEnded}';
    if (TravelDates.sameDay(s, end)) return fmt.formatDate(s, style: style);
    if (s.year == end.year && s.month == end.month && style == MadarDateStyle.dayMonth) {
      // "١٢ – ١٨ أكتوبر": the month once.
      final month = fmt.formatDate(end, style: MadarDateStyle.dayMonth);
      return '${fmt.formatInt(s.day, grouping: false)} – $month';
    }
    return '${fmt.formatDate(s, style: style)} – ${fmt.formatDate(end, style: style)}';
  }

  /// "+٢ ساعة" style offset from the phone, or "same time".
  String offsetFromPhone(Duration d) {
    if (d.inMinutes == 0) return l.travelTimeSame;
    final abs = d.abs();
    final h = abs.inHours;
    final m = abs.inMinutes % 60;
    final amount = m == 0
        ? l.travelHours(h, n(h))
        : l.travelHoursMinutes(BidiIsolate.ltr(fmt.localizeDigits('$h:${m.toString().padLeft(2, '0')}')));
    return d.isNegative ? l.travelTimeBehind(amount) : l.travelTimeAhead(amount);
  }

  // ----------------------------------------------------------- packing --

  String category(String? key) => switch (PackingCategories.of(key)) {
    PackingCategories.documents => l.travelCatDocuments,
    PackingCategories.clothes => l.travelCatClothes,
    PackingCategories.toiletries => l.travelCatToiletries,
    PackingCategories.health => l.travelCatHealth,
    PackingCategories.electronics => l.travelCatElectronics,
    PackingCategories.prayer => l.travelCatPrayer,
    PackingCategories.misc => l.travelCatMisc,
    final custom => name(custom),
  };

  String packedCount(PackingProgress p) => l.travelPackedCount(n(p.packed), n(p.total));

  String remaining(PackingProgress p) =>
      p.complete ? l.travelPackingAllDone : l.travelPackingRemaining(p.remaining, n(p.remaining));

  String templateItems(int count) => l.travelTemplateItems(count, n(count));

  // --------------------------------------------------------- documents --

  String kind(TravelDocKind k) => switch (k) {
    TravelDocKind.passport => l.travelDocKindPassport,
    TravelDocKind.visa => l.travelDocKindVisa,
    TravelDocKind.licence => l.travelDocKindLicence,
    TravelDocKind.id => l.travelDocKindId,
    TravelDocKind.insurance => l.travelDocKindInsurance,
    TravelDocKind.other => l.travelDocKindOther,
  };

  /// "Passport (Sara)" when a holder is recorded.
  String docTitle(DocFacts d) {
    final holder = d.holder?.trim();
    return holder == null || holder.isEmpty ? name(d.name) : l.travelDocWithHolder(name(d.name), name(holder));
  }

  /// "Expires in 43 days" / "in 5 months" / "in 2 years" / "today" /
  /// "expired 3 days ago".
  String expiry(DocumentExpiry e, {DateTime? on}) {
    final d = e.daysLeft;
    if (d == null) return l.travelNoExpiry;
    if (d == 0) return l.travelExpiresToday;
    if (d < 0) {
      final ago = -d;
      if (ago > 60 && on != null) return l.travelExpiredOn(fmt.formatDate(on));
      return l.travelExpiredAgo(ago, n(ago));
    }
    if (d < 60) return l.travelExpiresInDays(d, n(d));
    if (d < 730) {
      final months = (d / 30.44).floor();
      return l.travelExpiresInMonths(months, n(months));
    }
    final years = (d / 365.25).floor();
    return l.travelExpiresInYears(years, n(years));
  }

  /// The label of a "remind N days before" choice.
  String remindLabel(int days) => switch (days) {
    0 => l.travelRemindOnDay,
    7 => l.travelRemindWeek,
    14 => l.travelRemindTwoWeeks,
    30 => l.travelRemindMonth,
    60 => l.travelRemindTwoMonths,
    90 => l.travelRemindMonths(n(3)),
    180 => l.travelRemindMonths(n(6)),
    _ => l.travelRemindDays(days, n(days)),
  };

  /// Choices offered for the reminder (the current value included).
  static const remindChoices = [0, 7, 14, 30, 60, 90, 180];

  /// "••1234" – only the end of a document number is shown in lists.
  String maskedNumber(String number) {
    final clean = Digits.toWestern(number).replaceAll(RegExp(r'[^0-9A-Za-z\u0600-\u06FF]'), '');
    final tail = clean.length <= 4 ? clean : clean.substring(clean.length - 4);
    return l.travelDocNumberShort(BidiIsolate.ltr('••${fmt.localizeDigits(tail)}'));
  }

  String warning(TripDocumentWarning w) {
    final doc = docTitle(w.doc);
    final date = w.doc.expiry == null ? '' : fmt.formatDate(w.doc.expiry!, style: MadarDateStyle.medium);
    return switch (w.conflict) {
      DocumentConflict.beforeTrip => l.travelWarnBeforeTrip(doc, date),
      DocumentConflict.duringTrip => l.travelWarnDuringTrip(doc, date),
      DocumentConflict.validityShort => l.travelWarnValidity(doc, n(TravelDocumentChecks.passportValidityMonths)),
    };
  }

  // ------------------------------------------------------ notifications --

  ({String group, String name, String description}) get channel =>
      (group: l.travelNoticeGroup, name: l.travelNoticeChannel, description: l.travelNoticeChannelDescription);

  String noticeTitle(DocumentReminderPlan p) {
    final when = p.kind == DocumentReminderKind.onDay
        ? l.travelExpiresToday
        : expiry(DocumentExpiry(ExpiryState.soon, p.daysLeft));
    return l.travelNoticeTitle(docTitle(p.doc), when);
  }

  String noticeBody(DocumentReminderPlan p) => p.kind == DocumentReminderKind.onDay
      ? l.travelNoticeOnDayBody
      : l.travelNoticeAheadBody(fmt.formatDate(p.doc.expiry!, style: MadarDateStyle.medium));
}
