import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import 'calendar_days.dart';

/// How a plan makes up for missed reading (or uses reading done ahead).
enum WirdCatchUp {
  /// Spread the difference over the coming days (the rest of a khatma, or
  /// the next [WirdPlanMeta.catchUpDays] days of an open-ended plan).
  spread,

  /// Put the whole difference on today.
  allAtOnce,
}

/// The kind of plan the user picked (how the row is interpreted).
enum WirdTemplate {
  /// Finish the mushaf (from the start position) in N days.
  khatma,
  pages,
  juz,
  hizb,
  ayat;

  WirdUnit get unit => switch (this) {
    WirdTemplate.khatma || WirdTemplate.pages => WirdUnit.pages,
    WirdTemplate.juz => WirdUnit.juz,
    WirdTemplate.hizb => WirdUnit.hizb,
    WirdTemplate.ayat => WirdUnit.ayat,
  };
}

/// A stretch of days when a plan was paused (inclusive; [to] null while it
/// still is). Paused days owe nothing and neither count for nor break a
/// streak.
@immutable
class WirdPause {
  const WirdPause(this.from, [this.to]);

  final DateTime from;
  final DateTime? to;

  bool covers(DateTime day) =>
      CalendarDays.between(from, day) >= 0 && (to == null || CalendarDays.between(day, to!) >= 0);

  /// Paused days (up to [today] while ongoing).
  int length(DateTime today) => CalendarDays.between(from, to ?? today) + 1;

  List<String?> toJson() => [CalendarDays.key(from), to == null ? null : CalendarDays.key(to!)];

  static WirdPause? fromJson(Object? json) {
    if (json is! List || json.isEmpty) return null;
    final from = CalendarDays.parse(json[0]);
    if (from == null) return null;
    return WirdPause(from, json.length > 1 ? CalendarDays.parse(json[1]) : null);
  }

  @override
  bool operator ==(Object other) => other is WirdPause && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// Settings of a plan kept beside its row (`key_values` `wird.meta`).
@immutable
class WirdPlanMeta {
  const WirdPlanMeta({
    this.catchUp = WirdCatchUp.spread,
    this.remind = true,
    this.remindOffsetMin = 15,
    this.pauses = const [],
    this.catchUpDays = defaultCatchUpDays,
  });

  /// Days an open-ended plan spreads a difference over.
  static const int defaultCatchUpDays = 7;

  /// Minutes after the prayer the reminder may be set to.
  static const List<int> offsets = [0, 10, 15, 20, 30, 45, 60];

  final WirdCatchUp catchUp;

  /// Remind after the prayer of the plan's window.
  final bool remind;
  final int remindOffsetMin;
  final List<WirdPause> pauses;
  final int catchUpDays;

  bool pausedOn(DateTime day) => pauses.any((p) => p.covers(day));

  WirdPause? get openPause {
    for (final p in pauses) {
      if (p.to == null) return p;
    }
    return null;
  }

  WirdPlanMeta copyWith({
    WirdCatchUp? catchUp,
    bool? remind,
    int? remindOffsetMin,
    List<WirdPause>? pauses,
    int? catchUpDays,
  }) => WirdPlanMeta(
    catchUp: catchUp ?? this.catchUp,
    remind: remind ?? this.remind,
    remindOffsetMin: remindOffsetMin ?? this.remindOffsetMin,
    pauses: pauses ?? this.pauses,
    catchUpDays: catchUpDays ?? this.catchUpDays,
  );

  Map<String, Object?> toJson() => {
    'catchUp': catchUp.name,
    'remind': remind,
    'offset': remindOffsetMin,
    'pauses': [for (final p in pauses) p.toJson()],
    if (catchUpDays != defaultCatchUpDays) 'catchUpDays': catchUpDays,
  };

  factory WirdPlanMeta.fromJson(Object? json) {
    if (json is! Map) return const WirdPlanMeta();
    final offset = json['offset'];
    final days = json['catchUpDays'];
    final pauses = json['pauses'];
    return WirdPlanMeta(
      catchUp: WirdCatchUp.values.asNameMap()[json['catchUp']] ?? WirdCatchUp.spread,
      remind: json['remind'] != false,
      remindOffsetMin: offset is num && offset >= 0 && offset <= 180 ? offset.toInt() : 15,
      pauses: [
        if (pauses is List)
          for (final p in pauses) ?WirdPause.fromJson(p),
      ],
      catchUpDays: days is num && days >= 1 && days <= 60 ? days.toInt() : defaultCatchUpDays,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WirdPlanMeta &&
      other.catchUp == catchUp &&
      other.remind == remind &&
      other.remindOffsetMin == remindOffsetMin &&
      listEquals(other.pauses, pauses) &&
      other.catchUpDays == catchUpDays;

  @override
  int get hashCode => Object.hash(catchUp, remind, remindOffsetMin, Object.hashAll(pauses), catchUpDays);
}

/// A daily wird plan: its row (`wird_plans`) and its [WirdPlanMeta].
@immutable
class WirdPlan {
  const WirdPlan({
    required this.id,
    required this.name,
    required this.unit,
    required this.amountPerDay,
    required this.start,
    required this.startDate,
    this.targetDate,
    this.window,
    this.active = true,
    this.sortOrder = 0,
    this.meta = const WirdPlanMeta(),
  });

  factory WirdPlan.fromRow(WirdPlanRow row, [WirdPlanMeta meta = const WirdPlanMeta()]) => WirdPlan(
    id: row.id,
    name: row.name,
    unit: row.unit,
    amountPerDay: row.amountPerDay,
    start: AyahRef(row.startSurah.clamp(1, 114), row.startAyah < 1 ? 1 : row.startAyah),
    startDate: row.startDate,
    targetDate: row.targetDate,
    window: row.window,
    active: row.active,
    sortOrder: row.sortOrder,
    meta: meta,
  );

  final String id;
  final String name;
  final WirdUnit unit;

  /// Units a day (for a khatma: the planned average, informative).
  final double amountPerDay;
  final AyahRef start;
  final DateTime startDate;

  /// Last day of a khatma (null = an open-ended daily amount).
  final DateTime? targetDate;
  final PrayerWindow? window;

  /// False while paused.
  final bool active;
  final int sortOrder;
  final WirdPlanMeta meta;

  bool get isKhatma => targetDate != null;

  WirdTemplate get template => isKhatma
      ? WirdTemplate.khatma
      : switch (unit) {
          WirdUnit.pages => WirdTemplate.pages,
          WirdUnit.juz => WirdTemplate.juz,
          WirdUnit.hizb => WirdTemplate.hizb,
          WirdUnit.ayat => WirdTemplate.ayat,
        };

  /// Planned length of a khatma in days (null when open-ended).
  int? get khatmaDays => targetDate == null ? null : CalendarDays.between(startDate, targetDate!) + 1;

  /// Whether [day] is a paused day ([today] counts as paused while the plan
  /// is inactive, even without a recorded pause).
  bool pausedOn(DateTime day, {required DateTime today}) =>
      meta.pausedOn(day) || (!active && CalendarDays.same(day, today));

  WirdPlan copyWith({WirdPlanMeta? meta, bool? active, DateTime? targetDate}) => WirdPlan(
    id: id,
    name: name,
    unit: unit,
    amountPerDay: amountPerDay,
    start: start,
    startDate: startDate,
    targetDate: targetDate ?? this.targetDate,
    window: window,
    active: active ?? this.active,
    sortOrder: sortOrder,
    meta: meta ?? this.meta,
  );

  @override
  bool operator ==(Object other) =>
      other is WirdPlan &&
      other.id == id &&
      other.name == name &&
      other.unit == unit &&
      other.amountPerDay == amountPerDay &&
      other.start == start &&
      other.startDate == startDate &&
      other.targetDate == targetDate &&
      other.window == window &&
      other.active == active &&
      other.sortOrder == sortOrder &&
      other.meta == meta;

  @override
  int get hashCode =>
      Object.hash(id, name, unit, amountPerDay, start, startDate, targetDate, window, active, sortOrder, meta);
}

/// One reading / listening session as the wird sees it (`quran_sessions`).
@immutable
class WirdSession {
  const WirdSession({
    required this.id,
    required this.day,
    required this.range,
    this.planId,
    this.mode = QuranSessionMode.read,
    required this.createdAt,
  });

  factory WirdSession.fromRow(QuranSessionRow row) {
    AyahRef ref(int s, int a) => AyahRef(s.clamp(1, 114), a < 1 ? 1 : a);
    var first = ref(row.fromSurah, row.fromAyah);
    var last = ref(row.toSurah, row.toAyah);
    if (last < first) (first, last) = (last, first);
    return WirdSession(
      id: row.id,
      day: row.day,
      range: AyahRange(first, last),
      planId: row.planId,
      mode: row.mode,
      createdAt: row.createdAt,
    );
  }

  final String id;
  final DateTime day;
  final AyahRange range;
  final String? planId;
  final QuranSessionMode mode;
  final DateTime createdAt;
}
