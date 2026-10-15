/// «خطة اليوم» · the daily plan of «الحفظ» (Part 14).
///
/// Pure Dart and **deterministic**: the same data and the same calendar day
/// always produce exactly the same plan, on his phone and in a test. There
/// is no randomness anywhere, nothing is remembered between days, and
/// nothing is written while planning – the plan is a function of his
/// results, his inventory, his marks, his settings and today's date.
///
/// ## What it decides every morning
///
/// 1. **الجديد** – one new portion, [HifzPlanSettings.newAyatPerDay] ayat
///    from where he left off ([HifzPlanSettings.newFrom]). No cursor set
///    means no new portion, and the plan says so instead of inventing one.
/// 2. **القريب** (the last seven days) – everything he was tested on in the
///    last [HifzPlanSettings.nearDays] days, everything in his list he has
///    **never** been tested on, and every ayah whose strength has fallen
///    into the weak band, wherever it is. Weakest first.
/// 3. **البعيد** – a rotation through everything else he has memorised. The
///    length of the rotation is derived from the cap
///    ([HifzPlanSettings.farCapAyat]), so a full turn visits **every**
///    memorised ayah exactly once and no day is ever bigger than the cap.
///
/// Each portion carries the mode the plan suggests for it (from its
/// strength alone), the hiding stage to start at, and how many repetitions
/// the owner asked for.
///
/// ## What it refuses to do
///
/// * It never schedules an ayah **twice in one day**: the three tracks are
///   filled in order and a verse already taken is never taken again.
/// * It never schedules a mode that cannot run today – with no speech model
///   on the phone, «سمّع» is not suggested and the typed modes are.
/// * It never touches an ayah he marked «مش عليّ».
/// * It never pretends a verse is weak because he never tried it: an
///   untested ayah is [StrengthBand.unknown], which puts it in the near
///   track as *new*, not as *forgotten*.
/// * It never piles missed days up. After a week away the day is still one
///   ordinary day, and the plan **says** what went back into the rotation
///   rather than letting it vanish ([HifzBacklog]).
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';
import '../../wird/domain/calendar_days.dart';
import 'hifz_modes.dart';
import 'hifz_strength.dart';
import 'mushaf_shape.dart';

/// Which of the three tracks a portion belongs to.
enum HifzTrack {
  /// «الجديد» – the new portion.
  fresh,

  /// «القريب» – the last seven days, plus whatever has gone weak.
  near,

  /// «البعيد» – the rotation through everything else.
  far,
}

/// Why something is not in today's plan although it was owed.
enum HifzDropReason {
  /// Days away: the rotation moved on while he was not here.
  missedDays,

  /// Today's cap was reached.
  dailyCap,
}

/// Something the plan wants him to know about itself.
enum HifzPlanNote {
  /// Nothing is memorised yet, so there is nothing to review.
  nothingMemorised,

  /// No cursor for the new portion, so there is no «جديد» today.
  noNewPortion,

  /// His very first day: no history at all.
  firstDay,

  /// There is no speech model on this phone, so «سمّع» is not offered and
  /// the written modes take its place.
  recitingUnavailable,

  /// He was away and the rotation moved on – see [HifzBacklog].
  backlogDropped,

  /// Everything in range is marked «مش عليّ».
  everythingSkipped,
}

/// His own choices for the plan.
@immutable
final class HifzPlanSettings {
  const HifzPlanSettings({
    this.newAyatPerDay = 5,
    this.newFrom,
    this.nearDays = 7,
    this.nearCapAyat = 30,
    this.farCapAyat = 40,
    this.dailyCapAyat = 80,
    this.repetitions = 3,
    this.groupSize = 5,
    this.practiseLinks = true,
  });

  static const String storageKey = 'hifz.plan';

  /// How much new material a day.
  final int newAyatPerDay;

  /// Where the new portion starts. Null means he has not chosen, and the
  /// plan offers no new portion rather than guessing.
  final AyahRef? newFrom;

  /// How many days count as «قريب».
  final int nearDays;

  /// The most ayat the near track may hold in one day.
  final int nearCapAyat;

  /// The most ayat the far rotation may hold in one day – this is what
  /// sets the length of the rotation.
  final int farCapAyat;

  /// The hard cap on the whole day, the three tracks together.
  final int dailyCapAyat;

  /// How many times he wants each ayah repeated.
  final int repetitions;

  /// How many ayat in a chunk of the chunking mode.
  final int groupSize;

  /// Whether to practise the join between the verses of a portion.
  final bool practiseLinks;

  HifzPlanSettings copyWith({
    int? newAyatPerDay,
    AyahRef? newFrom,
    bool clearNewFrom = false,
    int? nearDays,
    int? nearCapAyat,
    int? farCapAyat,
    int? dailyCapAyat,
    int? repetitions,
    int? groupSize,
    bool? practiseLinks,
  }) => HifzPlanSettings(
    newAyatPerDay: newAyatPerDay ?? this.newAyatPerDay,
    newFrom: clearNewFrom ? null : (newFrom ?? this.newFrom),
    nearDays: nearDays ?? this.nearDays,
    nearCapAyat: nearCapAyat ?? this.nearCapAyat,
    farCapAyat: farCapAyat ?? this.farCapAyat,
    dailyCapAyat: dailyCapAyat ?? this.dailyCapAyat,
    repetitions: repetitions ?? this.repetitions,
    groupSize: groupSize ?? this.groupSize,
    practiseLinks: practiseLinks ?? this.practiseLinks,
  );

  Map<String, Object?> toJson() => {
    'newAyatPerDay': newAyatPerDay,
    'newFrom': newFrom?.toString(),
    'nearDays': nearDays,
    'nearCapAyat': nearCapAyat,
    'farCapAyat': farCapAyat,
    'dailyCapAyat': dailyCapAyat,
    'repetitions': repetitions,
    'groupSize': groupSize,
    'practiseLinks': practiseLinks,
  };

  factory HifzPlanSettings.fromJson(Object? json) {
    if (json is! Map) return const HifzPlanSettings();
    int pick(String key, int fallback, int min, int max) {
      final v = json[key];
      return v is num && v >= min && v <= max ? v.toInt() : fallback;
    }

    final from = json['newFrom'];
    return HifzPlanSettings(
      newAyatPerDay: pick('newAyatPerDay', 5, 0, 300),
      newFrom: from is String ? AyahRef.tryParse(from) : null,
      nearDays: pick('nearDays', 7, 1, 60),
      nearCapAyat: pick('nearCapAyat', 30, 0, 2000),
      farCapAyat: pick('farCapAyat', 40, 0, 2000),
      dailyCapAyat: pick('dailyCapAyat', 80, 1, 6236),
      repetitions: pick('repetitions', 3, 1, 50),
      groupSize: pick('groupSize', 5, 1, 50),
      practiseLinks: json['practiseLinks'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HifzPlanSettings &&
      other.newAyatPerDay == newAyatPerDay &&
      other.newFrom == newFrom &&
      other.nearDays == nearDays &&
      other.nearCapAyat == nearCapAyat &&
      other.farCapAyat == farCapAyat &&
      other.dailyCapAyat == dailyCapAyat &&
      other.repetitions == repetitions &&
      other.groupSize == groupSize &&
      other.practiseLinks == practiseLinks;

  @override
  int get hashCode => Object.hash(
    newAyatPerDay,
    newFrom,
    nearDays,
    nearCapAyat,
    farCapAyat,
    dailyCapAyat,
    repetitions,
    groupSize,
    practiseLinks,
  );
}

/// One portion of today's plan.
@immutable
final class HifzPortion {
  const HifzPortion({
    required this.track,
    required this.range,
    required this.ayahCount,
    required this.band,
    required this.method,
    required this.stage,
    required this.repetitions,
    required this.practiseLinks,
    required this.firstPage,
    required this.lastPage,
    required this.seed,
    this.strength,
  });

  final HifzTrack track;
  final AyahRange range;
  final int ayahCount;

  /// The weakest band in the portion – what its colour comes from.
  final StrengthBand band;

  /// The mean strength of the ayat that have a result; null when none of
  /// them has one (nothing is invented for an untested portion).
  final double? strength;

  /// The mode the plan suggests, already filtered by what the phone can do.
  final HifzMethod method;

  /// Which stage of the hiding ladder to start at.
  final HidingStage stage;

  /// How many times he asked for each ayah.
  final int repetitions;

  /// Whether to practise the joins inside this portion.
  final bool practiseLinks;

  final int firstPage;
  final int lastPage;

  /// The deterministic seed for a fill-in-the-blank drill over this
  /// portion: the same portion on the same day always blanks the same
  /// words.
  final int seed;

  bool get crossesSurah => Mushaf.crossesSurah(range);

  @override
  String toString() => 'HifzPortion(${track.name} $range ×$ayahCount ${method.name})';
}

/// What a week away cost, said out loud instead of silently dropped.
@immutable
final class HifzBacklog {
  const HifzBacklog({
    required this.missedDays,
    required this.wouldHaveBeenAyat,
    required this.todayAyat,
    required this.droppedAyat,
    required this.dropped,
    required this.reasons,
    this.lastActiveDay,
  });

  static const HifzBacklog none = HifzBacklog(
    missedDays: 0,
    wouldHaveBeenAyat: 0,
    todayAyat: 0,
    droppedAyat: 0,
    dropped: [],
    reasons: {},
  );

  /// Days in a row with nothing at all, before today.
  final int missedDays;

  /// The last day he did something.
  final DateTime? lastActiveDay;

  /// How many ayat of review those days would have held.
  final int wouldHaveBeenAyat;

  /// How many are in today's plan.
  final int todayAyat;

  /// How many went back into the rotation instead of onto today.
  final int droppedAyat;

  /// Exactly which stretches went back, so he can be told rather than left
  /// to wonder. They are **not** lost: each comes round again on its own
  /// turn of the rotation.
  final List<AyahRange> dropped;

  final Set<HifzDropReason> reasons;

  bool get isEmpty => droppedAyat == 0 && missedDays == 0;

  @override
  String toString() => 'HifzBacklog($missedDays days away, $droppedAyat ayat back into the rotation)';
}

/// Today's plan.
@immutable
final class HifzDailyPlan {
  const HifzDailyPlan({
    required this.day,
    required this.fresh,
    required this.near,
    required this.far,
    required this.backlog,
    required this.notes,
    required this.cycleDays,
    required this.memorisedAyat,
    required this.settings,
  });

  final DateTime day;

  /// «الجديد»: the new portion, or null when he set no cursor.
  final HifzPortion? fresh;

  /// «القريب»: the last seven days and whatever went weak.
  final List<HifzPortion> near;

  /// «البعيد»: today's turn of the rotation.
  final List<HifzPortion> far;

  final HifzBacklog backlog;
  final List<HifzPlanNote> notes;

  /// How many days a full turn of the far rotation takes.
  final int cycleDays;

  /// How many ayat he has memorised in all (after his own marks).
  final int memorisedAyat;

  final HifzPlanSettings settings;

  /// Every portion of the day, new first.
  List<HifzPortion> get portions => [?fresh, ...near, ...far];

  int get totalAyat => portions.fold(0, (sum, p) => sum + p.ayahCount);

  bool get isEmpty => portions.isEmpty;

  bool has(HifzPlanNote note) => notes.contains(note);

  @override
  String toString() => 'HifzDailyPlan(${CalendarDays.key(day)}, $totalAyat ayat in ${portions.length} portions)';
}

/// Building the plan.
abstract final class HifzPlanner {
  /// Today's plan, from his own data and nothing else.
  ///
  /// [memorised] is his inventory (the ayah ranges of his Hifz list);
  /// [activeDays] are the days he actually did something, which is what
  /// "away for a week" is measured by.
  static HifzDailyPlan planFor({
    required DateTime today,
    required MushafShape shape,
    required List<AyahRange> memorised,
    required HifzStrengths strengths,
    required HifzPlanSettings settings,
    required List<HifzMethodState> methods,
    Set<DateTime> activeDays = const {},
  }) {
    final day = CalendarDays.dateOnly(today);
    final notes = <HifzPlanNote>{};

    // Everything he has memorised, in reading order, minus «مش عليّ».
    final inventory = <AyahRef>[];
    final seenRef = <String>{};
    final marked = <AyahRef>[];
    for (final range in memorised) {
      for (final ref in Mushaf.ayatIn(shape, Mushaf.clamp(shape, range))) {
        if (!seenRef.add(ref.toString())) continue;
        if (strengths.marks.skipped(ref)) {
          marked.add(ref);
          continue;
        }
        inventory.add(ref);
      }
    }
    inventory.sort((a, b) => shape.indexOf(a).compareTo(shape.indexOf(b)));
    if (inventory.isEmpty) {
      notes.add(marked.isEmpty ? HifzPlanNote.nothingMemorised : HifzPlanNote.everythingSkipped);
    }
    if (!_canRecite(methods)) notes.add(HifzPlanNote.recitingUnavailable);

    final taken = <String>{};

    // --------------------------------------------------------- الجديد ----
    HifzPortion? fresh;
    final from = settings.newFrom;
    if (from == null || settings.newAyatPerDay <= 0) {
      notes.add(HifzPlanNote.noNewPortion);
    } else {
      final range = Mushaf.take(shape, from, settings.newAyatPerDay);
      if (range != null) {
        final refs = [
          for (final r in Mushaf.ayatIn(shape, range))
            if (!strengths.marks.skipped(r)) r,
        ];
        if (refs.isNotEmpty) {
          for (final r in refs) {
            taken.add(r.toString());
          }
          fresh = _portionOf(
            shape: shape,
            strengths: strengths,
            settings: settings,
            methods: methods,
            day: day,
            track: HifzTrack.fresh,
            refs: refs,
            isNew: true,
          );
        }
      }
    }

    // ---------------------------------------------------------- القريب ----
    final nearRefs = <AyahRef>[];
    for (final ref in inventory) {
      if (taken.contains(ref.toString())) continue;
      final s = strengths.of(ref);
      final recent = s.lastDay != null && CalendarDays.between(s.lastDay!, day) < settings.nearDays;
      final weak = s.isKnown && s.band == StrengthBand.weak;
      final untested = !s.isKnown;
      if (recent || weak || untested) nearRefs.add(ref);
    }
    // Weakest first, and it **stays** in that order until the cap has had
    // its say: when the day has to be cut short, what is cut is the
    // strongest, never whatever happens to sit late in the mushaf.
    nearRefs.sort((a, b) => HifzStrengths.compare(strengths.of(a), strengths.of(b)));
    final nearTaken = nearRefs.take(math.max(0, settings.nearCapAyat)).toList();
    for (final r in nearTaken) {
      taken.add(r.toString());
    }

    // ---------------------------------------------------------- البعيد ----
    final rest = [
      for (final ref in inventory)
        if (!taken.contains(ref.toString())) ref,
    ];
    final perDay = math.max(1, settings.farCapAyat);
    final cycleDays = rest.isEmpty ? 1 : (rest.length / perDay).ceil();
    final slice = _sliceOf(day, cycleDays);
    final farTaken = _sliceRefs(rest, slice, cycleDays);
    for (final r in farTaken) {
      taken.add(r.toString());
    }

    // ------------------------------------------- the cap, and what it drops ----
    final dropped = <AyahRange>[];
    final reasons = <HifzDropReason>{};
    var nearKept = nearTaken;
    var farKept = farTaken;
    final capped = _applyCap(
      cap: settings.dailyCapAyat,
      freshCount: fresh?.ayahCount ?? 0,
      near: nearKept,
      far: farKept,
    );
    nearKept = capped.near;
    farKept = capped.far;
    if (capped.dropped.isNotEmpty) {
      dropped.addAll(Mushaf.rangesOf(shape, capped.dropped));
      reasons.add(HifzDropReason.dailyCap);
    }

    // ------------------------------------------------- days away ----
    final lastActive = _lastActiveBefore(activeDays, day);
    final missedDays = lastActive == null ? 0 : math.max(0, CalendarDays.between(lastActive, day) - 1);
    if (lastActive == null) notes.add(HifzPlanNote.firstDay);
    final missedTurns = <AyahRef>[];
    if (missedDays > 0 && rest.isNotEmpty) {
      final turns = math.min(missedDays, cycleDays - 1);
      for (var i = 1; i <= turns; i++) {
        final missedDay = CalendarDays.add(day, -i);
        final missedSlice = _sliceOf(missedDay, cycleDays);
        if (missedSlice == slice) continue;
        missedTurns.addAll(_sliceRefs(rest, missedSlice, cycleDays));
      }
    }
    if (missedTurns.isNotEmpty) {
      dropped.addAll(Mushaf.rangesOf(shape, missedTurns));
      reasons.add(HifzDropReason.missedDays);
      notes.add(HifzPlanNote.backlogDropped);
    }

    // Only now, with the cap applied, does the near track go back into
    // reading order: he reviews it as it is written.
    final nearPortions = [
      for (final refs in _runs(shape, nearKept))
        _portionOf(
          shape: shape,
          strengths: strengths,
          settings: settings,
          methods: methods,
          day: day,
          track: HifzTrack.near,
          refs: refs,
        ),
    ];
    final farPortions = [
      for (final refs in _runs(shape, farKept))
        _portionOf(
          shape: shape,
          strengths: strengths,
          settings: settings,
          methods: methods,
          day: day,
          track: HifzTrack.far,
          refs: refs,
        ),
    ];

    final todayAyat = (fresh?.ayahCount ?? 0) + nearKept.length + farKept.length;
    final droppedAyat = capped.dropped.length + missedTurns.length;
    return HifzDailyPlan(
      day: day,
      fresh: fresh,
      near: nearPortions,
      far: farPortions,
      backlog: HifzBacklog(
        missedDays: missedDays,
        lastActiveDay: lastActive,
        wouldHaveBeenAyat: todayAyat + droppedAyat,
        todayAyat: todayAyat,
        droppedAyat: droppedAyat,
        dropped: List.unmodifiable(dropped),
        reasons: Set.unmodifiable(reasons),
      ),
      notes: List.unmodifiable(notes.toList()..sort((a, b) => a.index.compareTo(b.index))),
      cycleDays: cycleDays,
      memorisedAyat: inventory.length,
      settings: settings,
    );
  }

  /// Which turn of the rotation [day] is: a plain function of the calendar,
  /// so two phones with the same data agree and a missed day does not shift
  /// anything.
  static int _sliceOf(DateTime day, int cycleDays) {
    if (cycleDays <= 1) return 0;
    final epochDay = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    return epochDay % cycleDays;
  }

  /// The contiguous slice [index] of [refs] when they are cut into
  /// [cycleDays] turns.
  static List<AyahRef> _sliceRefs(List<AyahRef> refs, int index, int cycleDays) {
    if (refs.isEmpty) return const [];
    final per = (refs.length / cycleDays).ceil();
    final start = index * per;
    if (start >= refs.length) return const [];
    final end = math.min(refs.length, start + per);
    return refs.sublist(start, end);
  }

  static DateTime? _lastActiveBefore(Set<DateTime> days, DateTime today) {
    DateTime? best;
    for (final d in days) {
      final day = CalendarDays.dateOnly(d);
      if (CalendarDays.between(day, today) < 0) continue; // the future
      if (best == null || day.isAfter(best)) best = day;
    }
    return best;
  }

  /// Keeps the day under the cap, taking from the far track first (it comes
  /// round again) and only then from the near one.
  static ({List<AyahRef> near, List<AyahRef> far, List<AyahRef> dropped}) _applyCap({
    required int cap,
    required int freshCount,
    required List<AyahRef> near,
    required List<AyahRef> far,
  }) {
    var room = math.max(0, cap - freshCount);
    final dropped = <AyahRef>[];
    var keptNear = near;
    var keptFar = far;
    if (near.length + far.length <= room) return (near: near, far: far, dropped: const []);
    final nearRoom = math.min(near.length, room);
    if (nearRoom < near.length) {
      dropped.addAll(near.sublist(nearRoom));
      keptNear = near.sublist(0, nearRoom);
    }
    room -= nearRoom;
    final farRoom = math.min(far.length, math.max(0, room));
    if (farRoom < far.length) {
      dropped.addAll(far.sublist(farRoom));
      keptFar = far.sublist(0, farRoom);
    }
    return (near: keptNear, far: keptFar, dropped: dropped);
  }

  /// [refs] (in reading order) cut into runs of neighbouring ayat.
  static List<List<AyahRef>> _runs(MushafShape shape, List<AyahRef> refs) {
    if (refs.isEmpty) return const [];
    final sorted = [...refs]..sort((a, b) => shape.indexOf(a).compareTo(shape.indexOf(b)));
    final out = <List<AyahRef>>[];
    var run = <AyahRef>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      if (shape.indexOf(sorted[i]) == shape.indexOf(sorted[i - 1]) + 1) {
        run.add(sorted[i]);
      } else {
        out.add(run);
        run = [sorted[i]];
      }
    }
    out.add(run);
    return out;
  }

  static bool _canRecite(List<HifzMethodState> methods) {
    for (final m in methods) {
      if (m.method == HifzMethod.reciting) return m.canRun;
    }
    return false;
  }

  static HifzPortion _portionOf({
    required MushafShape shape,
    required HifzStrengths strengths,
    required HifzPlanSettings settings,
    required List<HifzMethodState> methods,
    required DateTime day,
    required HifzTrack track,
    required List<AyahRef> refs,
    bool isNew = false,
  }) {
    final range = AyahRange(refs.first, refs.last);
    var band = StrengthBand.solid;
    for (final r in refs) {
      final b = strengths.of(r).band;
      if (b == StrengthBand.skipped) continue;
      if (_bandRank(b) < _bandRank(band)) band = b;
    }
    return HifzPortion(
      track: track,
      range: range,
      ayahCount: refs.length,
      band: band,
      strength: strengths.meanOf(refs),
      method: HifzMethods.suggestFor(band, states: methods, isNew: isNew),
      stage: FirstLetters.stageFor(band),
      repetitions: settings.repetitions,
      practiseLinks: settings.practiseLinks && refs.length > 1,
      firstPage: shape.pageOf(range.first),
      lastPage: shape.pageOf(range.last),
      seed: seedFor(day, range),
    );
  }

  /// Unknown counts as the weakest for a portion's colour: it is the one
  /// that needs the most work, even though it is not "forgotten".
  static int _bandRank(StrengthBand band) => switch (band) {
    StrengthBand.unknown => 0,
    StrengthBand.weak => 1,
    StrengthBand.shaky => 2,
    StrengthBand.firm => 3,
    StrengthBand.solid => 4,
    StrengthBand.skipped => 5,
  };

  /// The deterministic drill seed of a range on a day – plain integer
  /// arithmetic, so a phone and a test agree exactly.
  static int seedFor(DateTime day, AyahRange range) {
    final epochDay = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    var x = epochDay & 0x3FFFFFFF;
    for (final part in [range.first.surah, range.first.ayah, range.last.surah, range.last.ayah]) {
      x = (x * 1103515245 + part * 12345 + 7) & 0x3FFFFFFF;
    }
    return x;
  }
}
