import 'package:flutter/material.dart' show MaterialLocalizations;
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../settings/app_settings.dart' show DigitStyle;
import 'gen/app_localizations.dart';

/// Digit conversion between Western (0-9), Arabic-Indic (٠-٩) and Persian
/// (۰-۹) digits. Pure – safe for any layer.
abstract final class Digits {
  static const String arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  static const String persian = '۰۱۲۳۴۵۶۷۸۹';

  /// Arabic decimal separator, thousands separator and percent sign.
  static const String arabicDecimal = '\u066B';
  static const String arabicGroup = '\u066C';
  static const String arabicPercent = '\u066A';

  /// Western → Arabic-Indic digits. A `.` or `,` that sits *between two
  /// digits* becomes the Arabic decimal / thousands separator and `%` after a
  /// digit becomes `٪`; punctuation elsewhere in the text is left alone.
  static String toArabicIndic(String input) {
    if (input.isEmpty) return input;
    final units = input.codeUnits;
    final out = StringBuffer();
    for (var i = 0; i < units.length; i++) {
      final c = units[i];
      if (_isWestern(c)) {
        out.writeCharCode(arabicIndic.codeUnitAt(c - 0x30));
      } else if ((c == 0x2E || c == 0x2C) &&
          i > 0 &&
          i + 1 < units.length &&
          _isAnyDigit(units[i - 1]) &&
          _isAnyDigit(units[i + 1])) {
        out.write(c == 0x2E ? arabicDecimal : arabicGroup);
      } else if (c == 0x25 && i > 0 && _isAnyDigit(units[i - 1])) {
        out.write(arabicPercent);
      } else {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }

  /// Western → Arabic-Indic digits only; every other character – dots
  /// included – is kept (version numbers and codes: `0.1.0` → `٠.١.٠`).
  static String toArabicIndicDigitsOnly(String input) {
    if (input.isEmpty) return input;
    final out = StringBuffer();
    for (final c in input.codeUnits) {
      out.writeCharCode(_isWestern(c) ? arabicIndic.codeUnitAt(c - 0x30) : c);
    }
    return out.toString();
  }

  /// Arabic-Indic / Persian → Western digits; `٫ ٬ ٪` become `. , %`.
  static String toWestern(String input) {
    if (input.isEmpty) return input;
    final out = StringBuffer();
    for (final c in input.codeUnits) {
      if (c >= 0x0660 && c <= 0x0669) {
        out.writeCharCode(0x30 + c - 0x0660);
      } else if (c >= 0x06F0 && c <= 0x06F9) {
        out.writeCharCode(0x30 + c - 0x06F0);
      } else if (c == 0x066B) {
        out.write('.');
      } else if (c == 0x066C) {
        out.write(',');
      } else if (c == 0x066A) {
        out.write('%');
      } else {
        out.writeCharCode(c);
      }
    }
    return out.toString();
  }

  /// Whether [text] contains any Arabic-Indic or Persian digit.
  static bool hasEasternDigits(String text) =>
      text.codeUnits.any((c) => (c >= 0x0660 && c <= 0x0669) || (c >= 0x06F0 && c <= 0x06F9));

  static bool _isWestern(int c) => c >= 0x30 && c <= 0x39;

  static bool _isAnyDigit(int c) => _isWestern(c) || (c >= 0x0660 && c <= 0x0669) || (c >= 0x06F0 && c <= 0x06F9);
}

/// Unicode bidi isolation for mixed Arabic / Latin text: wrapping an
/// embedded run keeps its internal order and stops it from reordering its
/// neighbours ("اتصل بـ John Smith الساعة ٣").
abstract final class BidiIsolate {
  /// FIRST STRONG ISOLATE – direction taken from the run's first strong char.
  static const String fsi = '\u2068';

  /// LEFT-TO-RIGHT ISOLATE.
  static const String lri = '\u2066';

  /// RIGHT-TO-LEFT ISOLATE.
  static const String rli = '\u2067';

  /// POP DIRECTIONAL ISOLATE – closes any of the three above.
  static const String pdi = '\u2069';

  /// Isolates [text] with its own first-strong direction (FSI … PDI).
  static String isolate(String text) => text.isEmpty ? text : '$fsi$text$pdi';

  /// Forces [text] to lay out left-to-right (LRI … PDI), e.g. codes, URLs.
  static String ltr(String text) => text.isEmpty ? text : '$lri$text$pdi';

  /// Forces [text] to lay out right-to-left (RLI … PDI).
  static String rtl(String text) => text.isEmpty ? text : '$rli$text$pdi';

  /// Removes every isolate / embedding control character (for comparisons,
  /// search and clipboard text).
  static String strip(String text) => text.replaceAll(_controls, '');

  /// The direction of [text]'s first strong character – what HTML's
  /// `dir="auto"` picks – or null when it has none (digits, symbols, empty).
  ///
  /// Follows the Unicode bidi rule P2: only letters are strong (Arabic-Indic
  /// digits, harakat, punctuation and emoji are not), LRM / RLM / ALM count,
  /// and text inside an isolate (FSI / LRI / RLI … PDI) is skipped – unless
  /// nothing outside one is strong, then the isolate's own text decides.
  ///
  /// Give it to a [Text] that shows the user's own words (task titles,
  /// names, notes), together with a `textAlign` that follows the UI, so that
  /// "Call Mum!" in an Arabic layout keeps its "!" at the end and an Arabic
  /// note in an English layout reads right to left.
  static TextDirection? directionOf(String text) => _firstStrong(text, skipIsolates: true) ?? _firstStrong(text);

  static TextDirection? _firstStrong(String text, {bool skipIsolates = false}) {
    var depth = 0;
    for (final rune in text.runes) {
      if (rune >= 0x2066 && rune <= 0x2068) {
        depth++;
        continue;
      }
      if (rune == 0x2069) {
        if (depth > 0) depth--;
        continue;
      }
      if (skipIsolates && depth > 0) continue;
      if (rune == 0x200F || rune == 0x061C) return TextDirection.rtl; // RLM, ALM
      if (rune == 0x200E) return TextDirection.ltr; // LRM
      if (rune < 0x41) continue; // ASCII digits, spaces and punctuation
      final c = String.fromCharCode(rune);
      if (!_letter.hasMatch(c)) continue;
      return _rtlScript.hasMatch(c) ? TextDirection.rtl : TextDirection.ltr;
    }
    return null;
  }

  /// Any letter (the strong bidi classes L, R and AL are letters).
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  /// Scripts written right to left.
  static final RegExp _rtlScript = RegExp(
    r'[\p{Script=Arabic}\p{Script=Hebrew}\p{Script=Syriac}\p{Script=Thaana}\p{Script=Nko}'
    r'\p{Script=Samaritan}\p{Script=Mandaic}\p{Script=Adlam}\p{Script=Hanifi_Rohingya}]',
    unicode: true,
  );

  static final RegExp _controls = RegExp('[\u2066-\u2069\u202A-\u202E\u200E\u200F]');
}

/// Date styles understood by [MadarFormatter.formatDate].
enum MadarDateStyle {
  /// "السبت ٢٧ سبتمبر ٢٠٢٦" / "Saturday, September 27, 2026".
  full,

  /// "٢٧ سبتمبر ٢٠٢٦" / "September 27, 2026".
  medium,

  /// "٢٧/٩/٢٠٢٦" / "9/27/2026".
  short,

  /// "٢٧ سبتمبر" / "September 27".
  dayMonth,

  /// "السبت ٢٧ سبتمبر" / "Saturday, September 27".
  weekdayDayMonth,
}

/// Locale- and [DigitStyle]-aware number, date, time and duration
/// formatting. Obtain the app's instance with `MadarFormatter.of(context)`
/// (or `context.formatter`); construct one directly in pure code and tests.
///
/// Numbers are always formatted with Western digits first and then converted
/// according to [digits], so the result never depends on the digit defaults
/// baked into intl's locale data.
@immutable
class MadarFormatter {
  const MadarFormatter({this.languageCode = 'ar', this.digits = DigitStyle.auto});

  final String languageCode;
  final DigitStyle digits;

  /// The formatter for [context]: locale from [Localizations], digit style
  /// from the nearest [MadarFormatScope] (auto when absent).
  factory MadarFormatter.of(BuildContext context) => MadarFormatter(
    languageCode: Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar',
    digits: MadarFormatScope.digitsOf(context),
  );

  bool get isArabic => languageCode == 'ar';

  /// Whether numbers are shown with Arabic-Indic digits.
  bool get arabicIndic => switch (digits) {
    DigitStyle.arabicIndic => true,
    DigitStyle.western => false,
    DigitStyle.auto => isArabic,
  };

  /// Converts every digit in [text] (and separators between digits) to the
  /// active digit style. Use on any pre-built string containing numbers,
  /// e.g. a pluralised l10n message.
  String localizeDigits(String text) => arabicIndic ? Digits.toArabicIndic(text) : Digits.toWestern(text);

  /// `1234` → `1,234` / `١٬٢٣٤`.
  String formatInt(int value, {bool grouping = true}) {
    final s = grouping ? NumberFormat('#,##0', 'en').format(value) : '$value';
    return localizeDigits(s);
  }

  /// A decimal number with at most [maxDecimals] fraction digits (trailing
  /// zeros dropped) or exactly [decimals] when given.
  String formatNumber(num value, {int? decimals, int maxDecimals = 2, bool grouping = true}) {
    final minD = decimals ?? 0;
    final maxD = decimals ?? maxDecimals;
    final f = NumberFormat.decimalPattern('en')
      ..minimumFractionDigits = minD
      ..maximumFractionDigits = maxD
      ..turnOffGrouping();
    var s = f.format(value);
    if (grouping) s = _group(s);
    return localizeDigits(s);
  }

  /// A fraction as a percentage: `0.42` → `42%` / `٤٢٪`.
  String formatPercent(double fraction, {int decimals = 0}) {
    final pct = formatNumber(fraction * 100, decimals: decimals, grouping: false);
    return arabicIndic ? '$pct${Digits.arabicPercent}' : '$pct%';
  }

  /// A calendar date in [style] with localised month / weekday names.
  String formatDate(DateTime date, {MadarDateStyle style = MadarDateStyle.medium}) {
    final pattern = switch (style) {
      MadarDateStyle.full => _dateFormat((l) => DateFormat.yMMMMEEEEd(l)),
      MadarDateStyle.medium => _dateFormat((l) => DateFormat.yMMMMd(l)),
      MadarDateStyle.short => _dateFormat((l) => DateFormat.yMd(l)),
      MadarDateStyle.dayMonth => _dateFormat((l) => DateFormat.MMMMd(l)),
      MadarDateStyle.weekdayDayMonth => _dateFormat((l) => DateFormat.MMMMEEEEd(l)),
    };
    return localizeDigits(pattern.format(date));
  }

  /// A clock time: `3:45 PM` / `٣:٤٥ م`.
  String formatTime(DateTime time) => localizeDigits(_dateFormat((l) => DateFormat.jm(l)).format(time));

  /// [formatTime] for an hour and minute of the day.
  String formatClock(int hour, int minute) => formatTime(DateTime(2000, 1, 1, hour, minute));

  /// A stopwatch-style duration: `1:05` (h:mm), or `5:03` (m:ss) with
  /// [seconds]. Negative durations are formatted by magnitude.
  String formatDuration(Duration duration, {bool seconds = false}) {
    final d = duration.isNegative ? -duration : duration;
    final String s;
    if (seconds) {
      final m = d.inMinutes;
      final sec = d.inSeconds.remainder(60);
      s = '$m:${sec.toString().padLeft(2, '0')}';
    } else {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      s = '$h:${m.toString().padLeft(2, '0')}';
    }
    return localizeDigits(s);
  }

  /// A duration in words: `١ س ٢٣ د` / `1h 23m`, `٤٠ د` / `40 min`, rounded
  /// up to whole minutes (a countdown never says "0 min" while time is left).
  String formatDurationWords(L10n l10n, Duration duration) {
    final d = duration.isNegative ? Duration.zero : duration;
    if (d == Duration.zero) return l10n.shellDurationLessThanMinute;
    final totalMinutes = (d.inSeconds + 59) ~/ 60;
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return l10n.shellDurationMinutes(formatInt(m));
    if (m == 0) return l10n.shellDurationHours(formatInt(h));
    return l10n.shellDurationHoursMinutes(formatInt(h), formatInt(m));
  }

  /// Wraps [text] in a first-strong isolate (see [BidiIsolate.isolate]).
  String isolate(String text) => BidiIsolate.isolate(text);

  /// A version number or dotted code in the active digits, separators kept
  /// and forced left-to-right (LRI … PDI): `0.1.0` → `٠.١.٠` / `0.1.0`.
  String formatVersion(String version) =>
      BidiIsolate.ltr(arabicIndic ? Digits.toArabicIndicDigitsOnly(version) : Digits.toWestern(version));

  DateFormat _dateFormat(DateFormat Function(String locale) build) {
    try {
      return build(languageCode);
    } catch (_) {
      // Locale data not loaded yet (ArgumentError / LocaleDataException in
      // pure unit tests before initializeDateFormatting); English patterns
      // are always available.
      return build('en');
    }
  }

  static String _group(String s) {
    final neg = s.startsWith('-');
    final body = neg ? s.substring(1) : s;
    final dot = body.indexOf('.');
    final intPart = dot < 0 ? body : body.substring(0, dot);
    final frac = dot < 0 ? '' : body.substring(dot);
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    return '${neg ? '-' : ''}$buf$frac';
  }

  @override
  bool operator ==(Object other) =>
      other is MadarFormatter && other.languageCode == languageCode && other.digits == digits;

  @override
  int get hashCode => Object.hash(languageCode, digits);
}

/// Provides the user's [DigitStyle] to [MadarFormatter.of]. The app shell
/// inserts it once above the navigator.
class MadarFormatScope extends StatelessWidget {
  const MadarFormatScope({super.key, required this.digits, required this.child});

  final DigitStyle digits;
  final Widget child;

  static DigitStyle digitsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MadarFormatInherited>()?.digits ?? DigitStyle.auto;

  @override
  Widget build(BuildContext context) {
    final scoped = _MadarFormatInherited(digits: digits, child: child);
    // Material's own number and date text – the calendar of a date field,
    // its month header – follows the digit style too (left to intl's `ar`
    // data, Material heads an Arabic calendar "سبتمبر ٢٠٢٦" over days
    // 1 … 30, whatever the user chose).
    final locale = Localizations.maybeLocaleOf(context);
    if (locale == null) return scoped;
    return Localizations.override(
      context: context,
      delegates: [
        MadarMaterialDigitsDelegate(
          arabicIndic: MadarFormatter(languageCode: locale.languageCode, digits: digits).arabicIndic,
        ),
      ],
      child: scoped,
    );
  }
}

class _MadarFormatInherited extends InheritedWidget {
  const _MadarFormatInherited({required this.digits, required super.child});

  final DigitStyle digits;

  @override
  bool updateShouldNotify(_MadarFormatInherited oldWidget) => oldWidget.digits != digits;
}

/// Material localisations whose digits follow the user's style. Material
/// formats with intl's plain language data – for Arabic that is Arabic-Indic
/// dates but Western numbers (a calendar headed "سبتمبر ٢٠٢٦" over days
/// 1 … 30) – so this rebuilds its formats with the digits chosen: dates with
/// or without native digits, numbers from Egyptian Arabic data (the same
/// grouping, with ٠–٩) or the plain language. An English UI with
/// Arabic-Indic digits keeps Western digits here (no English locale data
/// writes ٠–٩).
class MadarMaterialDigitsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const MadarMaterialDigitsDelegate({required this.arabicIndic});

  final bool arabicIndic;

  /// The intl locale Material's numbers are formatted with for [locale].
  Locale localeFor(Locale locale) =>
      arabicIndic && locale.languageCode == 'ar' ? const Locale('ar', 'EG') : Locale(locale.languageCode);

  static final Map<(String, bool), MaterialLocalizations> _cache = {};

  @override
  bool isSupported(Locale locale) => GlobalMaterialLocalizations.delegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    final lang = locale.languageCode;
    final hit = _cache[(lang, arabicIndic)];
    if (hit != null) return SynchronousFuture(hit);
    // Loads intl's date data (synchronously) and is the fallback.
    final plain = GlobalMaterialLocalizations.delegate.load(Locale(lang));
    final numbers = localeFor(locale).toString();
    if (!DateFormat.localeExists(lang) || !NumberFormat.localeExists(numbers)) return plain;
    DateFormat d(DateFormat f) => f..useNativeDigits = arabicIndic;
    final built = getMaterialTranslation(
      Locale(lang),
      d(DateFormat.y(lang)),
      d(DateFormat.yMd(lang)),
      d(DateFormat.yMMMd(lang)),
      d(DateFormat.MMMEd(lang)),
      d(DateFormat.yMMMMEEEEd(lang)),
      d(DateFormat.yMMMM(lang)),
      d(DateFormat.MMMd(lang)),
      NumberFormat.decimalPattern(numbers),
      NumberFormat('00', numbers),
    );
    if (built == null) return plain;
    return SynchronousFuture(_cache[(lang, arabicIndic)] = built);
  }

  @override
  bool shouldReload(MadarMaterialDigitsDelegate old) => old.arabicIndic != arabicIndic;
}

extension MadarFormatterContext on BuildContext {
  /// Shorthand for [MadarFormatter.of].
  MadarFormatter get formatter => MadarFormatter.of(this);
}
