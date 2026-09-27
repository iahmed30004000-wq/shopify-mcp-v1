/// Quick-add natural-language parser (pure Dart, unit-tested).
///
/// Understands Jordanian / Levantine colloquial Arabic, MSA, English and
/// mixed input:
///
/// * "صرفت 12.5 دينار بنزين" → expense 12.5 JOD "بنزين"
/// * "بكرا بعد المغرب اجتماع مع فريق مصر" → task tomorrow, Maghrib window
/// * "tomorrow after isha call supplier" → contact (call) "supplier"
/// * "شرب ماء 500 مل", "ألم ظهر 6", "مزاجي 4" …
library;

import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../domain/enums.dart';
import '../numbers.dart';

/// What the user most likely wants to add.
enum QuickAddKind { task, expense, income, water, pain, mood, contact, note }

/// Structured result of [QuickAddParser.parse].
@immutable
class QuickAddIntent {
  const QuickAddIntent({
    required this.kind,
    required this.title,
    required this.raw,
    this.amountMilli,
    this.currency,
    this.unit,
    this.window,
    this.date,
    this.time,
    this.planetKey,
    this.channel,
    this.confidence = 0.5,
  });

  final QuickAddKind kind;

  /// What remains once amounts, dates, times and keywords are removed
  /// ("بنزين", "اجتماع مع فريق مصر", "supplier"). For pain it is the
  /// location/type ("ظهر", "صداع"); for contact the person.
  final String title;

  /// The input as typed.
  final String raw;

  /// Amount × 1000: money (in [currency]), water (in ml, so ml × 1000),
  /// pain score (0–10) or mood (1–5).
  final int? amountMilli;

  /// JOD / USD / SYP / EGP / LYD, or null when not stated.
  final String? currency;

  /// Unit of [amountMilli] when it is not money: `"ml"` for water.
  final String? unit;

  /// Prayer window ("after Asr", "before Maghrib" → Asr window …).
  final PrayerWindow? window;

  /// Day (local midnight) when explicitly stated; null otherwise – callers
  /// usually treat null as "today" when [time] or [window] is set.
  final DateTime? date;

  /// `"HH:mm"` when a clock time was stated.
  final String? time;

  /// Suggested planet (faith, health, family, work, money, growth, body,
  /// travel) or null.
  final String? planetKey;

  /// For [QuickAddKind.contact]: call / visit / message.
  final ContactChannel? channel;

  /// 0..1 – how sure the parser is about [kind] and its fields.
  final double confidence;

  double? get amount => amountMilli == null ? null : amountMilli! / 1000;

  /// Water amount in ml.
  int? get ml => kind == QuickAddKind.water && amountMilli != null ? (amountMilli! / 1000).round() : null;

  /// Pain (0–10) or mood (1–5) score.
  int? get score => (kind == QuickAddKind.pain || kind == QuickAddKind.mood) && amountMilli != null
      ? (amountMilli! / 1000).round()
      : null;

  bool get hasSchedule => date != null || time != null || window != null;

  /// [date] combined with [time] (or midnight), or null without a date.
  DateTime? get dateTime {
    final d = date;
    if (d == null) return null;
    final t = time;
    if (t == null) return d;
    final p = t.split(':');
    return DateTime(d.year, d.month, d.day, int.parse(p[0]), int.parse(p[1]));
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'title': title,
    'raw': raw,
    'amountMilli': amountMilli,
    'currency': currency,
    'unit': unit,
    'window': window?.name,
    'date': date?.toIso8601String(),
    'time': time,
    'planetKey': planetKey,
    'channel': channel?.name,
    'confidence': confidence,
  };

  @override
  bool operator ==(Object other) =>
      other is QuickAddIntent &&
      other.kind == kind &&
      other.title == title &&
      other.raw == raw &&
      other.amountMilli == amountMilli &&
      other.currency == currency &&
      other.unit == unit &&
      other.window == window &&
      other.date == date &&
      other.time == time &&
      other.planetKey == planetKey &&
      other.channel == channel &&
      other.confidence == confidence;

  @override
  int get hashCode =>
      Object.hash(kind, title, raw, amountMilli, currency, unit, window, date, time, planetKey, channel, confidence);

  @override
  String toString() => 'QuickAddIntent(${toJson()..removeWhere((k, v) => v == null || k == 'raw')})';
}

/// Parses free text typed into the quick-add bar.
abstract final class QuickAddParser {
  static QuickAddIntent parse(String input, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final clean = _clean(input);
    if (clean.isEmpty) {
      return QuickAddIntent(kind: QuickAddKind.task, title: '', raw: input, confidence: 0);
    }
    final s = _Scan(clean);

    // 1. Explicit prefixes ("note:", "ملاحظة:", "ذكرني").
    QuickAddKind? explicit;
    var stripLeadingBa = false;
    for (final (re, kind, ba) in _prefixes) {
      final m = s.first(re);
      if (m != null) {
        explicit = kind;
        stripLeadingBa = ba;
        s.take(m.start, m.end);
        break;
      }
    }

    // 2. Keyword scan (not consumed yet).
    final hits = <_Hit>[];
    if (explicit == null) {
      for (final rule in _rules) {
        final m = s.first(rule.re);
        if (m != null) hits.add(_Hit(rule, m));
      }
    }
    final prelim = hits
        .firstWhereOrNull((h) => h.rule.kind == QuickAddKind.pain || h.rule.kind == QuickAddKind.mood)
        ?.rule
        .kind;

    // 3. Dates, times, windows.
    // Scores like "7/10" are not dates when logging pain or mood.
    final date = _extractDate(s, today, scores: prelim != null);
    var window = date.tonight ? PrayerWindow.isha : null;
    var time = _extractTime(s);
    if (time != null && date.tonight && time.guessed) {
      final (h, m) = (int.parse(time.hhmm.substring(0, 2)), int.parse(time.hhmm.substring(3)));
      if (h < 12) time = (hhmm: _hhmm(h + 12, m), guessed: false);
    }
    window = _extractWindow(s, strict: prelim == QuickAddKind.pain, timeFound: time != null) ?? window;

    // 4. Money with an explicit currency.
    final money = _extractMoney(s);

    // 5. Resolve the kind.
    final resolved = _resolveKind(explicit, hits, money != null);
    final kind = resolved.kind;

    // 6. Kind-specific quantities.
    int? amountMilli = money?.milli;
    String? currency = money?.currency;
    String? unit;
    var quantityStated = money != null;
    var scoreFromWord = false;
    switch (kind) {
      case QuickAddKind.expense:
      case QuickAddKind.income:
        if (amountMilli == null) {
          final n = _extractBareNumber(s);
          if (n != null) {
            amountMilli = LocalizedNumbers.toMilli(n);
            quantityStated = true;
          }
        }
      case QuickAddKind.water:
        amountMilli = null;
        currency = null;
        unit = 'ml';
        final ml = _extractWater(s);
        quantityStated = ml != null;
        amountMilli = (ml ?? 250) * 1000;
      case QuickAddKind.pain:
        final n = _extractScore(s, max: 10) ?? _wordScore(s, _painWords);
        scoreFromWord = n != null && n.$2;
        quantityStated = n != null;
        amountMilli = n == null ? null : n.$1 * 1000;
        currency = null;
      case QuickAddKind.mood:
        final n = _extractMood(s) ?? _wordScore(s, _moodWords, consume: false);
        scoreFromWord = n != null && n.$2;
        quantityStated = n != null;
        amountMilli = n == null ? null : n.$1 * 1000;
        currency = null;
      case QuickAddKind.task:
      case QuickAddKind.contact:
      case QuickAddKind.note:
        break;
    }

    // 7. Consume the kind's keywords.
    for (final h in hits) {
      if (h.rule.kind == kind && h.rule.consume) {
        s.takeFree(h.match.start, h.match.end);
      }
    }

    // 8. Title.
    var title = _title(s.remainder());
    if (stripLeadingBa) {
      title = _stripPreposition(title, 'ب');
    } else if (kind == QuickAddKind.contact && resolved.hit != null) {
      title = _stripPreposition(title, _contactPrefixes(resolved.hit!.match.group(0)!));
    }

    // 9. Planet.
    final planet = _planet(kind, _fold(clean));

    // 10. Confidence.
    var c = resolved.base;
    switch (kind) {
      case QuickAddKind.expense:
      case QuickAddKind.income:
        c += amountMilli != null ? 0.1 : -0.35;
        if (currency != null) c += 0.04;
      case QuickAddKind.water:
        c += quantityStated ? 0.1 : -0.1;
      case QuickAddKind.pain:
      case QuickAddKind.mood:
        c += quantityStated ? (scoreFromWord ? 0.02 : 0.1) : -0.25;
      case QuickAddKind.task:
      case QuickAddKind.contact:
      case QuickAddKind.note:
        if (title.isEmpty) c -= 0.3;
        c += math.min(0.1, [date.value, time?.hhmm, window].nonNulls.length * 0.05);
    }
    if (time != null && time.guessed) c -= 0.05;

    return QuickAddIntent(
      kind: kind,
      title: title,
      raw: input,
      amountMilli: amountMilli,
      currency: currency,
      unit: unit,
      window: window,
      date: date.value,
      time: time?.hhmm,
      planetKey: planet,
      channel: kind == QuickAddKind.contact ? resolved.hit?.rule.channel : null,
      confidence: double.parse(c.clamp(0.05, 0.99).toStringAsFixed(2)),
    );
  }

  // -------------------------------------------------------------- text ----

  static final RegExp _diacritics = RegExp('[\\u064B-\\u065F\\u0670\\u0640\\u06D6-\\u06ED]');
  static final RegExp _bidi = RegExp('[\\u200B-\\u200F\\u202A-\\u202E\\u2066-\\u2069\\u061C\\uFEFF]', unicode: true);
  static final RegExp _spaces = RegExp(r'\s+');

  static String _clean(String input) =>
      input.replaceAll(_diacritics, '').replaceAll(_bidi, '').replaceAll(_spaces, ' ').trim();

  /// Folds text for matching without changing its length: digits → ASCII,
  /// alef/teh-marbuta/yeh variants unified, ASCII lower-cased.
  static String _fold(String s, {bool ascii = true}) {
    final digits = LocalizedNumbers.normalizeDigits(s);
    final out = StringBuffer();
    for (final c in digits.codeUnits) {
      out.writeCharCode(switch (c) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // آ أ إ ٱ → ا
        0x0629 => 0x0647, // ة → ه
        0x0649 || 0x0626 || 0x06CC => 0x064A, // ى ئ ی → ي
        0x0624 => 0x0648, // ؤ → و
        0x06A9 => 0x0643, // ک → ك
        0x060C => 0x2C, // ، → ,
        0x061B => 0x3B, // ؛ → ;
        0x061F => 0x3F, // ؟ → ?
        >= 0x41 && <= 0x5A when ascii => c + 32,
        _ => c,
      });
    }
    return out.toString();
  }

  static const _b = r'(?<![\p{L}\p{N}_])';
  static const _e = r'(?![\p{L}\p{N}_])';
  static const _num = r'\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:[.,]\d+)?';

  /// Regex over folded text; the pattern's Arabic letters are folded too
  /// (ASCII is left alone so escapes like `\p{L}` survive).
  static RegExp _re(String pattern) => RegExp(_fold(pattern, ascii: false), unicode: true);

  // ---------------------------------------------------------- prefixes ----

  static final List<(RegExp, QuickAddKind, bool)> _prefixes = [
    (_re(r'^(?:note|idea|memo|ملاحظة|فكرة|نوت)\s*(?:[:：\-–]\s*|\s+|$)'), QuickAddKind.note, false),
    (
      _re(r'^(?:task|todo|to-do|to do|مهمة|remind me to|remind me|ذكرني|ذكّرني)\s*(?:[:：\-–]\s*|\s+|$)'),
      QuickAddKind.task,
      true,
    ),
  ];

  // ------------------------------------------------------------- kinds ----

  static final String _curWords = [for (final c in _currencies) c.pattern].join('|');

  static final List<_Rule> _rules = [
    // Money – strong past-tense verbs.
    _Rule(
      QuickAddKind.expense,
      _re('$_b(?:و)?(?:صرفت|صرفنا|دفعت|دفعنا|اشتريت|اشترينا|شريت|شرينا|سددت|سددنا|spent|paid|bought|purchased)$_e'),
      strength: 3,
    ),
    _Rule(QuickAddKind.expense, _re('$_b(?:مصروف|مصاريف|مصروفات|expense|expenses)$_e'), strength: 2),
    _Rule(QuickAddKind.expense, _re('$_b(?:فاتورة|فواتير|bill|bills)$_e'), strength: 1, consume: false),
    // Imperatives are to-dos, even with an amount ("ادفع الإيجار 300 دينار").
    _Rule(
      QuickAddKind.task,
      _re('$_b(?:ادفع|اشتري|اشتر|سدد|حول|حوّل|pay|buy|purchase|transfer)$_e'),
      strength: 2,
      consume: false,
    ),
    _Rule(QuickAddKind.income, _re('$_b(?:و)?(?:قبضت|قبضنا|ربحت|كسبت|received|earned|got paid)$_e'), strength: 3),
    _Rule(
      QuickAddKind.income,
      _re('$_b(?:ال)?(?:راتب|معاش|salary|paycheck|income|bonus|مكافأة|refund)$_e'),
      strength: 2,
      consume: false,
    ),
    _Rule(QuickAddKind.income, _re('$_b(?:و)?(?:استلمت|وصلني|وصلتني|اجاني|جاني|اجتني|got)$_e'), strength: 0),
    // Health logs.
    _Rule(
      QuickAddKind.pain,
      _re('$_b(?:ال)?(?:ألم|آلام|اوجاع|وجع|اوجعني|بيوجعني|يوجعني|بوجعني|pain|ache|aches|aching|sore|hurts|hurt)$_e'),
      strength: 2,
    ),
    _Rule(
      QuickAddKind.pain,
      _re('$_b(?:ال)?(?:صداع|شقيقة|مغص|headache|migraine|cramps|cramp)$_e'),
      strength: 2,
      consume: false,
    ),
    _Rule(QuickAddKind.mood, _re('$_b(?:ال)?(?:مزاجي|مزاج|نفسيتي|نفسية|mood|feeling)$_e'), strength: 2),
    _Rule(QuickAddKind.water, _re('$_b(?:شربت|شرب|اشرب|نشرب|drank|drink|drinking)$_e'), strength: -1, drinkVerb: true),
    _Rule(
      QuickAddKind.water,
      _re('$_b(?:ال|و)?(?:ماء|مي|مية|مويه|موية|مياه|water)$_e(?!\\s*(?:$_curWords))'),
      strength: 2,
    ),
    // Contact.
    _Rule(
      QuickAddKind.contact,
      _re('$_b(?:و)?(?:اتصل|اتصلت|اتصال|تصل|رن|رنيت|رني|كلم|كلمت|حاكي|احكي مع|احكي|call|called|phone|ring)$_e'),
      strength: 2,
      channel: ContactChannel.call,
    ),
    _Rule(
      QuickAddKind.contact,
      _re('$_b(?:و)?(?:زور|زرت|زيارة|visit|visited)$_e'),
      strength: 2,
      channel: ContactChannel.visit,
    ),
    _Rule(
      QuickAddKind.contact,
      _re('$_b(?:و)?(?:ابعث|ابعتل|بعتت|ارسل|راسل|راسلت|text|texted|message|msg|email|whatsapp|واتساب|واتس)$_e'),
      strength: 2,
      channel: ContactChannel.message,
    ),
  ];

  static ({QuickAddKind kind, double base, _Hit? hit}) _resolveKind(
    QuickAddKind? explicit,
    List<_Hit> hits,
    bool hasCurrency,
  ) {
    if (explicit != null) return (kind: explicit, base: 0.92, hit: null);
    _Hit? find(QuickAddKind k, {int minStrength = 1}) =>
        hits.firstWhereOrNull((h) => h.rule.kind == k && h.rule.strength >= minStrength);
    final strongMoney = hits.firstWhereOrNull(
      (h) => (h.rule.kind == QuickAddKind.expense || h.rule.kind == QuickAddKind.income) && h.rule.strength >= 3,
    );
    if (strongMoney != null) return (kind: strongMoney.rule.kind, base: 0.85, hit: strongMoney);
    final imperative = find(QuickAddKind.task);
    if (imperative != null) return (kind: QuickAddKind.task, base: 0.72, hit: imperative);
    if (hasCurrency) {
      final income = find(QuickAddKind.income, minStrength: 0);
      return (kind: income != null ? QuickAddKind.income : QuickAddKind.expense, base: 0.74, hit: income);
    }
    for (final k in const [QuickAddKind.pain, QuickAddKind.mood, QuickAddKind.contact, QuickAddKind.water]) {
      final h = find(k);
      if (h != null) return (kind: k, base: 0.8, hit: h);
    }
    final noun = find(QuickAddKind.expense) ?? find(QuickAddKind.income);
    if (noun != null) return (kind: noun.rule.kind, base: 0.7, hit: noun);
    return (kind: QuickAddKind.task, base: 0.5, hit: null);
  }

  /// Prepositions a contact verb glues to the person ("اتصل بأبوي",
  /// "ابعث لأحمد").
  static String _contactPrefixes(String verb) {
    final v = verb.trim();
    if (RegExp(r'(?:اتصل|اتصلت|اتصال|تصل)$').hasMatch(v)) return 'ب';
    if (RegExp(r'(?:رن|رنيت|رني)$').hasMatch(v)) return 'بل';
    if (RegExp(r'(?:ابعث|ابعتل|بعتت|ارسل|راسل|راسلت)$').hasMatch(v)) return 'ل';
    return '';
  }

  // ------------------------------------------------------------- dates ----

  static final RegExp _dayAfter = _re(
    '$_b(?:و)?(?:بعد (?:بكرا|بكرة|بكره|بكرى|غدا|الغد)|(?:the )?day after tomorrow|overmorrow)$_e',
  );
  static final RegExp _tomorrow = _re(
    '$_b(?:و)?(?:بكرا|بكرة|بكره|بكرى|غدا|الغد|tomorrow|tmrw|tmr|tomorow|tommorow)$_e',
  );
  static final RegExp _today = _re('$_b(?:و)?(?:اليوم|هاليوم|النهارده|النهاردة|today|tonight|tonite)$_e');
  static final RegExp _yesterday = _re('$_b(?:و)?(?:امبارح|مبارح|أمس|البارحة|yesterday)$_e');
  static final RegExp _inDays = _re('$_b(?:بعد|in|within) (\\d{1,3}) ?(?:يوم|ايام|أيام|days?)$_e');
  static final RegExp _inTwoDays = _re('$_b(?:بعد يومين|in two days)$_e');
  static final RegExp _nextWeek = _re(
    '$_b(?:بعد (?:أسبوع|اسبوع|جمعة)|in a week|(?:ال)?(?:أسبوع|اسبوع) (?:الجاي|القادم|الياي)|next week)$_e',
  );
  static final RegExp _weekday = _re(
    '$_b(?:(?<pre>يوم|next|this|on|coming) )?(?<al>ال)?'
    '(?<d>سبت|أحد|احد|حد|اثنين|إثنين|اتنين|تنين|ثلاثاء|ثلاثا|تلاتا|تلات|أربعاء|اربعاء|أربعا|اربعا|خميس|جمعة|'
    'saturday|sunday|monday|tuesday|wednesday|thursday|friday|mon|tue|tues|wed|thu|thur|thurs|fri)'
    '(?: (?<post>الجاي|القادم|الياي|الجاية|القادمة|next))?$_e',
  );
  static final RegExp _dmy = _re('$_b(\\d{1,2}) ?/ ?(\\d{1,2})(?: ?/ ?(\\d{2,4}))?$_e');
  static final RegExp _iso = _re('$_b(\\d{4})-(\\d{1,2})-(\\d{1,2})$_e');

  static const Map<String, int> _weekdays = {
    'سبت': DateTime.saturday,
    'احد': DateTime.sunday,
    'حد': DateTime.sunday,
    'اثنين': DateTime.monday,
    'اتنين': DateTime.monday,
    'تنين': DateTime.monday,
    'ثلاثاء': DateTime.tuesday,
    'ثلاثا': DateTime.tuesday,
    'تلاتا': DateTime.tuesday,
    'تلات': DateTime.tuesday,
    'اربعاء': DateTime.wednesday,
    'اربعا': DateTime.wednesday,
    'خميس': DateTime.thursday,
    'جمعه': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'fri': DateTime.friday,
  };

  static ({DateTime? value, bool tonight}) _extractDate(_Scan s, DateTime today, {bool scores = false}) {
    DateTime plus(int days) => DateTime(today.year, today.month, today.day + days);
    for (final (re, days) in [(_dayAfter, 2), (_inTwoDays, 2), (_nextWeek, 7), (_tomorrow, 1), (_yesterday, -1)]) {
      final m = s.first(re);
      if (m != null) {
        s.take(m.start, m.end);
        return (value: plus(days), tonight: false);
      }
    }
    final inDays = s.first(_inDays);
    if (inDays != null) {
      s.take(inDays.start, inDays.end);
      return (value: plus(int.parse(inDays.group(1)!)), tonight: false);
    }
    final wd = s.first(_weekday, (m) {
      final name = m.namedGroup('d')!;
      final latin = RegExp('^[a-z]').hasMatch(name);
      if (latin) return true;
      final pre = m.namedGroup('pre');
      if (name == 'حد') return pre == 'يوم';
      return pre == 'يوم' || m.namedGroup('al') != null;
    });
    if (wd != null) {
      s.take(wd.start, wd.end);
      final target = _weekdays[wd.namedGroup('d')!]!;
      var delta = (target - today.weekday + 7) % 7;
      final next = wd.namedGroup('post') != null || wd.namedGroup('pre') == 'next';
      if (delta == 0 && next) delta = 7;
      return (value: plus(delta), tonight: false);
    }
    final iso = s.first(_iso);
    if (iso != null) {
      final d = _validDate(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
      if (d != null) {
        s.take(iso.start, iso.end);
        return (value: d, tonight: false);
      }
    }
    final dmy = s.first(_dmy, (m) => !scores || m.group(3) != null);
    if (dmy != null) {
      final y = dmy.group(3) == null ? today.year : int.parse(dmy.group(3)!);
      final d = _validDate(y < 100 ? 2000 + y : y, int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
      if (d != null) {
        s.take(dmy.start, dmy.end);
        return (value: d, tonight: false);
      }
    }
    final t = s.first(_today);
    if (t != null) {
      s.take(t.start, t.end);
      final word = t.group(0)!.trim();
      return (value: plus(0), tonight: word.contains('tonight') || word.contains('tonite'));
    }
    return (value: null, tonight: false);
  }

  static DateTime? _validDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final date = DateTime(y, m, d);
    return date.month == m && date.day == d ? date : null;
  }

  // ------------------------------------------------------------- times ----

  static const _am = r'الصبح|الصباح|صباحا|صبحا|الفجر|فجرا|am|a\.m\.?|in the morning|morning';
  static const _night = r'بالليل|الليل|ليلا|بليل|at night|tonight|night';
  static const _afternoon = r'العصر|عصرا|العصرية|in the afternoon|afternoon';
  static const _noon = r'بعد الظهر|الظهر|ظهرا|الضهر';
  static const _pm = r'المسا|مسا|المساء|مساء|مساءا|pm|p\.m\.?|in the evening|evening';
  static const _markers = '$_night|$_afternoon|$_noon|$_pm|$_am';
  static const _hourPrefix = r'(?:عال|على ال|ع ال|بال|ال)?ساعة ?';

  static final RegExp _timeColon = _re(
    '(?:$_b$_hourPrefix|${_b}at |@ ?)?(?<![\\p{N}.:/])(?<h>[01]?\\d|2[0-3]) ?: ?(?<m>[0-5]\\d)(?![\\p{N}])'
    '(?: ?(?<mk>$_markers|ص|م)$_e)?',
  );
  static final RegExp _timeArabic = _re(
    '$_b$_hourPrefix(?<h>\\d{1,2})(?![\\p{N}:])'
    '(?: ?(?:و ?)?(?<frac>نص|ربع|ثلث)$_e| ?(?:الا|إلا|غير) ?(?<minus>ربع|ثلث)$_e| ?و ?(?<mm>\\d{1,2}) ?(?:دقيقة|دقايق|دقائق|د)?$_e)?'
    '(?: ?(?<mk>$_markers|ص|م)$_e)?',
  );
  static final RegExp _timeAt = _re(
    '$_b(?:at|@) ?(?<h>\\d{1,2})(?:[.:](?<m>\\d{2}))?(?: ?(?<mk>am|pm|a\\.m\\.?|p\\.m\\.?|in the morning|in the evening|in the afternoon|at night|tonight))?$_e',
  );
  static final RegExp _timeMarked = _re('(?<![\\p{N}.:/])(?<h>\\d{1,2})(?:[.:](?<m>\\d{2}))? ?(?<mk>$_markers|ص|م)$_e');

  static ({String hhmm, bool guessed})? _extractTime(_Scan s) {
    for (final re in [_timeColon, _timeArabic, _timeAt, _timeMarked]) {
      final m = s.first(re, (m) => int.parse(m.namedGroup('h')!) <= 24);
      if (m == null) continue;
      var h = int.parse(m.namedGroup('h')!);
      var min = 0;
      if (re == _timeColon || re == _timeAt || re == _timeMarked) {
        final mm = m.namedGroup('m');
        if (mm != null) min = int.parse(mm);
      }
      if (re == _timeArabic) {
        final frac = m.namedGroup('frac');
        final minus = m.namedGroup('minus');
        final mm = m.namedGroup('mm');
        if (frac != null) min = _fraction(frac);
        if (mm != null) min = int.parse(mm).clamp(0, 59);
        if (minus != null) {
          h = (h - 1) % 24;
          min = 60 - _fraction(minus);
        }
      }
      final zeroPadded = re == _timeColon && m.namedGroup('h')!.length == 2 && h < 10;
      final resolved = _resolveHour(h, m.namedGroup('mk'), keepAsTyped: zeroPadded);
      s.take(m.start, m.end);
      return (hhmm: _hhmm(resolved.$1 % 24, min), guessed: resolved.$2);
    }
    return null;
  }

  static int _fraction(String f) => switch (f) {
    'نص' => 30,
    'ربع' => 15,
    _ => 20,
  };

  static bool _in(String? marker, String alternatives) =>
      marker != null && RegExp('^(?:${_fold(alternatives, ascii: false)})\$', unicode: true).hasMatch(marker);

  /// Resolves a 12-hour reading. Returns (hour, guessed).
  static (int, bool) _resolveHour(int h, String? marker, {bool keepAsTyped = false}) {
    if (h >= 13 || h == 0) return (h % 24, false);
    if (_in(marker, _am) || marker == 'ص') return (h == 12 ? 0 : h, false);
    if (_in(marker, _night)) {
      if (h == 12) return (0, false);
      return (h >= 6 ? h + 12 : h, false);
    }
    if (_in(marker, _noon)) return (h == 12 || h == 11 ? h : h + 12, false);
    if (_in(marker, _afternoon) || _in(marker, _pm) || marker == 'م') return (h == 12 ? 12 : h + 12, false);
    if (keepAsTyped) return (h, false);
    // No marker: 1–6 are almost always afternoon appointments.
    if (h >= 1 && h <= 6) return (h + 12, true);
    return (h, true);
  }

  static String _hhmm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  // ----------------------------------------------------------- windows ----

  static final RegExp _window = _re(
    '$_b(?:(?<rel>بعد|قبل|عند|وقت|مع|after|before|at|around|by) )?(?<salah>(?:صلاة|صلاه|صلات) )?(?<al>(?:و|ب|ف)?ال)?'
    '(?<w>فجر|ضحى|ضحي|ظهر|ضهر|عصر|مغرب|عشاء|عشا|fajr|fajer|duha|dhuhr|zuhr|duhr|zohr|asr|maghrib|magrib|isha|ishaa)'
    '(?: (?:prayer|salah))?$_e',
  );
  static final RegExp _morning = _re('$_b(?:(?:في|ب) )?(?:الصبح|الصباح|صباحا|this morning|in the morning|morning)$_e');
  static final RegExp _evening = _re(
    '$_b(?:(?:في|ب) )?(?:المسا|المساء|مساء|مساءا|this evening|in the evening|evening)$_e',
  );
  static final RegExp _nightWords = _re('$_b(?:بالليل|الليل|ليلا|at night|night)$_e');
  static final RegExp _noonWords = _re('$_b(?:الظهيرة|noon|midday|afternoon|this afternoon|in the afternoon)$_e');
  static final RegExp _anytime = _re('$_b(?:أي وقت|اي وقت|anytime|any time)$_e');

  static const Map<String, PrayerWindow> _windowNames = {
    'فجر': PrayerWindow.fajr,
    'fajr': PrayerWindow.fajr,
    'fajer': PrayerWindow.fajr,
    'ضحي': PrayerWindow.duha,
    'duha': PrayerWindow.duha,
    'ظهر': PrayerWindow.dhuhr,
    'ضهر': PrayerWindow.dhuhr,
    'dhuhr': PrayerWindow.dhuhr,
    'zuhr': PrayerWindow.dhuhr,
    'duhr': PrayerWindow.dhuhr,
    'zohr': PrayerWindow.dhuhr,
    'عصر': PrayerWindow.asr,
    'asr': PrayerWindow.asr,
    'مغرب': PrayerWindow.maghrib,
    'maghrib': PrayerWindow.maghrib,
    'magrib': PrayerWindow.maghrib,
    'عشاء': PrayerWindow.isha,
    'عشا': PrayerWindow.isha,
    'isha': PrayerWindow.isha,
    'ishaa': PrayerWindow.isha,
  };

  static PrayerWindow _before(PrayerWindow w) => switch (w) {
    PrayerWindow.fajr => PrayerWindow.isha,
    PrayerWindow.duha => PrayerWindow.fajr,
    PrayerWindow.dhuhr => PrayerWindow.duha,
    PrayerWindow.asr => PrayerWindow.dhuhr,
    PrayerWindow.maghrib => PrayerWindow.asr,
    PrayerWindow.isha => PrayerWindow.maghrib,
    PrayerWindow.anytime => PrayerWindow.anytime,
  };

  static PrayerWindow? _extractWindow(_Scan s, {required bool strict, required bool timeFound}) {
    final m = s.first(_window, (m) {
      final name = m.namedGroup('w')!;
      final latin = RegExp('^[a-z]').hasMatch(name);
      final rel = m.namedGroup('rel');
      final salah = m.namedGroup('salah') != null;
      if (strict) return (rel != null && !const ['at', 'by', 'مع'].contains(rel)) || salah;
      if (latin) return true;
      return rel != null || salah || m.namedGroup('al') != null;
    });
    if (m != null) {
      s.take(m.start, m.end);
      final w = _windowNames[m.namedGroup('w')!]!;
      final rel = m.namedGroup('rel');
      return rel == 'قبل' || rel == 'before' ? _before(w) : w;
    }
    if (timeFound) return null;
    for (final (re, w) in [
      (_anytime, PrayerWindow.anytime),
      (_morning, PrayerWindow.duha),
      (_evening, PrayerWindow.maghrib),
      (_nightWords, PrayerWindow.isha),
      (_noonWords, PrayerWindow.dhuhr),
    ]) {
      final x = s.first(re);
      if (x != null) {
        s.take(x.start, x.end);
        return w;
      }
    }
    return null;
  }

  // ------------------------------------------------------------- money ----

  static final List<_Currency> _currencies = [
    _Currency('LYD', r'دينار ليبي|دنانير ليبية|د\. ?ل|lyd|libyan dinars?'),
    _Currency('EGP', r'جنيه مصري|جنيهات مصرية|جنيهات|جنيه|ج\. ?م|egp|egyptian pounds?'),
    _Currency('SYP', r'ليرة سورية|ليرات سورية|ليرات|ليرة|ل\. ?س|syp|syrian pounds?|liras?|lira'),
    _Currency('USD', r'دولار أمريكي|دولار امريكي|دولارات|دولار|usd|us\$|dollars?|bucks?|\$'),
    _Currency(
      'JOD',
      r'دينار أردني|دينار اردني|دنانير أردنية|دنانير اردنية|دنانير|دينار|jod|jds?|dinars?|د\. ?أ|د\. ?ا',
    ),
    _Currency('JOD', r'قروش|قرش|قرشا|piasters?|piastres?', factor: 0.01),
    _Currency('JOD', r'فلس|fils', factor: 0.001),
  ];

  static const Map<String, (String, num)> _duals = {
    'دينارين': ('JOD', 2),
    'دولارين': ('USD', 2),
    'جنيهين': ('EGP', 2),
    'ليرتين': ('SYP', 2),
    'قرشين': ('JOD', 0.02),
  };

  static const Map<String, num> _numberWords = {
    'واحد': 1,
    'وحده': 1,
    'اثنين': 2,
    'اتنين': 2,
    'تنين': 2,
    'ثلاث': 3,
    'ثلاثه': 3,
    'تلات': 3,
    'تلاته': 3,
    'اربع': 4,
    'اربعه': 4,
    'خمس': 5,
    'خمسه': 5,
    'ست': 6,
    'سته': 6,
    'سبع': 7,
    'سبعه': 7,
    'ثمان': 8,
    'ثمانيه': 8,
    'تمن': 8,
    'تمنيه': 8,
    'تسع': 9,
    'تسعه': 9,
    'عشر': 10,
    'عشره': 10,
    'عشرين': 20,
    'ثلاثين': 30,
    'تلاتين': 30,
    'اربعين': 40,
    'خمسين': 50,
    'ميه': 100,
    'مئه': 100,
    'مائه': 100,
    'ميت': 100,
    'الف': 1000,
    'نص': 0.5,
    'نصف': 0.5,
    'ربع': 0.25,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'twenty': 20,
    'fifty': 50,
    'hundred': 100,
    'half': 0.5,
  };

  static final String _words = (_numberWords.keys.toList()..sort((a, b) => b.length.compareTo(a.length))).join('|');
  static final String _curGroup = '(?<cur>$_curWords)';
  static final RegExp _moneyAfter = _re(
    '(?<![\\p{N}.,])(?<num>$_num) ?(?<k>k|ألف|الف|آلاف|الاف|thousand)? ?$_curGroup$_e',
  );
  static final RegExp _moneyBefore = _re(
    '(?:$_b|(?<=\\s)|^)(?<cur>\\\$|us\\\$|usd|jod|jd|syp|egp|lyd) ?(?<num>$_num)(?<k>k)?(?![\\p{N}])',
  );
  static final RegExp _moneyWords = _re('$_b(?:و|ب)?(?<w>$_words) ?$_curGroup$_e');
  static final RegExp _moneyDual = _re('$_b(?:و|ب)?(?<d>${_duals.keys.join('|')})$_e');

  static ({int milli, String currency})? _extractMoney(_Scan s) {
    ({int milli, String currency})? build(num n, String curText, String? k) {
      final c = _currencies.firstWhereOrNull((c) => c.exact.hasMatch(curText.trim()));
      if (c == null) return null;
      final mult = (k != null && k.isNotEmpty) ? 1000 : 1;
      return (milli: LocalizedNumbers.toMilli(n * mult * c.factor), currency: c.code);
    }

    for (final re in [_moneyAfter, _moneyBefore]) {
      final m = s.first(re);
      if (m == null) continue;
      final n = LocalizedNumbers.parse(m.namedGroup('num')!);
      if (n == null) continue;
      final r = build(n, m.namedGroup('cur')!, m.namedGroup('k'));
      if (r == null) continue;
      s.take(m.start, m.end);
      return r;
    }
    final w = s.first(_moneyWords);
    if (w != null) {
      final r = build(_numberWords[w.namedGroup('w')!]!, w.namedGroup('cur')!, null);
      if (r != null) {
        s.take(w.start, w.end);
        return r;
      }
    }
    final d = s.first(_moneyDual);
    if (d != null) {
      final (code, n) = _duals[d.namedGroup('d')!]!;
      s.take(d.start, d.end);
      return (milli: LocalizedNumbers.toMilli(n), currency: code);
    }
    // A currency word alone ("دينار بنزين") → 1 unit.
    final lone = s.first(
      _re('$_b(?:ب)?(?<cur>دينار|دولار|ليرة|جنيه)$_e(?! ?(?:ليبي|سوري|مصري|أمريكي|امريكي|اردني|أردني))'),
    );
    if (lone != null) {
      final r = build(1, lone.namedGroup('cur')!, null);
      if (r != null) {
        s.take(lone.start, lone.end);
        return r;
      }
    }
    return null;
  }

  static final RegExp _bareNumber = _re('(?<![\\p{N}.,:/])(?<num>$_num)(?<k>k| ?ألف| ?الف)?(?![\\p{N}:/])');

  static num? _extractBareNumber(_Scan s) {
    final m = s.first(_bareNumber);
    if (m == null) return null;
    final n = LocalizedNumbers.parse(m.namedGroup('num')!);
    if (n == null) return null;
    s.take(m.start, m.end);
    return m.namedGroup('k') != null ? n * 1000 : n;
  }

  // ------------------------------------------------------------- water ----

  static const _ml = r'ml|مل|ملي|مللي|ميلي|ملل|ميليلتر|مليلتر|milliliters?|millilitres?';
  static const _litre = r'l|ltr|لتر|ليتر|لترات|ليترات|liters?|litres?';
  static const _glass = r'كاسة|كاسات|كاس|كوب|أكواب|اكواب|كوباية|كباية|glass|glasses|cups?';
  static const _bottle = r'قنينة|قناني|علبة|زجاجة|bottles?';
  static final RegExp _waterAmount = _re(
    '(?:(?<![\\p{N}.,])(?<num>$_num)|$_b(?<w>$_words|a|an)) ?(?<u>$_ml|$_litre|$_glass|$_bottle)$_e',
  );
  static final RegExp _waterDual = _re('$_b(?<d>لترين|ليترين|كاستين|كاسين|كوبين|قنينتين)$_e');
  static final RegExp _waterUnitAlone = _re('$_b(?:ب)?(?<u>$_litre|$_glass|$_bottle)$_e');

  static int _unitMl(String unit) {
    if (_in(unit, _ml)) return 1;
    if (_in(unit, _litre)) return 1000;
    if (_in(unit, _glass)) return 250;
    return 500;
  }

  static int? _extractWater(_Scan s) {
    final m = s.first(_waterAmount, (m) => m.namedGroup('num') != null || m.namedGroup('w') != null);
    if (m != null) {
      final numText = m.namedGroup('num');
      final word = m.namedGroup('w');
      final n = numText != null
          ? LocalizedNumbers.parse(numText)
          : (word == 'a' || word == 'an' ? 1 : _numberWords[word]);
      if (n != null) {
        s.take(m.start, m.end);
        return (n * _unitMl(m.namedGroup('u')!)).round();
      }
    }
    final d = s.first(_waterDual);
    if (d != null) {
      s.take(d.start, d.end);
      final w = d.namedGroup('d')!;
      if (w.startsWith('لت') || w.startsWith('ليت')) return 2000;
      if (w.startsWith('قن')) return 1000;
      return 500;
    }
    final u = s.first(_waterUnitAlone);
    if (u != null) {
      s.take(u.start, u.end);
      return _unitMl(u.namedGroup('u')!);
    }
    final bare = s.first(_bareNumber);
    if (bare != null) {
      final n = LocalizedNumbers.parse(bare.namedGroup('num')!);
      if (n != null && n > 0) {
        s.take(bare.start, bare.end);
        // "ماء 2" = litres, "ماء 500" = ml.
        return n < 10 ? (n * 1000).round() : n.round();
      }
    }
    return null;
  }

  // ------------------------------------------------------------ scores ----

  static final RegExp _score = _re('(?<![\\p{N}.,:/])(?<n>\\d{1,2})(?:\\.\\d+)?(?: ?/ ?(?<of>10|5))?(?![\\p{N}])');

  static (int, bool)? _extractScore(_Scan s, {required int max}) {
    final m = s.first(_score, (m) => int.parse(m.namedGroup('n')!) <= max);
    if (m == null) return null;
    s.take(m.start, m.end);
    return (int.parse(m.namedGroup('n')!), false);
  }

  static (int, bool)? _extractMood(_Scan s) {
    final m = s.first(_score, (m) => int.parse(m.namedGroup('n')!) <= 10);
    if (m == null) return null;
    s.take(m.start, m.end);
    final n = int.parse(m.namedGroup('n')!);
    final outOfTen = m.namedGroup('of') == '10' || n > 5;
    final v = outOfTen ? (n / 2).round() : n;
    return (v.clamp(1, 5), false);
  }

  static final Map<RegExp, int> _painWords = {
    _re('$_b(?:شديد|شديدة|قوي|قوية|كتير|severe|strong|bad)$_e'): 8,
    _re('$_b(?:متوسط|متوسطة|moderate)$_e'): 5,
    _re('$_b(?:خفيف|خفيفة|بسيط|بسيطة|mild|light|slight)$_e'): 3,
  };

  static final Map<RegExp, int> _moodWords = {
    _re('$_b(?:زفت|تعيس|تعيسة|awful|terrible|horrible)$_e'): 1,
    _re('$_b(?:تعبان|تعبانة|زعلان|زعلانة|مضايق|مخنوق|سيء|bad|sad|down|low)$_e'): 2,
    _re('$_b(?:عادي|ماشي|نص نص|ok|okay|fine|meh|so so)$_e'): 3,
    _re('$_b(?:منيح|منيحة|كويس|كويسة|حلو|جيد|مبسوط|مبسوطة|good|happy)$_e'): 4,
    _re('$_b(?:ممتاز|ممتازة|رائع|رائعة|فرحان|فرحانة|great|excellent|amazing|awesome)$_e'): 5,
  };

  static (int, bool)? _wordScore(_Scan s, Map<RegExp, int> words, {bool consume = true}) {
    for (final e in words.entries) {
      final m = s.first(e.key);
      if (m != null) {
        if (consume) s.take(m.start, m.end);
        return (e.value, true);
      }
    }
    return null;
  }

  // ------------------------------------------------------------- title ----

  static const Set<String> _connectors = {
    'on', 'for', 'at', 'in', 'to', 'the', 'a', 'an', 'of', 'and', 'with', 'from', 'by', 'about', //
    'علي', 'ع', 'عال', 'في', 'ب', 'بـ', 'ل', 'لـ', 'عشان', 'علشان', 'مشان', 'من', 'و', 'ف', 'الساعه', 'ساعه',
    'يوم', 'بقيمه', 'بمبلغ', 'مبلغ', 'قيمته', 'ثمن', 'حق', 'مع', 'الي', 'لل',
  };
  static final RegExp _punct = RegExp(r'^[\s,.:;!?\-–—،؛"\u0027()\[\]]+|[\s,.:;!?\-–—،؛"\u0027()\[\]]+$');

  static String _title(String remainder) {
    final words = remainder.split(' ').map((w) => w.replaceAll(_punct, '')).where((w) => w.isNotEmpty).toList();
    bool isConnector(String w) => _connectors.contains(_fold(w));
    while (words.isNotEmpty && isConnector(words.first)) {
      words.removeAt(0);
    }
    while (words.isNotEmpty && isConnector(words.last)) {
      words.removeLast();
    }
    return words.join(' ');
  }

  /// "بأبوي" → "أبوي", "للمورد" → "المورد", "لأحمد" → "أحمد" – only for the
  /// prepositions in [letters].
  static String _stripPreposition(String title, String letters) {
    if (title.isEmpty || letters.isEmpty) return title;
    final space = title.indexOf(' ');
    final first = space < 0 ? title : title.substring(0, space);
    final rest = space < 0 ? '' : title.substring(space);
    final f = _fold(first);
    if (f.length < 3) return title;
    String out = first;
    if (letters.contains('ل') && f.startsWith('لل')) {
      out = 'ا${first.substring(1)}';
    } else if (letters.contains(f[0])) {
      out = first.substring(1);
    }
    return '$out$rest'.trim();
  }

  // ------------------------------------------------------------ planet ----

  static final List<(String, RegExp)> _planetWords = [
    (
      'faith',
      _re(
        '$_b(?:و|ب|ل|لل)?(?:ال)?(?:صلاة|قرآن|قران|أذكار|اذكار|مسجد|جامع|صدقة|صيام|صوم|عمرة|حج|دعاء|تهجد|قيام|ختمة|تلاوة|quran|mosque|charity|sadaqah|dua|prayer|fasting|umrah)$_e',
      ),
    ),
    (
      'health',
      _re(
        '$_b(?:و|ب|ل|لل)?(?:ال)?(?:دكتور|دكتورة|طبيب|دواء|دوا|علاج|صيدلية|تحليل|تحاليل|مستشفى|عيادة|أسنان|اسنان|doctor|medicine|meds|pharmacy|clinic|hospital|lab|dentist|checkup)$_e',
      ),
    ),
    (
      'body',
      _re(
        '$_b(?:و|ب|ل|لل)?(?:ال)?(?:رياضة|جيم|نادي|مشي|تمرين|تمارين|ركض|جري|سباحة|يوغا|gym|workout|run|running|walk|exercise|training|swim|yoga|steps)$_e',
      ),
    ),
    (
      'travel',
      _re(
        '$_b(?:و|ب|ل|لل)?(?:ال)?(?:سفر|سفرة|طيارة|طيران|رحلة|فندق|تذكرة|تذاكر|مطار|جواز|فيزا|flight|trip|hotel|airport|passport|visa|travel)$_e',
      ),
    ),
    (
      'work',
      _re(
        '$_b(?:و|ب|ل|لل)?(?:ال)?(?:اجتماع|ميتنج|ميتينج|فريق|مشروع|عميل|عملاء|زبون|زباين|مورد|موردين|شغل|دوام|مدير|مديري|تقرير|مكتب|meeting|team|project|client|customer|supplier|vendor|boss|manager|report|office|work|deadline|invoice|presentation|standup)$_e',
      ),
    ),
    (
      'family',
      _re(
        '$_b(?:و|ب|ل|لل)?(?:أبوي|ابوي|ابويا|بابا|أبي|امي|أمي|ماما|يما|اخوي|أخوي|اخي|أخي|اختي|أختي|خيتي|اخواني|اخواتي|زوجتي|مرتي|جوزي|زوجي|ابني|بنتي|ولادي|اولادي|عمي|عمتي|خالي|خالتي|جدي|جدتي|ستي|سيدي|نسايبي|حماي|حماتي|العيلة|عيلتي|اهلي|أهلي|dad|father|mom|mum|mother|brother|sister|wife|husband|son|daughter|uncle|aunt|grandma|grandpa|grandmother|grandfather|family|parents|kids)$_e',
      ),
    ),
    (
      'growth',
      _re(
        '$_b(?:و|ب|ل|لل)?(?:ال)?(?:كتاب|قراءة|اقرأ|اقرا|دورة|كورس|تعلم|اتعلم|ادرس|دراسة|درس|محاضرة|book|read|reading|course|study|learn|lesson|lecture|class)$_e',
      ),
    ),
    (
      'money',
      _re(
        '$_b(?:و|ب|ل|لل)?(?:ال)?(?:بنك|فاتورة|فواتير|إيجار|ايجار|قسط|تحويل|bank|bill|rent|loan|installment|transfer|budget)$_e',
      ),
    ),
  ];

  static String? _planet(QuickAddKind kind, String folded) {
    switch (kind) {
      case QuickAddKind.expense:
      case QuickAddKind.income:
        return 'money';
      case QuickAddKind.water:
      case QuickAddKind.pain:
      case QuickAddKind.mood:
        return 'health';
      case QuickAddKind.contact:
        for (final key in const ['family', 'work']) {
          if (_planetWords.firstWhere((p) => p.$1 == key).$2.hasMatch(folded)) return key;
        }
        return null;
      case QuickAddKind.task:
      case QuickAddKind.note:
        for (final (key, re) in _planetWords) {
          if (re.hasMatch(folded)) return key;
        }
        return null;
    }
  }
}

class _Currency {
  _Currency(this.code, String pattern, {this.factor = 1})
    : pattern = QuickAddParser._fold(pattern, ascii: false),
      exact = RegExp('^(?:${QuickAddParser._fold(pattern, ascii: false)})\$', unicode: true);
  final String code;
  final String pattern;
  final RegExp exact;
  final num factor;
}

class _Rule {
  _Rule(this.kind, this.re, {required this.strength, this.consume = true, this.channel, this.drinkVerb = false});

  final QuickAddKind kind;
  final RegExp re;

  /// 3 = past-tense money verb, 2 = keyword, 1 = weak noun, 0 = needs an
  /// amount, -1 = helper (drink verb).
  final int strength;
  final bool consume;
  final ContactChannel? channel;
  final bool drinkVerb;
}

class _Hit {
  _Hit(this.rule, this.match);
  final _Rule rule;
  final RegExpMatch match;
}

/// Folded text plus a mask of consumed characters (indexes align with the
/// cleaned input because folding is length-preserving).
class _Scan {
  _Scan(this.clean) : norm = QuickAddParser._fold(clean), _used = List<bool>.filled(clean.length, false);

  final String clean;
  final String norm;
  final List<bool> _used;

  bool _free(int start, int end) {
    for (var i = start; i < end; i++) {
      if (_used[i]) return false;
    }
    return true;
  }

  void take(int start, int end) {
    for (var i = start; i < end; i++) {
      _used[i] = true;
    }
  }

  /// Consumes only the not-yet-consumed part of a range.
  void takeFree(int start, int end) => take(start, end);

  RegExpMatch? first(RegExp re, [bool Function(RegExpMatch m)? ok]) {
    for (final m in re.allMatches(norm)) {
      if (m.end <= m.start || !_free(m.start, m.end)) continue;
      if (ok != null && !ok(m)) continue;
      return m;
    }
    return null;
  }

  String remainder() {
    final b = StringBuffer();
    for (var i = 0; i < clean.length; i++) {
      b.write(_used[i] ? ' ' : clean[i]);
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
