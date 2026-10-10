/// The weekly shared challenge: one small thing to do together each week,
/// rotating through a list of generic ideas and the couple's own. Both
/// players mark it done; weeks done together in a row make a streak. The
/// week resets on the chosen first day of the week, in local time.
library;

import 'dart:math' as math;

import '../../domain/player_profile.dart';
import '../../domain/together_bounds.dart';
import 'specials_bounds.dart';

/// A default challenge.
final class DefaultChallenge {
  const DefaultChallenge(this.id, this.text, this.icon);

  final String id;
  final BiText text;

  /// Icon key (the UI maps it to an icon).
  final String icon;
}

/// Generic, culturally appropriate ideas (first person plural in Arabic:
/// "we …", no gender to guess). Every one can be reworded or hidden.
abstract final class ChallengeCatalogue {
  static const List<DefaultChallenge> all = [
    DefaultChallenge('walk', BiText('نتمشّى معًا نصف ساعة', 'Walk together for half an hour'), 'walk'),
    DefaultChallenge('cook', BiText('نطبخ معًا طبقًا جديدًا', 'Cook a new dish together'), 'cook'),
    DefaultChallenge('surah', BiText('نقرأ معًا سورة ونتأمّل معانيها', 'Read a surah together and reflect on it'), 'quran'),
    DefaultChallenge('noPhones', BiText('أمسية كاملة بلا هواتف', 'A whole evening without phones'), 'phoneOff'),
    DefaultChallenge('breakfast', BiText('نحضّر الفطور معًا', 'Make breakfast together'), 'breakfast'),
    DefaultChallenge('gratitude', BiText('يكتب كلٌّ منّا ثلاثة أشياء يقدّرها في الآخر', 'Each write three things we appreciate in the other'), 'heart'),
    DefaultChallenge('family', BiText('نزور الأهل معًا', 'Visit family together'), 'family'),
    DefaultChallenge('sunset', BiText('نشاهد الغروب معًا', 'Watch the sunset together'), 'sunset'),
    DefaultChallenge('newPlace', BiText('نزور مكانًا لم نزره من قبل', "Visit a place we've never been to"), 'explore'),
    DefaultChallenge('boardGame', BiText('نلعب لعبة ورق أو لعبة لوحية بلا شاشات', 'Play a card or board game – no screens'), 'cards'),
    DefaultChallenge('photos', BiText('نتصفّح صورنا القديمة معًا', 'Look through our old photos together'), 'photos'),
    DefaultChallenge('plant', BiText('نزرع نبتة أو نعتني بها معًا', 'Plant or care for a plant together'), 'plant'),
    DefaultChallenge('charity', BiText('نتصدّق أو نعمل عملًا خيريًا معًا', 'Give charity or do a good deed together'), 'charity'),
    DefaultChallenge('adhkar', BiText('نقرأ أذكار المساء معًا', 'Say the evening adhkar together'), 'moon'),
    DefaultChallenge('tidy', BiText('نرتّب ركنًا من البيت معًا', 'Tidy one corner of the home together'), 'home'),
    DefaultChallenge('learn', BiText('نتعلّم معًا شيئًا جديدًا', 'Learn something new together'), 'learn'),
    DefaultChallenge('stars', BiText('نتأمّل النجوم معًا في ليلة صافية', 'Stargaze together on a clear night'), 'stars'),
    DefaultChallenge('notes', BiText('يكتب كلٌّ منّا رسالة قصيرة للآخر', 'Each write the other a short note'), 'note'),
    DefaultChallenge('dessert', BiText('نصنع حلوى معًا', 'Make a dessert together'), 'dessert'),
    DefaultChallenge('exercise', BiText('نمارس الرياضة معًا', 'Exercise together'), 'fitness'),
    DefaultChallenge('bookChapter', BiText('نقرأ فصلًا من كتاب معًا', 'Read a chapter of a book together'), 'book'),
    DefaultChallenge('plan', BiText('نخطّط معًا لنزهة قريبة', 'Plan an outing together'), 'map'),
    DefaultChallenge('fast', BiText('نصوم معًا يوم تطوّع', 'Fast a voluntary day together'), 'crescent'),
    DefaultChallenge('nightPrayer', BiText('نصلّي معًا ركعتين في الليل', 'Pray two rak‘ahs together at night'), 'prayer'),
    DefaultChallenge('childhood', BiText('يحكي كلٌّ منّا للآخر ذكرى من طفولته', 'Each tell the other a childhood memory'), 'album'),
    DefaultChallenge('tea', BiText('جلسة شاي هادئة على الشرفة أو في الحديقة', 'A quiet cup of tea outdoors together'), 'tea'),
  ];

  static final Map<String, DefaultChallenge> _byId = {for (final c in all) c.id: c};

  static DefaultChallenge? byId(String id) => _byId[id];

  static bool isDefault(String id) => _byId.containsKey(id);
}

/// A challenge in the list: a default one (possibly reworded or hidden) or
/// one of the couple's own.
final class Challenge {
  const Challenge({required this.id, this.text = '', this.hidden = false});

  final String id;

  /// The typed text ('' = the default's localised text).
  final String text;

  /// A default taken out of the rotation (defaults are hidden, not deleted).
  final bool hidden;

  bool get isDefault => ChallengeCatalogue.isDefault(id);

  bool get isEdited => isDefault && text.isNotEmpty;

  String textIn(String languageCode) => text.isNotEmpty ? text : (ChallengeCatalogue.byId(id)?.text.of(languageCode) ?? '');

  String get iconKey => ChallengeCatalogue.byId(id)?.icon ?? 'star';

  Challenge copyWith({String? text, bool? hidden}) =>
      Challenge(id: id, text: text ?? this.text, hidden: hidden ?? this.hidden);

  Map<String, Object?> toJson() => {'i': id, if (text.isNotEmpty) 't': text, if (hidden) 'h': 1};

  static Challenge? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['i'];
    if (id is! String || !SpecialsBounds.isValidId(id)) return null;
    final text = SpecialsBounds.clean(json['t'], SpecialsBounds.maxChallengeLength);
    final c = Challenge(id: id, text: text, hidden: json['h'] == 1 || json['h'] == true);
    if (!c.isDefault && text.isEmpty) return null;
    // Only defaults can be hidden (the couple's own are deleted instead).
    return c.isDefault ? c : c.copyWith(hidden: false);
  }

  @override
  bool operator ==(Object other) => other is Challenge && other.id == id && other.text == text && other.hidden == hidden;

  @override
  int get hashCode => Object.hash(id, text, hidden);
}

/// Why a change of the challenge list was refused.
enum ChallengeEditError { emptyText, full, lastActive, unknown }

final class ChallengeEditException implements Exception {
  const ChallengeEditException(this.error);

  final ChallengeEditError error;

  @override
  String toString() => 'ChallengeEditException(${error.name})';
}

/// The challenges in rotation order.
final class ChallengeList {
  const ChallengeList(this.items);

  factory ChallengeList.defaults() => ChallengeList([for (final c in ChallengeCatalogue.all) Challenge(id: c.id)]);

  final List<Challenge> items;

  /// The rotation: every challenge that is not hidden, in order.
  List<Challenge> get pool => [
    for (final c in items)
      if (!c.hidden) c,
  ];

  bool get isFull => items.length >= SpecialsBounds.maxChallenges;

  Challenge? byId(String id) => items.where((c) => c.id == id).firstOrNull;

  String _clean(String text) {
    final t = SpecialsBounds.clean(text, SpecialsBounds.maxChallengeLength);
    if (t.isEmpty) throw const ChallengeEditException(ChallengeEditError.emptyText);
    return t;
  }

  ChallengeList add({required String id, required String text}) {
    if (isFull) throw const ChallengeEditException(ChallengeEditError.full);
    if (!SpecialsBounds.isValidId(id) || byId(id) != null || ChallengeCatalogue.isDefault(id)) {
      throw ArgumentError.value(id, 'id', 'not a fresh id');
    }
    return ChallengeList([...items, Challenge(id: id, text: _clean(text))]);
  }

  /// Rewords a challenge (a default reworded back to its default text in
  /// either language becomes the default again).
  ChallengeList edit(String id, String text) {
    final c = byId(id);
    if (c == null) throw const ChallengeEditException(ChallengeEditError.unknown);
    var t = _clean(text);
    final d = ChallengeCatalogue.byId(id);
    if (d != null && (t == d.text.ar || t == d.text.en)) t = '';
    return ChallengeList([for (final x in items) x.id == id ? x.copyWith(text: t) : x]);
  }

  ChallengeList resetText(String id) => ChallengeList([for (final x in items) x.id == id && x.isDefault ? x.copyWith(text: '') : x]);

  /// Hides / shows a default challenge; the last one in rotation stays.
  ChallengeList setHidden(String id, bool hidden) {
    final c = byId(id);
    if (c == null || !c.isDefault) throw const ChallengeEditException(ChallengeEditError.unknown);
    if (hidden && !c.hidden && pool.length <= 1) throw const ChallengeEditException(ChallengeEditError.lastActive);
    return ChallengeList([for (final x in items) x.id == id ? x.copyWith(hidden: hidden) : x]);
  }

  /// Deletes one of the couple's own challenges (a default is hidden
  /// instead); the last one in rotation stays.
  ChallengeList delete(String id) {
    final c = byId(id);
    if (c == null) return this;
    if (c.isDefault) return setHidden(id, true);
    if (!c.hidden && pool.length <= 1) throw const ChallengeEditException(ChallengeEditError.lastActive);
    return ChallengeList([
      for (final x in items)
        if (x.id != id) x,
    ]);
  }

  ChallengeList reorder(List<String> ids) {
    final byId = {for (final c in items) c.id: c};
    final ordered = <Challenge>[
      for (final id in ids.toSet())
        if (byId.containsKey(id)) byId[id]!,
    ];
    for (final c in items) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    return ChallengeList(ordered);
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'i': [for (final c in items) c.toJson()],
  };

  /// A stored list (defaults when missing); defaults are always present –
  /// a newer app version's new ones are appended.
  static ChallengeList fromJson(Object? json) {
    if (json is! Map || json['i'] is! List) return ChallengeList.defaults();
    final items = <Challenge>[];
    for (final item in json['i'] as List) {
      final c = Challenge.fromJson(item);
      if (c == null || items.any((x) => x.id == c.id)) continue;
      if (c.isDefault || items.where((x) => !x.isDefault).length < SpecialsBounds.maxChallenges - ChallengeCatalogue.all.length) {
        items.add(c);
      }
    }
    for (final d in ChallengeCatalogue.all) {
      if (!items.any((x) => x.id == d.id)) items.add(Challenge(id: d.id));
    }
    // Something must rotate.
    if (!items.any((c) => !c.hidden)) {
      final i = items.indexWhere((c) => c.isDefault);
      items[i] = items[i].copyWith(hidden: false);
    }
    return ChallengeList(items);
  }

  @override
  bool operator ==(Object other) {
    if (other is! ChallengeList || other.items.length != items.length) return false;
    for (var i = 0; i < items.length; i++) {
      if (other.items[i] != items[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(items);
}

/// One week of the log.
final class ChallengeWeek {
  const ChallengeWeek({
    required this.start,
    required this.challengeId,
    this.doneOne,
    this.doneTwo,
    this.streak,
    this.bestBefore = 0,
  });

  /// First local day of the week ([TogetherDays.indexOf]) under the week
  /// start in force when the week was written (see [SpecialWeeks.canonical]).
  final int start;

  /// This week's challenge (pinned once the week is shown).
  final String challengeId;

  /// When each player marked it done (null: not yet).
  final DateTime? doneOne;
  final DateTime? doneTwo;

  /// Streak length this week completed (both done), else null.
  final int? streak;

  /// The best streak before this week completed (restored on undo).
  final int bestBefore;

  bool get bothDone => doneOne != null && doneTwo != null;

  bool get anyDone => doneOne != null || doneTwo != null;

  DateTime? doneBy(PlayerSlot s) => s == PlayerSlot.one ? doneOne : doneTwo;

  ChallengeWeek copyWith({
    String? challengeId,
    DateTime? Function()? doneOne,
    DateTime? Function()? doneTwo,
    int? Function()? streak,
    int? bestBefore,
  }) => ChallengeWeek(
    start: start,
    challengeId: challengeId ?? this.challengeId,
    doneOne: doneOne == null ? this.doneOne : doneOne(),
    doneTwo: doneTwo == null ? this.doneTwo : doneTwo(),
    streak: streak == null ? this.streak : streak(),
    bestBefore: bestBefore ?? this.bestBefore,
  );

  Map<String, Object?> toJson() => {
    'w': start,
    'c': challengeId,
    'a': ?doneOne?.millisecondsSinceEpoch,
    'b': ?doneTwo?.millisecondsSinceEpoch,
    's': ?streak,
    if (bestBefore > 0) 'pb': bestBefore,
  };

  static ChallengeWeek? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = SpecialWeeks.parseDay(json['w']);
    final c = json['c'];
    if (start == null || c is! String || !SpecialsBounds.isValidId(c)) return null;
    final one = TogetherBounds.time(json['a']);
    final two = TogetherBounds.time(json['b']);
    final s = json['s'];
    final both = one != null && two != null;
    return ChallengeWeek(
      start: start,
      challengeId: c,
      doneOne: one,
      doneTwo: two,
      // A streak only on a completed week, at least 1.
      streak: both && s is int && s >= 1 ? math.min(s, 1 << 20) : (both ? 1 : null),
      bestBefore: TogetherBounds.count(json['pb'], max: 1 << 20),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChallengeWeek &&
      other.start == start &&
      other.challengeId == challengeId &&
      other.doneOne == doneOne &&
      other.doneTwo == doneTwo &&
      other.streak == streak &&
      other.bestBefore == bestBefore;

  @override
  int get hashCode => Object.hash(start, challengeId, doneOne, doneTwo, streak, bestBefore);
}

/// What marking a challenge did.
final class ChallengeMark {
  const ChallengeMark({required this.log, required this.completed, required this.uncompleted});

  final ChallengeLog log;

  /// Both players are now done (this week just completed).
  final bool completed;

  /// A completed week was un-marked.
  final bool uncompleted;
}

/// The challenge log: recent weeks (bounded) and lifetime totals.
///
/// Only the current week can change, so each completed week's streak is
/// final when written – streaks never depend on how many weeks are kept.
final class ChallengeLog {
  const ChallengeLog({this.weeks = const [], this.total = 0, this.best = 0});

  static const ChallengeLog empty = ChallengeLog();

  /// Oldest first.
  final List<ChallengeWeek> weeks;

  /// Weeks completed together, ever.
  final int total;

  /// Longest streak, ever.
  final int best;

  /// The stored week that is [week] under [weekStart].
  ChallengeWeek? weekAt(int week, int weekStart) =>
      weeks.where((w) => SpecialWeeks.canonical(w.start, weekStart) == week).lastOrNull;

  /// The challenge [week] has – or would get: the next one in rotation
  /// after the most recent earlier week's (the first of the rotation
  /// otherwise, spread by the week number).
  String challengeFor(int week, int weekStart, List<Challenge> pool) {
    final pinned = weekAt(week, weekStart);
    if (pinned != null) return pinned.challengeId;
    if (pool.isEmpty) return '';
    ChallengeWeek? previous;
    var previousWeek = -1 << 40;
    for (final w in weeks) {
      final c = SpecialWeeks.canonical(w.start, weekStart);
      if (c < week && c > previousWeek) {
        previous = w;
        previousWeek = c;
      }
    }
    final i = previous == null ? -1 : pool.indexWhere((c) => c.id == previous!.challengeId);
    if (i < 0) return pool[(week ~/ 7) % pool.length].id;
    return pool[(i + 1) % pool.length].id;
  }

  /// This log with [week] pinned to its challenge (unchanged when it is).
  /// With [existing] (every challenge id in the list), a week pinned to a
  /// challenge that was deleted since – and not started – gets the next one
  /// in rotation instead.
  ChallengeLog ensureWeek(int week, int weekStart, List<Challenge> pool, {Set<String>? existing}) {
    final pinned = weekAt(week, weekStart);
    if (pinned != null) {
      if (existing == null || existing.contains(pinned.challengeId) || pinned.anyDone) return this;
      final without = ChallengeLog(weeks: [
        for (final w in weeks)
          if (!identical(w, pinned)) w,
      ], total: total, best: best);
      final id = without.challengeFor(week, weekStart, pool);
      if (id.isEmpty) return this;
      return _withWeek(pinned.copyWith(challengeId: id), weekStart);
    }
    final id = challengeFor(week, weekStart, pool);
    if (id.isEmpty) return this;
    return _withWeek(ChallengeWeek(start: week, challengeId: id), weekStart);
  }

  ChallengeLog _withWeek(ChallengeWeek w, int weekStart, {int? total, int? best}) {
    final list = [
      for (final x in weeks)
        if (SpecialWeeks.canonical(x.start, weekStart) != SpecialWeeks.canonical(w.start, weekStart)) x,
      w,
    ]..sort((a, b) => SpecialWeeks.canonical(a.start, weekStart).compareTo(SpecialWeeks.canonical(b.start, weekStart)));
    return ChallengeLog(
      weeks: list.length > SpecialsBounds.maxWeeks ? list.sublist(list.length - SpecialsBounds.maxWeeks) : list,
      total: total ?? this.total,
      best: best ?? this.best,
    );
  }

  /// [slot] marks [week]'s challenge done ([done]) or not done. Completing
  /// the week (both done) extends the streak from the week before;
  /// un-marking a completed week takes it back exactly.
  ChallengeMark mark({
    required int week,
    required int weekStart,
    required PlayerSlot slot,
    required bool done,
    required DateTime at,
    required List<Challenge> pool,
  }) {
    final base = ensureWeek(week, weekStart, pool);
    final w = base.weekAt(week, weekStart);
    if (w == null) return ChallengeMark(log: this, completed: false, uncompleted: false);
    if ((w.doneBy(slot) != null) == done) return ChallengeMark(log: base, completed: false, uncompleted: false);
    DateTime? value() => done ? at : null;
    var next = slot == PlayerSlot.one ? w.copyWith(doneOne: value) : w.copyWith(doneTwo: value);
    var total = base.total;
    var completed = false, uncompleted = false;
    if (next.bothDone && w.streak == null) {
      final previous = base.weekAt(week - 7, weekStart);
      final streak = (previous?.streak ?? 0) + 1;
      next = next.copyWith(streak: () => streak, bestBefore: base.best);
      total++;
      completed = true;
    } else if (!next.bothDone && w.streak != null) {
      next = next.copyWith(streak: () => null, bestBefore: 0);
      total = math.max(0, total - 1);
      uncompleted = true;
    }
    if (!completed && !uncompleted) {
      return ChallengeMark(log: base._withWeek(next, weekStart), completed: false, uncompleted: false);
    }
    // Weeks after this one already completed (the clock or the time zone
    // went back over a week boundary) continue this week's streak.
    final log = base._withWeek(next, weekStart, total: total)._restreakAfter(week, weekStart);
    var later = 0;
    for (final x in log.weeks) {
      if (SpecialWeeks.canonical(x.start, weekStart) >= week) later = math.max(later, x.streak ?? 0);
    }
    final best = completed ? math.max(base.best, later) : math.max(w.bestBefore, later);
    return ChallengeMark(
      log: ChallengeLog(weeks: log.weeks, total: log.total, best: best),
      completed: completed,
      uncompleted: uncompleted,
    );
  }

  /// Recomputes the streaks of the completed weeks right after [week].
  ChallengeLog _restreakAfter(int week, int weekStart) {
    var log = this;
    for (var k = week + 7; ; k += 7) {
      final w = log.weekAt(k, weekStart);
      if (w == null || !w.bothDone) return log;
      final streak = (log.weekAt(k - 7, weekStart)?.streak ?? 0) + 1;
      if (streak == w.streak) return log;
      log = log._withWeek(w.copyWith(streak: () => streak), weekStart);
    }
  }

  /// Picks another challenge for [week] – only while nobody has marked it.
  ChallengeLog swap({required int week, required int weekStart, required String challengeId, required List<Challenge> pool}) {
    if (!pool.any((c) => c.id == challengeId)) throw const ChallengeEditException(ChallengeEditError.unknown);
    final base = ensureWeek(week, weekStart, pool);
    final w = base.weekAt(week, weekStart)!;
    if (w.anyDone) throw StateError('the week\'s challenge is already being done');
    return base._withWeek(w.copyWith(challengeId: challengeId), weekStart);
  }

  /// The next challenge in rotation after [week]'s (for "another one").
  String nextAfter(int week, int weekStart, List<Challenge> pool) {
    if (pool.isEmpty) return '';
    final current = challengeFor(week, weekStart, pool);
    final i = pool.indexWhere((c) => c.id == current);
    return pool[(i + 1) % pool.length].id;
  }

  /// The streak as of [week]: alive while the latest completed week is this
  /// week or the one before (or later – the clock or the time zone moved
  /// back), else 0.
  int currentStreak(int week, int weekStart) {
    ChallengeWeek? latest;
    var latestWeek = -1 << 40;
    for (final w in weeks) {
      if (w.streak == null) continue;
      final c = SpecialWeeks.canonical(w.start, weekStart);
      if (c > latestWeek) {
        latest = w;
        latestWeek = c;
      }
    }
    if (latest == null) return 0;
    return latestWeek >= week - 7 ? latest.streak! : 0;
  }

  /// Recent weeks up to [week] (oldest first, at most [count]), with
  /// missing weeks as null.
  List<ChallengeWeek?> recent(int week, int weekStart, {int count = 8}) => [
    for (var i = count - 1; i >= 0; i--) weekAt(week - 7 * i, weekStart),
  ];

  Map<String, Object?> toJson() => {
    'v': 1,
    'w': [for (final w in weeks) w.toJson()],
    't': total,
    'b': best,
  };

  static ChallengeLog fromJson(Object? json) {
    if (json is! Map) return empty;
    final weeks = <ChallengeWeek>[];
    final raw = json['w'];
    if (raw is List) {
      for (final item in raw) {
        final w = ChallengeWeek.fromJson(item);
        if (w != null && !weeks.any((x) => x.start == w.start)) weeks.add(w);
      }
    }
    weeks.sort((a, b) => a.start.compareTo(b.start));
    final kept = weeks.length > SpecialsBounds.maxWeeks ? weeks.sublist(weeks.length - SpecialsBounds.maxWeeks) : weeks;
    final completed = kept.where((w) => w.bothDone).length;
    final longest = kept.fold<int>(0, (m, w) => math.max(m, w.streak ?? 0));
    return ChallengeLog(
      weeks: kept,
      // Never less than what the kept weeks prove.
      total: math.max(TogetherBounds.count(json['t'], max: 1 << 20), completed),
      best: math.max(TogetherBounds.count(json['b'], max: 1 << 20), longest),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! ChallengeLog || other.total != total || other.best != best || other.weeks.length != weeks.length) {
      return false;
    }
    for (var i = 0; i < weeks.length; i++) {
      if (other.weeks[i] != weeks[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(weeks), total, best);
}
