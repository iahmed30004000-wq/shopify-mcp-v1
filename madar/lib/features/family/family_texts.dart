import 'dart:ui' show Locale;

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:intl/date_symbol_data_local.dart';

import '../../core/domain/enums.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/settings/app_settings.dart' show DigitStyle;
import 'domain/birthdays.dart';
import 'domain/family_models.dart';
import 'domain/family_reminders.dart';
import 'domain/rhythm.dart';

/// Every user-facing Family text, from the localisations and the digit
/// style: numbers in the user's digits, names bidi-isolated so a Latin name
/// never scrambles an Arabic sentence.
class FamilyTexts implements FamilyReminderTexts {
  const FamilyTexts(this.l, this.fmt);

  factory FamilyTexts.of(BuildContext context) => FamilyTexts(L10n.of(context), MadarFormatter.of(context));

  /// Texts outside the widget tree (notifications).
  factory FamilyTexts.forLanguage(String languageCode, {DigitStyle digits = DigitStyle.auto}) {
    if (!_dateSymbols) {
      _dateSymbols = true;
      initializeDateFormatting();
    }
    final lang = languageCode == 'en' ? 'en' : 'ar';
    return FamilyTexts(lookupL10n(Locale(lang)), MadarFormatter(languageCode: lang, digits: digits));
  }

  static bool _dateSymbols = false;

  final L10n l;
  final MadarFormatter fmt;

  bool get arabic => fmt.languageCode == 'ar';

  String _n(String s) => fmt.localizeDigits(s);

  @override
  String name(String name) => fmt.isolate(name.trim());

  String count(int n) => fmt.formatInt(n);

  // --------------------------------------------------------------- relation

  /// A stored relation: a suggestion key in the UI language, anything else
  /// as the user wrote it.
  String? relation(String? stored) {
    if (stored == null || stored.trim().isEmpty) return null;
    return switch (stored) {
      'father' => l.familyRelFather,
      'mother' => l.familyRelMother,
      'wife' => l.familyRelWife,
      'husband' => l.familyRelHusband,
      'son' => l.familyRelSon,
      'daughter' => l.familyRelDaughter,
      'brother' => l.familyRelBrother,
      'sister' => l.familyRelSister,
      'grandfather' => l.familyRelGrandfather,
      'grandmother' => l.familyRelGrandmother,
      'uncle' => l.familyRelUncle,
      'maternalUncle' => l.familyRelMaternalUncle,
      'aunt' => l.familyRelAunt,
      'maternalAunt' => l.familyRelMaternalAunt,
      'inLaw' => l.familyRelInLaw,
      'relative' => l.familyRelRelative,
      'friend' => l.familyRelFriend,
      'colleague' => l.familyRelColleague,
      'partner' => l.familyRelPartner,
      'neighbour' => l.familyRelNeighbour,
      'teacher' => l.familyRelTeacher,
      _ => stored.trim(),
    };
  }

  /// [stored]'s label for a person called [name], or null when the name
  /// already says it ("أمي" / "أخي أحمد" need no «أخي» next to them).
  String? relationBeside(String name, String? stored) {
    final label = relation(stored);
    if (label == null) return null;
    final n = BidiIsolate.strip(name).toLowerCase();
    return n.contains(label.toLowerCase()) ? null : label;
  }

  /// The suggestion key whose label (in either language) is [typed], so a
  /// typed «أمي» or "Mother" is stored as `mother`. Arabic marks are
  /// ignored: «جدتي» is «جدّتي».
  static String? relationKeyFor(String typed) {
    final t = _plain(typed);
    if (t.isEmpty) return null;
    for (final lang in const ['ar', 'en']) {
      final texts = FamilyTexts.forLanguage(lang);
      for (final k in FamilyRelations.keys) {
        if (_plain(texts.relation(k)!) == t) return k;
      }
    }
    return null;
  }

  /// Arabic short vowels, shadda, sukun and tatweel.
  static final RegExp _marks = RegExp('[\u064B-\u0652\u0640]');

  static String _plain(String s) => s.trim().toLowerCase().replaceAll(_marks, '');

  // ----------------------------------------------------------------- rhythm

  String rhythm(int? days) {
    final d = RhythmEngine.normalizeRhythm(days);
    return switch (d) {
      null => l.familyRhythmNone,
      7 => l.familyRhythmWeekly,
      14 => l.familyRhythmBiweekly,
      30 => l.familyRhythmMonthly,
      _ => _n(l.familyRhythmEvery(d)),
    };
  }

  /// "3 days overdue" / "Due today" / "Due in 4 days" / "No rhythm".
  String status(RhythmState s) => switch (s.status) {
    RhythmStatus.none => l.familyStatusNoRhythm,
    RhythmStatus.overdue => _n(l.familyStatusOverdue(s.daysOverdue)),
    RhythmStatus.dueToday => l.familyStatusDueToday,
    RhythmStatus.dueSoon || RhythmStatus.ok => _n(l.familyStatusDueIn(s.daysUntilDue!)),
  };

  /// "Last contact 5 days ago" / "No contact logged yet".
  String lastContact(RhythmState s) {
    final d = s.daysSinceContact;
    return d == null ? l.familyLastNever : _n(l.familyLastDaysAgo(d));
  }

  String inDays(int days) => _n(l.familyInDays(days));

  String daysAgo(int days) => _n(l.familyDaysAgo(days));

  String days(int days) => _n(l.familyDaysCount(days));

  String group(FamilyGroup g) => switch (g) {
    FamilyGroup.overdue => l.familyGroupOverdue,
    FamilyGroup.dueToday => l.familyGroupDueToday,
    FamilyGroup.thisWeek => l.familyGroupThisWeek,
    FamilyGroup.inTouch => l.familyGroupInTouch,
    FamilyGroup.noRhythm => l.familyGroupNoRhythm,
  };

  String channel(ContactChannel c) => switch (c) {
    ContactChannel.call => l.familyChannelCall,
    ContactChannel.visit => l.familyChannelVisit,
    ContactChannel.message => l.familyChannelMessage,
    ContactChannel.other => l.familyChannelOther,
  };

  // --------------------------------------------------------------- birthday

  String birthdayDate(DateTime birthday) {
    if (Birthdays.yearKnown(birthday)) return fmt.formatDate(birthday, style: MadarDateStyle.medium);
    return fmt.formatDate(DateTime(2000, birthday.month, birthday.day), style: MadarDateStyle.dayMonth);
  }

  String birthdayWhen(BirthdayInfo b) => b.isToday ? l.familyBirthdayTodayBadge : inDays(b.daysUntil);

  String? age(int? turning) => turning == null ? null : _n(l.familyAgeTurning(turning));

  String birthdayUpcoming(String personName, BirthdayInfo b) =>
      l.familyBirthdayUpcoming(name(personName), b.isToday ? l.familyWhenToday : inDays(b.daysUntil));

  // ------------------------------------------------------------ date / time

  /// "Today, 8:30 PM" / "Yesterday, …" / "Sunday 27 September, …".
  String when(DateTime at, DateTime now) {
    final d = CalendarDays.between(at, now);
    final day = switch (d) {
      0 => l.familyWhenToday,
      1 => l.familyWhenYesterday,
      _ when at.year == now.year => fmt.formatDate(at, style: MadarDateStyle.weekdayDayMonth),
      _ => fmt.formatDate(at, style: MadarDateStyle.medium),
    };
    return '$day${l.familyListSep}${fmt.formatTime(at)}';
  }

  String clock(int minutes) => fmt.formatClock(minutes ~/ 60, minutes % 60);

  String decimal(double v) => fmt.formatNumber(v, maxDecimals: 1);

  String percent(double v) => fmt.formatPercent(v);

  String joinNames(List<String> names) => names.join(l.familyListSep);

  // ---------------------------------------------------------- notifications

  @override
  String digestTitle(int count) => _n(l.familyDigestNotifyTitle(count));

  @override
  String digestBody(List<String> names, int more) {
    final list = [...names, if (more > 0) l.familyCardMore(count(more))];
    return l.familyDigestNotifyBody(joinNames(list));
  }

  @override
  String birthdayEveTitle(String name) => l.familyBirthdayEveTitle(name);

  @override
  String birthdayEveBody(int? turning) => [?age(turning), l.familyBirthdayEveBody].join(l.familyDot);

  @override
  String birthdayDayTitle(String name) => l.familyBirthdayDayTitle(name);

  @override
  String birthdayDayBody(int? turning) => [?age(turning), l.familyBirthdayDayBody].join(l.familyDot);
}
