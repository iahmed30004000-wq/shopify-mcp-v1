/// Tolerant value parsers for prototype data (pure Dart): dates in many
/// shapes, clock times, booleans, numbers, lists and weekdays, all accepting
/// Arabic-Indic digits and Arabic words.
library;

import '../domain/money.dart' show MoneyText;
import 'import_text.dart';

/// Result of [ImportValues.times].
class ParsedTimes {
  const ParsedTimes(this.times, {this.inferred = const [], this.rejected = const []});

  /// `HH:mm`, in the order given, without duplicates.
  final List<String> times;

  /// Words turned into a default clock time (`morning` → 08:00).
  final List<String> inferred;

  /// Tokens that are not a time.
  final List<String> rejected;
}

abstract final class ImportValues {
  // ------------------------------------------------------------ scalars ---

  /// Trimmed non-empty text; numbers print without a trailing `.0`; lists of
  /// scalars are joined with `, `. Maps and booleans give null.
  static String? string(Object? v) {
    if (v == null || v is bool || v is Map) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    if (v is int) return '$v';
    if (v is double) return v == v.roundToDouble() && v.abs() < 1e15 ? '${v.toInt()}' : '$v';
    if (v is List) {
      final parts = [for (final e in v) ?string(e)];
      return parts.isEmpty ? null : parts.join(', ');
    }
    return v.toString();
  }

  /// A number from a num or localised text (`"5.4 mmol/L"`, `"٥٫٤"`).
  static double? number(Object? v) {
    if (v is num) return v.isFinite ? v.toDouble() : null;
    if (v is String) return MoneyText.parseNumber(v);
    return null;
  }

  /// [number] rounded to an int.
  static int? integer(Object? v) => number(v)?.round();

  static const _trueWords = {
    'true', 'yes', 'y', 't', 'on', 'done', 'ok', 'taken', 'completed', 'complete', 'checked', 'prayed', 'active', //
    'نعم', 'اي', 'ايوه', 'اجل', 'تم', 'صح', 'منجز', 'مكتمل', 'نشط', 'صليت', 'اخذت',
  };
  static const _falseWords = {
    'false', 'no', 'n', 'f', 'off', 'not done', 'missed', 'inactive', 'pending', //
    'لا', 'كلا', 'لم', 'لم يتم', 'غير منجز', 'فائت', 'فاتت',
  };

  /// A boolean from `true/false`, `1/0`, `yes/no`, `نعم/لا`, `✓/✗`, `done`…
  static bool? boolean(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is! String) return null;
    final raw = v.trim();
    if (raw == '✓' || raw == '✔' || raw == '☑' || raw == '✅') return true;
    if (raw == '✗' || raw == '✘' || raw == '☐' || raw == '❌') return false;
    final w = ImportText.words(raw);
    if (_trueWords.contains(w)) return true;
    if (_falseWords.contains(w)) return false;
    if (w == '1') return true;
    if (w == '0') return false;
    return null;
  }

  // -------------------------------------------------------------- dates ---

  static const _monthWords = <String, int>{
    'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3, 'apr': 4, 'april': 4, 'may': 5, //
    'jun': 6, 'june': 6, 'jul': 7, 'july': 7, 'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
    'يناير': 1, 'فبراير': 2, 'مارس': 3, 'ابريل': 4, 'مايو': 5, 'يونيو': 6, 'يونيه': 6, 'يوليو': 7, 'يوليه': 7,
    'اغسطس': 8, 'سبتمبر': 9, 'اكتوبر': 10, 'نوفمبر': 11, 'ديسمبر': 12,
    'شباط': 2, 'اذار': 3, 'نيسان': 4, 'ايار': 5, 'حزيران': 6, 'تموز': 7, 'اب': 8, 'ايلول': 9,
  };
  static const _monthPairs = <String, int>{
    'كانون ثاني': 1, 'كانون اول': 12, 'تشرين اول': 10, 'تشرين ثاني': 11, //
  };

  static final _ymd = RegExp(r'^(\d{4})[/.\-](\d{1,2})[/.\-](\d{1,2})(?:[ T,]+(.+))?$');
  static final _dmy = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})(?:[ T,]+(.+))?$');

  /// A local date-time from:
  /// * ISO 8601 (`2026-01-10`, `2026-01-10T08:30`, `…Z` → local),
  /// * epoch milliseconds or seconds (number or digit string), `yyyyMMdd`,
  /// * `yyyy/MM/dd`, `dd/MM/yyyy`, `dd-MM-yy`, `dd.MM.yyyy` (+ optional time;
  ///   day-first unless the first part is > 12 is impossible — i.e. `MM/dd`
  ///   is used only when the second part is > 12),
  /// * month names in English and Arabic (`10 Jan 2026`, `١٠ يناير ٢٠٢٦`,
  ///   `10 كانون الثاني 2026`), all with Arabic-Indic digits.
  static DateTime? date(Object? v) {
    if (v is DateTime) return v;
    if (v is num) return _fromNumber(v);
    if (v is! String) return null;
    final s = MoneyText.foldDigits(v).trim();
    if (s.isEmpty) return null;
    if (RegExp(r'^-?\d+$').hasMatch(s)) {
      if (s.length == 8) return _ymdChecked(int.parse(s.substring(0, 4)), int.parse(s.substring(4, 6)), int.parse(s.substring(6)));
      return _fromNumber(int.parse(s));
    }
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.isUtc ? iso.toLocal() : iso;
    var m = _ymd.firstMatch(s);
    if (m != null) {
      final d = _ymdChecked(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      return d == null ? null : _withTime(d, m[4]);
    }
    m = _dmy.firstMatch(s);
    if (m != null) {
      final a = int.parse(m[1]!), b = int.parse(m[2]!);
      var y = int.parse(m[3]!);
      if (m[3]!.length == 2) y += 2000;
      final (day, month) = a > 12 || b <= 12 ? (a, b) : (b, a);
      final d = _ymdChecked(y, month, day);
      return d == null ? null : _withTime(d, m[4]);
    }
    return _fromWords(s);
  }

  /// The local calendar day (`yyyy-MM-dd`) of [v], or null.
  static String? day(Object? v) {
    final d = date(v);
    return d == null ? null : dayKey(d);
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Whether [key] is a date (used to detect day-keyed maps).
  static bool isDateKey(String key) {
    final s = MoneyText.foldDigits(key).trim();
    if (s.length < 6) return false;
    if (RegExp(r'^\d+$').hasMatch(s) && s.length != 8) return false;
    return date(s) != null;
  }

  static DateTime? _fromNumber(num n) {
    if (!n.isFinite) return null;
    final a = n.abs();
    if (a >= 1e11) return DateTime.fromMillisecondsSinceEpoch(n.round());
    if (a >= 1e8) return DateTime.fromMillisecondsSinceEpoch((n * 1000).round());
    if (n is int && n >= 19000101 && n <= 21001231) {
      return _ymdChecked(n ~/ 10000, n ~/ 100 % 100, n % 100);
    }
    return null;
  }

  static DateTime? _ymdChecked(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > 2200) return null;
    final dt = DateTime(y, m, d);
    return dt.month == m && dt.day == d ? dt : null;
  }

  static DateTime _withTime(DateTime d, String? rest) {
    if (rest == null) return d;
    final minutes = _clock(rest.trim());
    return minutes == null ? d : DateTime(d.year, d.month, d.day, minutes ~/ 60, minutes % 60);
  }

  static DateTime? _fromWords(String s) {
    var w = ImportText.words(s);
    for (final e in _monthPairs.entries) {
      w = w.replaceAll(e.key, ' m${e.value} ');
    }
    int? month;
    final numbers = <String>[];
    String? clock;
    final clockMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(MoneyText.foldDigits(s));
    if (clockMatch != null) clock = clockMatch[0];
    final withoutClock = clockMatch == null ? w : w.replaceFirst(RegExp(r'\b\d{1,2} \d{2}\b'), ' ');
    for (final token in withoutClock.split(' ')) {
      if (token.isEmpty) continue;
      final pair = RegExp(r'^m(\d{1,2})$').firstMatch(token);
      if (pair != null) {
        month ??= int.parse(pair[1]!);
      } else if (_monthWords.containsKey(token)) {
        month ??= _monthWords[token];
      } else if (RegExp(r'^\d+$').hasMatch(token)) {
        numbers.add(token);
      } else {
        final stripped = token.replaceAll(RegExp(r'(st|nd|rd|th)$'), '');
        if (RegExp(r'^\d+$').hasMatch(stripped)) numbers.add(stripped);
      }
    }
    if (month == null) return null;
    final year = numbers.where((n) => n.length == 4).firstOrNull;
    final day = numbers.where((n) => n.length <= 2).firstOrNull;
    if (year == null || day == null) return null;
    final d = _ymdChecked(int.parse(year), month, int.parse(day));
    return d == null ? null : _withTime(d, clock);
  }

  // -------------------------------------------------------------- times ---

  static final _clockRe = RegExp(
    r'^(\d{1,2})(?:[:.h](\d{2}))?(?::\d{2})?\s*(am|pm|a\.m\.?|p\.m\.?|a|p|ص|م|صباحا|صباحاً|مساء|مساءً|مساءا)?$',
  );

  /// Minutes after midnight of one clock token (`08:00`, `8`, `8:30 pm`,
  /// `٨:٣٠ م`, `20h`, `0830`), or null.
  static int? _clock(String token) {
    var t = MoneyText.foldDigits(token).toLowerCase().trim();
    t = t.replaceAll(RegExp('[ً-ٟ]'), '');
    if (RegExp(r'^\d{3,4}$').hasMatch(t)) {
      final n = int.parse(t);
      final h = n ~/ 100, mm = n % 100;
      return h < 24 && mm < 60 ? h * 60 + mm : null;
    }
    final m = _clockRe.firstMatch(t.replaceAll(RegExp(r'h$'), ''));
    if (m == null) return null;
    var h = int.parse(m[1]!);
    final mm = int.tryParse(m[2] ?? '0') ?? 0;
    final suffix = m[3];
    if (mm > 59 || h > 24) return null;
    if (suffix != null) {
      final pm = suffix.startsWith('p') || suffix.startsWith('م');
      if (h > 12) return null;
      if (pm && h < 12) h += 12;
      if (!pm && h == 12) h = 0;
    }
    if (h == 24) h = 0;
    return h * 60 + mm;
  }

  /// `HH:mm` of one clock value, or null.
  static String? time(Object? v) {
    if (v is DateTime) return _hhmm(v.hour * 60 + v.minute);
    final parsed = times(v);
    return parsed.times.isEmpty ? null : parsed.times.first;
  }

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static const _wordTimes = <String, int>{
    'morning': 8 * 60, 'am': 8 * 60, 'breakfast': 8 * 60, 'noon': 12 * 60, 'midday': 12 * 60, 'lunch': 13 * 60, //
    'afternoon': 16 * 60, 'evening': 19 * 60, 'dinner': 19 * 60, 'pm': 19 * 60, 'night': 22 * 60, 'bedtime': 22 * 60,
    'صباح': 8 * 60, 'صباحا': 8 * 60, 'صبح': 8 * 60, 'فطور': 8 * 60, 'ظهر': 12 * 60, 'ظهرا': 12 * 60, 'غداء': 13 * 60,
    'عصر': 16 * 60, 'عصرا': 16 * 60, 'مساء': 19 * 60, 'مساءا': 19 * 60, 'عشاء': 19 * 60, 'ليل': 22 * 60,
    'ليلا': 22 * 60, 'نوم': 22 * 60, 'قبل نوم': 22 * 60,
  };

  static final _splitRe = RegExp(r'[,،;|\n/+]|\s+(?:and|&|و)\s+');

  /// Every clock time in [v]: a string (`"08:00, 20:00"`, `"8am و 8pm"`), a
  /// number (`8`, `20.5` → 20:30, `830` → 08:30), a list of those, or maps
  /// with a `time`/`at`/`hour` entry. Words such as `morning` / `صباحًا` /
  /// `bedtime` become default times and are listed in
  /// [ParsedTimes.inferred].
  static ParsedTimes times(Object? v) {
    final out = <String>[];
    final inferred = <String>[];
    final rejected = <String>[];
    void add(int minutes) {
      final s = _hhmm(minutes);
      if (!out.contains(s)) out.add(s);
    }

    void visit(Object? x) {
      if (x == null) return;
      if (x is DateTime) return add(x.hour * 60 + x.minute);
      if (x is List) return x.forEach(visit);
      if (x is Map) {
        for (final k in const ['time', 'at', 'hour', 'clock', 'وقت', 'الوقت', 'ساعة']) {
          if (x.containsKey(k)) return visit(x[k]);
        }
        return;
      }
      if (x is num) {
        if (!x.isFinite || x < 0) return rejected.add('$x');
        if (x < 24) return add((x * 60).round() % (24 * 60));
        final n = x.round();
        if (n >= 100 && n <= 2359 && n % 100 < 60) return add(n ~/ 100 * 60 + n % 100);
        return rejected.add('$x');
      }
      if (x is! String) return;
      final tokens = <String>[];
      for (final part in x.split(_splitRe)) {
        final p = part.trim();
        if (p.isEmpty) continue;
        final low = MoneyText.foldDigits(p).toLowerCase();
        final suffixOnly = RegExp(r'^(am|pm|a\.m\.?|p\.m\.?|ص|م|مساء|مساءً|صباحا|صباحاً)$').hasMatch(low);
        if (suffixOnly && tokens.isNotEmpty) {
          tokens[tokens.length - 1] = '${tokens.last} $p';
        } else {
          // "08:00 20:00" – whitespace between two clock tokens.
          final pieces = p.split(RegExp(r'\s+'));
          if (pieces.length > 1 && pieces.every((q) => _clock(q) != null)) {
            tokens.addAll(pieces);
          } else {
            tokens.add(p);
          }
        }
      }
      for (final token in tokens) {
        final c = _clock(token);
        if (c != null) {
          add(c);
          continue;
        }
        final w = ImportText.words(token);
        final word = _wordTimes[w] ?? _wordTimes[w.split(' ').last];
        if (word != null) {
          add(word);
          inferred.add(token);
        } else {
          rejected.add(token);
        }
      }
    }

    visit(v);
    return ParsedTimes(out, inferred: inferred, rejected: rejected);
  }

  // -------------------------------------------------------------- lists ---

  static final _listSplit = RegExp(r'[,،;|\n]');

  /// Strings from a list (maps contribute their name/label/title), or from
  /// text separated by `,`, `،`, `;`, `|` or new lines.
  static List<String> strings(Object? v) {
    if (v == null) return const [];
    if (v is List) {
      return [
        for (final e in v)
          if (e is Map) ?string(e['name'] ?? e['label'] ?? e['title'] ?? e['text'] ?? e['value']) else ?string(e),
      ];
    }
    if (v is Map) {
      // {"head": true, "back": false} → selected keys.
      return [
        for (final e in v.entries)
          if (boolean(e.value) ?? false) '${e.key}',
      ];
    }
    final s = string(v);
    if (s == null) return const [];
    return [
      for (final p in s.split(_listSplit))
        if (p.trim().isNotEmpty) p.trim(),
    ];
  }

  static const _weekdayWords = <String, int>{
    'mon': 1, 'monday': 1, 'tue': 2, 'tues': 2, 'tuesday': 2, 'wed': 3, 'wednesday': 3, 'thu': 4, 'thur': 4, //
    'thurs': 4, 'thursday': 4, 'fri': 5, 'friday': 5, 'sat': 6, 'saturday': 6, 'sun': 7, 'sunday': 7,
    'اثنين': 1, 'ثلاثاء': 2, 'اربعاء': 3, 'خميس': 4, 'جمعه': 5, 'سبت': 6, 'احد': 7,
  };

  /// ISO weekdays (1 = Monday … 7 = Sunday) from names (English / Arabic) or
  /// numbers. Numbers follow ISO unless a 0 appears, in which case the
  /// JavaScript convention (0 = Sunday … 6 = Saturday) is assumed.
  static List<int> weekdays(Object? v) {
    final items = v is List ? v : strings(v);
    final numbers = <int>[];
    final named = <int>[];
    for (final item in items) {
      if (item is num) {
        numbers.add(item.round());
        continue;
      }
      final s = string(item);
      if (s == null) continue;
      final n = int.tryParse(MoneyText.foldDigits(s).trim());
      if (n != null) {
        numbers.add(n);
        continue;
      }
      final w = ImportText.words(s).replaceAll(' ', '');
      final d = _weekdayWords[w] ?? _weekdayWords[w.length > 3 ? w.substring(0, 3) : w];
      if (d != null) named.add(d);
    }
    final js = numbers.contains(0);
    final out = <int>{
      ...named,
      for (final n in numbers)
        if (js && n >= 0 && n <= 6)
          n == 0 ? 7 : n
        else if (!js && n >= 1 && n <= 7)
          n,
    }.toList()..sort();
    return out;
  }

  // -------------------------------------------------------------- enums ---

  /// Looks [v] up in an alias table keyed by [ImportText.words]-normalised
  /// phrases: an exact phrase first, then the longest alias contained in
  /// the text as whole words (`"with breakfast please"` → `breakfast`).
  static T? enumOf<T>(Object? v, Map<String, T> aliases) {
    if (v is bool) return aliases[v ? 'true' : 'false'];
    final s = string(v);
    if (s == null) return null;
    final w = ImportText.words(s);
    if (w.isEmpty) return null;
    final exact = aliases[w] ?? aliases[w.replaceAll(' ', '')];
    if (exact != null) return exact;
    final padded = ' $w ';
    String? best;
    for (final alias in aliases.keys) {
      if (alias.length < 2) continue;
      if (padded.contains(' $alias ') && (best == null || alias.length > best.length)) best = alias;
    }
    return best == null ? null : aliases[best];
  }
}
