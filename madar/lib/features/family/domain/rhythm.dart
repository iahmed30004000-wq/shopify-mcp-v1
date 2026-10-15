import 'dart:math' as math;

/// Calendar-day arithmetic (DST-safe: whole local days, never 24-hour
/// multiples of an instant).
abstract final class CalendarDays {
  /// Local midnight of [t]'s day.
  static DateTime dayOf(DateTime t) {
    final l = t.isUtc ? t.toLocal() : t;
    return DateTime(l.year, l.month, l.day);
  }

  /// Whole calendar days from [a]'s day to [b]'s day (negative when [b] is
  /// earlier). Matches the orbit's Neglect Radar (`orbit_moons._days`).
  static int between(DateTime a, DateTime b) => (dayOf(b).difference(dayOf(a)).inHours / 24).round();

  /// [day] plus [n] calendar days (local midnight).
  static DateTime add(DateTime day, int n) {
    final d = dayOf(day);
    return DateTime(d.year, d.month, d.day + n);
  }

  static bool sameDay(DateTime a, DateTime b) => between(a, b) == 0;
}

/// Where a person stands against their contact rhythm today.
enum RhythmStatus {
  /// No rhythm set.
  none,

  /// Past the due day.
  overdue,

  /// Due today.
  dueToday,

  /// Due within [RhythmEngine.soonDays] days.
  dueSoon,

  /// Comfortably within the rhythm.
  ok,
}

/// The list sections of the Family screen, in urgency order.
enum FamilyGroup { overdue, dueToday, thisWeek, inTouch, noRhythm }

/// One person's rhythm, evaluated at a moment.
class RhythmState {
  const RhythmState({
    required this.rhythmDays,
    required this.lastContact,
    required this.anchor,
    required this.daysSince,
    required this.nextDue,
    required this.daysUntilDue,
  });

  /// Reach out every N days (null = no rhythm).
  final int? rhythmDays;

  /// The effective last contact (never in the future), or null.
  final DateTime? lastContact;

  /// What the rhythm counts from: the last contact, else when the person
  /// was added (as the Neglect Radar does).
  final DateTime anchor;

  /// Calendar days since [anchor].
  final int daysSince;

  /// The day the next contact is due (null without a rhythm).
  final DateTime? nextDue;

  /// Days until [nextDue]: 0 = today, negative = overdue (null without a
  /// rhythm).
  final int? daysUntilDue;

  bool get hasRhythm => rhythmDays != null;
  bool get neverContacted => lastContact == null;

  /// Days past the due day (0 when not overdue).
  int get daysOverdue => math.max(0, -(daysUntilDue ?? 0));

  /// Days since the last contact, or null if never contacted.
  int? get daysSinceContact => lastContact == null ? null : daysSince;

  RhythmStatus get status {
    final until = daysUntilDue;
    if (until == null) return RhythmStatus.none;
    if (until < 0) return RhythmStatus.overdue;
    if (until == 0) return RhythmStatus.dueToday;
    if (until <= RhythmEngine.soonDays) return RhythmStatus.dueSoon;
    return RhythmStatus.ok;
  }

  FamilyGroup get group => switch (status) {
    RhythmStatus.none => FamilyGroup.noRhythm,
    RhythmStatus.overdue => FamilyGroup.overdue,
    RhythmStatus.dueToday => FamilyGroup.dueToday,
    RhythmStatus.dueSoon => FamilyGroup.thisWeek,
    RhythmStatus.ok => FamilyGroup.inTouch,
  };

  /// Due or overdue today (what the daily digest lists).
  bool get isDue => (daysUntilDue ?? 1) <= 0;

  /// Share of the rhythm elapsed (0 = just contacted, 1 = due, > 1 =
  /// overdue); null without a rhythm.
  double? get progress => rhythmDays == null ? null : daysSince / rhythmDays!;

  /// How pressing the person is: overdue share of the rhythm (larger =
  /// more urgent); for people not yet due, minus the days left.
  double get urgency {
    final r = rhythmDays;
    final until = daysUntilDue;
    if (r == null || until == null) return double.negativeInfinity;
    if (until < 0) return 1000 + -until / r * 100;
    return -until.toDouble();
  }
}

/// Contact-rhythm maths (pure).
abstract final class RhythmEngine {
  /// "This week": due within this many days.
  static const int soonDays = 7;

  /// Longest rhythm the editor offers.
  static const int maxRhythmDays = 365;

  /// Normalises a stored rhythm (null, 0 or negative = none).
  static int? normalizeRhythm(int? days) {
    if (days == null || days <= 0) return null;
    return math.min(days, maxRhythmDays);
  }

  /// [at], or [now] when [at] is later: a contact is never logged in the
  /// future.
  static DateTime clampToNow(DateTime at, DateTime now) => at.isAfter(now) ? now : at;

  /// The effective last contact: the latest of the stored value and the
  /// logged contacts, ignoring logs in the future (a stored future value –
  /// an import in another time zone – counts as now).
  static DateTime? effectiveLastContact({DateTime? stored, Iterable<DateTime> logs = const [], required DateTime now}) {
    DateTime? best = stored == null ? null : clampToNow(stored, now);
    for (final at in logs) {
      if (at.isAfter(now)) continue;
      if (best == null || at.isAfter(best)) best = at;
    }
    return best;
  }

  /// The stored last contact after a contact at [removedAt] was removed (or
  /// moved): unchanged unless it came from that contact; then the latest of
  /// [fallback] (the value before that contact was logged, when known) and
  /// the [remaining] logs – never in the future.
  static DateTime? lastContactAfterRemoval({
    required DateTime? stored,
    required DateTime removedAt,
    required Iterable<DateTime> remaining,
    required DateTime now,
    DateTime? fallback,
  }) {
    if (stored == null || !stored.isAtSameMomentAs(removedAt)) return stored;
    return effectiveLastContact(stored: fallback, logs: remaining, now: now);
  }

  /// The stored last contact after logging a contact at [at]: moves forward
  /// only (a back-dated log never rewinds it), never into the future.
  static DateTime? lastContactAfterLog({required DateTime? stored, required DateTime at, required DateTime now}) {
    final clamped = clampToNow(at, now);
    if (stored == null || clamped.isAfter(stored)) return clamped;
    return stored;
  }

  /// Evaluates a person's rhythm at [now]. [lastContact] should already be
  /// effective (see [effectiveLastContact]); a future value is clamped.
  static RhythmState evaluate({
    required int? rhythmDays,
    required DateTime? lastContact,
    required DateTime createdAt,
    required DateTime now,
  }) {
    final rhythm = normalizeRhythm(rhythmDays);
    final last = lastContact == null ? null : clampToNow(lastContact, now);
    final anchor = last ?? clampToNow(createdAt, now);
    final since = math.max(0, CalendarDays.between(anchor, now));
    if (rhythm == null) {
      return RhythmState(
        rhythmDays: null,
        lastContact: last,
        anchor: anchor,
        daysSince: since,
        nextDue: null,
        daysUntilDue: null,
      );
    }
    final due = CalendarDays.add(anchor, rhythm);
    return RhythmState(
      rhythmDays: rhythm,
      lastContact: last,
      anchor: anchor,
      daysSince: since,
      nextDue: due,
      daysUntilDue: CalendarDays.between(now, due),
    );
  }

  /// Orders people by urgency: overdue first (the larger share of their
  /// rhythm overdue first), due today, then soonest due; people without a
  /// rhythm last, in their manual order. Stable for ties.
  static List<T> byUrgency<T>(Iterable<T> items, RhythmState Function(T item) stateOf) {
    final list = items.toList();
    final index = {for (var i = 0; i < list.length; i++) list[i]: i};
    list.sort((a, b) {
      final ua = stateOf(a).urgency, ub = stateOf(b).urgency;
      final c = ub.compareTo(ua);
      if (c != 0) return c;
      return index[a]!.compareTo(index[b]!);
    });
    return list;
  }

  /// Groups [items] into the Family screen's sections (each in urgency
  /// order); empty groups are omitted.
  static Map<FamilyGroup, List<T>> group<T>(Iterable<T> items, RhythmState Function(T item) stateOf) {
    final out = <FamilyGroup, List<T>>{};
    for (final item in byUrgency(items, stateOf)) {
      (out[stateOf(item).group] ??= []).add(item);
    }
    return {
      for (final g in FamilyGroup.values)
        if (out[g] != null) g: out[g]!,
    };
  }

  /// Whether a person is due (or overdue) on [day], assuming no contact
  /// before then – the daily digest's projection.
  static bool dueOn(RhythmState state, DateTime day) {
    final due = state.nextDue;
    if (due == null) return false;
    return CalendarDays.between(due, day) >= 0;
  }

  /// The rhythm a relation usually suggests (a starting point the user can
  /// change), by relation key.
  static int? suggestedRhythm(String relationKey) => switch (relationKey) {
    'father' || 'mother' => 2,
    'grandfather' || 'grandmother' || 'brother' || 'sister' || 'partner' => 7,
    'friend' => 14,
    'uncle' || 'maternalUncle' || 'aunt' || 'maternalAunt' || 'inLaw' || 'relative' || 'colleague' => 30,
    'neighbour' || 'teacher' => 30,
    _ => null,
  };
}
