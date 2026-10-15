import 'package:flutter/foundation.dart';

/// Units the app knows by name: shown with correct plurals in both languages
/// ("صفحتان", "١١ صفحة", "1 page") and offered as suggestions.
enum GrowthUnitKind {
  pages,
  lessons,
  hours,
  chapters,
  courses,
  words,
  books,
  lectures,
  minutes,
  articles;

  /// Whether amounts are whole things (a page, a lesson) rather than a
  /// measure (hours).
  bool get countable => this != hours;
}

/// A goal's unit: one of the [GrowthUnitKind]s or the user's own words.
///
/// Stored in `LearningGoals.unit` as the kind's name (`pages`) or the free
/// text as typed. Any spelling of a known unit in Arabic or English
/// ("صفحات", "Pages", "صفحة") is recognised as that unit, so imported or
/// typed units get proper plurals too.
@immutable
class GrowthUnit {
  const GrowthUnit.known(GrowthUnitKind this.kind) : custom = null;
  const GrowthUnit.custom(String this.custom) : kind = null;

  /// No unit (plain numbers).
  static const GrowthUnit none = GrowthUnit.custom('');

  /// Suggestion order in the goal editor.
  static const List<GrowthUnitKind> suggestions = GrowthUnitKind.values;

  final GrowthUnitKind? kind;
  final String? custom;

  factory GrowthUnit.parse(String? stored) {
    final raw = (stored ?? '').trim();
    if (raw.isEmpty) return none;
    final kind = matchKind(raw);
    return kind == null ? GrowthUnit.custom(raw) : GrowthUnit.known(kind);
  }

  /// The known unit [text] names, if any.
  static GrowthUnitKind? matchKind(String text) => _aliases[normalize(text)];

  /// Lower case, no Arabic diacritics or tatweel, unified alef / yeh / teh
  /// marbuta forms, collapsed spaces.
  static String normalize(String text) {
    var s = text.trim().toLowerCase();
    s = s.replaceAll(RegExp('[ً-ْٰـ]'), '');
    s = s.replaceAll(RegExp('[أإآٱ]'), 'ا').replaceAll('ى', 'ي').replaceAll('ة', 'ه');
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  static final Map<String, GrowthUnitKind> _aliases = {
    for (final e in const {
      GrowthUnitKind.pages: ['pages', 'page', 'pp', 'صفحات', 'صفحة', 'صفحه'],
      GrowthUnitKind.lessons: ['lessons', 'lesson', 'دروس', 'درس'],
      GrowthUnitKind.hours: ['hours', 'hour', 'hrs', 'hr', 'ساعات', 'ساعة', 'ساعه'],
      GrowthUnitKind.chapters: ['chapters', 'chapter', 'فصول', 'فصل'],
      GrowthUnitKind.courses: ['courses', 'course', 'دورات', 'دورة', 'دوره', 'كورس', 'كورسات'],
      GrowthUnitKind.words: ['words', 'word', 'vocabulary', 'كلمات', 'كلمة', 'كلمه', 'مفردات', 'مفردة'],
      GrowthUnitKind.books: ['books', 'book', 'كتب', 'كتاب'],
      GrowthUnitKind.lectures: ['lectures', 'lecture', 'محاضرات', 'محاضرة', 'محاضره'],
      GrowthUnitKind.minutes: ['minutes', 'minute', 'mins', 'min', 'دقائق', 'دقيقة', 'دقيقه'],
      GrowthUnitKind.articles: ['articles', 'article', 'مقالات', 'مقال', 'مقالة', 'مقاله'],
    }.entries)
      for (final alias in e.value) normalize(alias): e.key,
  };

  bool get isKnown => kind != null;
  bool get isEmpty => kind == null && custom!.trim().isEmpty;

  /// What is written to the database.
  String get stored => kind?.name ?? custom!.trim();

  /// Whether amounts are whole things (custom units may be anything).
  bool get countable => kind?.countable ?? false;

  /// The smallest amount worth showing: whole things, tenths of an hour or
  /// of a custom unit.
  double get granularity => switch (kind) {
    GrowthUnitKind.hours || null => 0.1,
    _ => 1,
  };

  /// Step of the log sheet's − / + buttons.
  double stepFor(double target) => switch (kind) {
    GrowthUnitKind.hours => 0.5,
    GrowthUnitKind.minutes || GrowthUnitKind.words => 5,
    null when target > 2000 => 10,
    _ => 1,
  };

  /// One-tap amounts ("+1", "+5", "+10") for a goal of [target] units.
  List<double> quickAmounts(double target) => switch (kind) {
    GrowthUnitKind.pages => const [1, 5, 10, 20],
    GrowthUnitKind.lessons ||
    GrowthUnitKind.chapters ||
    GrowthUnitKind.lectures ||
    GrowthUnitKind.articles => const [1, 2, 3],
    GrowthUnitKind.hours => const [0.5, 1, 2],
    GrowthUnitKind.minutes => const [10, 15, 30, 60],
    GrowthUnitKind.words => const [5, 10, 25, 50],
    GrowthUnitKind.courses || GrowthUnitKind.books => const [1],
    null when target <= 12 => const [1, 2, 3],
    null when target <= 200 => const [1, 5, 10],
    null when target <= 2000 => const [5, 10, 25, 50],
    null => const [10, 50, 100, 500],
  };

  @override
  bool operator ==(Object other) => other is GrowthUnit && other.kind == kind && other.custom == custom;

  @override
  int get hashCode => Object.hash(kind, custom);

  @override
  String toString() => 'GrowthUnit($stored)';
}

/// How a rate is best said: per day, or per week when less than one whole
/// thing a day ("٣ صفحات أسبوعيًا" rather than "٠٫٤ صفحة يوميًا").
@immutable
class GrowthRate {
  const GrowthRate(this.amount, {required this.perWeek});

  final double amount;
  final bool perWeek;

  /// [perDay] rounded to the unit's [GrowthUnit.granularity]; [roundUp] for
  /// what is *needed* (never promise less than it takes).
  static GrowthRate of(double perDay, GrowthUnit unit, {bool roundUp = false}) {
    final g = unit.granularity;
    double round(double v) {
      final steps = v / g;
      final r = roundUp ? (steps - 1e-9).ceilToDouble() : steps.roundToDouble();
      // Keep a non-zero rate visible.
      return (r == 0 && v > 0 ? 1 : r) * g;
    }

    if (perDay > 0 && perDay < 1 && unit.countable) return GrowthRate(round(perDay * 7), perWeek: true);
    return GrowthRate(_clean(round(perDay)), perWeek: false);
  }

  static double _clean(double v) => (v * 1000).roundToDouble() / 1000;

  @override
  bool operator ==(Object other) => other is GrowthRate && other.amount == amount && other.perWeek == perWeek;

  @override
  int get hashCode => Object.hash(amount, perWeek);

  @override
  String toString() => 'GrowthRate($amount${perWeek ? '/week' : '/day'})';
}
