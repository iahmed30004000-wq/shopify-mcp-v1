import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/domain/enums.dart';
import '../../../core/domain/money.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../money_glyphs.dart';
import 'domain/due_dates.dart';
import 'domain/goals_rates.dart';

/// Localised text for the goals package: money in the user's digits with
/// the currency's decimals, bidi-isolated so an amount never reorders the
/// sentence around it (and negative amounts keep their sign on the
/// reading side), dates, due-date phrases and recurrence names.
class GoalsTexts {
  const GoalsTexts(this.l, this.fmt, this.rates);

  factory GoalsTexts.of(BuildContext context, GoalsRates rates) =>
      GoalsTexts(L10n.of(context), MadarFormatter.of(context), rates);

  final L10n l;
  final MadarFormatter fmt;
  final GoalsRates rates;

  bool get arabic => fmt.languageCode.toLowerCase().startsWith('ar');

  MoneyDigits get _digits => fmt.arabicIndic ? MoneyDigits.arabicIndic : MoneyDigits.western;

  /// Decimals shown for an amount of [code]: always the currency's own
  /// (`٥٠٠٫٠٠٠ د.أ`, `87.500 JOD`, `$350.00`, `15,000 SYP`), as on every
  /// other Money screen: the hub, the ledger and the budget show the same
  /// amount the same way, and one card never mixes `112.50` with `25.715`.
  /// [milli] is kept for existing callers.
  int decimalsFor(int milli, String code) => rates.decimalsOf(code);

  /// `١٢٫٥٠٠ د.أ` / `12.500 JOD` / `$12.50`, wrapped in an isolate of the UI
  /// direction (see [decimalsFor]). [signed] adds `+` to positive amounts.
  String money(int milli, String currency, {bool signed = false}) {
    final code = currency.toUpperCase();
    final custom = _customSymbol(code);
    var s = MoneyGlyphs.legibleGroups(
      Money(
        milli,
        code,
      ).format(locale: fmt.languageCode, digits: _digits, decimals: decimalsFor(milli, code), symbol: custom),
    );
    if (signed && milli > 0) {
      // The same marks intl puts before a minus sign (ALM / LRM).
      final mark = !arabic ? '' : (fmt.arabicIndic ? '\u061C' : '\u200E');
      s = '$mark+$s';
    }
    return arabic ? BidiIsolate.rtl(s) : BidiIsolate.ltr(s);
  }

  /// [money] in the base currency.
  String base(int milli) => money(milli, rates.base);

  /// The amount alone (no symbol), for large display numbers.
  String amount(int milli, String currency) => MoneyGlyphs.legibleGroups(
    Money(
      milli,
      currency.toUpperCase(),
    ).formatAmount(locale: fmt.languageCode, digits: _digits, decimals: decimalsFor(milli, currency.toUpperCase())),
  );

  /// The symbol shown next to [amount].
  String symbol(String currency) {
    final code = currency.toUpperCase();
    return _customSymbol(code) ?? CurrencyCatalog.symbolFor(code, arabic: arabic);
  }

  /// The user's own symbol – only for currencies the catalogue does not
  /// know (a known code keeps its Arabic abbreviation / ISO code, so a JOD
  /// row seeded with `د.أ` still reads `JOD` in English).
  String? _customSymbol(String code) {
    if (CurrencyCatalog.knownCodes.contains(code)) return null;
    final custom = rates[code]?.symbol?.trim();
    return custom == null || custom.isEmpty ? null : custom;
  }

  String percent(double fraction) => fmt.formatPercent(fraction);

  String date(DateTime d, {MadarDateStyle style = MadarDateStyle.medium}) => fmt.formatDate(d, style: style);

  /// `٣ أكتوبر` / `Oct 3` style short date (with the year when it differs
  /// from [today]'s).
  String shortDate(DateTime d, DateTime today) =>
      fmt.formatDate(d, style: d.year == today.year ? MadarDateStyle.dayMonth : MadarDateStyle.medium);

  /// A date for big numerals: `Jun 1` / `١ يونيو`, with the year apart
  /// (`2027` / `٢٠٢٧`; null in [today]'s year) so it fits a stat tile.
  ({String dayMonth, String? year}) compactDate(DateTime d, DateTime today) {
    String format(DateFormat Function(String locale) build) {
      DateFormat f;
      try {
        f = build(fmt.languageCode);
      } catch (_) {
        f = build('en');
      }
      return fmt.localizeDigits(f.format(d));
    }

    return (dayMonth: format(DateFormat.MMMd), year: d.year == today.year ? null : format(DateFormat.y));
  }

  String _n(int n) => fmt.formatInt(n);

  /// "Today", "Tomorrow", "In 3 days", "2 days overdue", or the date when
  /// it is further than [maxDays] away.
  String dueRelative(DateTime due, DateTime today, {int maxDays = 14}) {
    final days = CalendarDays.between(today, due);
    if (days == 0) return l.goalsDueToday;
    if (days == 1) return l.goalsDueTomorrow;
    if (days < 0) return fmt.localizeDigits(l.goalsOverdueDays(-days, _n(-days)));
    if (days <= maxDays) return fmt.localizeDigits(l.goalsDueInDays(days, _n(days)));
    return l.goalsDueOn(shortDate(due, today));
  }

  /// "Every month", "Every 2 weeks", "Every year" …
  String recurrence(Recurrence frequency, int interval) {
    final n = interval < 1 ? 1 : interval;
    final text = switch (frequency) {
      Recurrence.weekly => l.goalsEveryWeeks(n, _n(n)),
      Recurrence.monthly => l.goalsEveryMonths(n, _n(n)),
      Recurrence.yearly => l.goalsEveryYears(n, _n(n)),
    };
    return fmt.localizeDigits(text);
  }

  /// "12 days left" / "باقٍ ١٢ يومًا".
  String daysLeft(int n) => fmt.localizeDigits(l.goalsDaysLeft(n, _n(n)));

  /// "Nothing due in the next 14 days".
  String nothingDue(int days) => fmt.localizeDigits(l.goalsNothingDue(days, _n(days)));

  /// A person's name or a user's title, isolated with its own direction.
  String user(String text) => BidiIsolate.isolate(text);
}

/// The abbreviated month of [d] (`Oct` / `أكتوبر`) in the formatter's
/// language and digits.
String goalsMonthShort(MadarFormatter fmt, DateTime d) {
  DateFormat f;
  try {
    f = DateFormat.MMM(fmt.languageCode);
  } catch (_) {
    f = DateFormat.MMM('en');
  }
  return fmt.localizeDigits(f.format(d));
}
