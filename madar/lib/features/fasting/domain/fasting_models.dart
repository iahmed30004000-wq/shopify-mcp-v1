/// «تذكير الصيام» · the voluntary fasts (Part 9b) - kinds and settings.
///
/// Pure Dart. Nothing here knows about notifications, the database or the
/// screen; the integrator wires those around this folder.
library;

import 'package:meta/meta.dart';

/// Why a day can never be reminded (fasting it is forbidden).
enum ForbiddenFastDay {
  /// 1 Shawwal.
  eidAlFitr,

  /// 10 Dhu al-Hijjah.
  eidAlAdha,

  /// 11, 12 and 13 Dhu al-Hijjah.
  tashriq,
}

/// The kinds of voluntary fast that get a reminder.
///
/// **The declaration order is the priority** when one day carries several
/// kinds (a Monday that is also Ashura, a white day that is also a Thursday):
/// the earlier kind is the day's one reminder, the others ride along in
/// [FastReminder.alsoKinds]. Do not reorder; the notification ids and the
/// stored JSON use [id], never the index, but the priority is deliberate.
enum FastKind {
  arafah,
  ashura,
  tasua,

  /// The first nine days of Dhu al-Hijjah (the tenth is the Eid).
  dhuHijjahTen,
  sixShawwal,

  /// 13, 14 and 15 of the Hijri month (13 Dhu al-Hijjah is Tashriq: dropped).
  whiteDay,
  monday,
  thursday,

  /// «أكثروا من الصيام في محرّم»: one gentle in-month nudge, not an alarm.
  muharramMore,

  /// «أكثروا من الصيام في شعبان»: the same, for Sha'ban.
  shabanMore;

  String get id => name;

  /// A month-level nudge rather than a particular day's fast.
  bool get isNudge => this == muharramMore || this == shabanMore;

  static FastKind? fromId(Object? id) {
    for (final k in values) {
      if (k.name == id) return k;
    }
    return null;
  }
}

/// Everything the owner can tune about the fasting reminders. The defaults
/// are the owner's brief; a fresh install reminds all kinds.
@immutable
class FastingConfig {
  const FastingConfig({
    this.hijriOffset = 0,
    this.shawwalStartDay = 2,
    this.nudgeDay = 1,
    this.disabled = const {},
  });

  /// Days added to the calculated Hijri date (the owner's "a day earlier /
  /// later" setting). It moves **every** rule, not only the displayed date.
  /// The owner's spec is -1/0/+1; the value is clamped to the same -2...+2
  /// the prayer settings and [HijriCalendarMath] accept, so the display and
  /// the rules can never disagree.
  final int hijriOffset;

  /// First of the six days of Shawwal that are reminded. The owner did not
  /// say which six: default 2-7 Shawwal (1 Shawwal is the Eid).
  final int shawwalStartDay;

  /// Day of Muharram / Sha'ban on which the single "more fasting" nudge falls.
  final int nudgeDay;

  /// Kinds the owner switched off (everything else is on).
  final Set<FastKind> disabled;

  static const int maxOffset = 2;
  static const int shawwalDays = 6;

  int get effectiveOffset => hijriOffset.clamp(-maxOffset, maxOffset);

  /// 2...24, so all six days sit inside Shawwal and never on its first day.
  int get effectiveShawwalStart => shawwalStartDay.clamp(2, 30 - shawwalDays);

  /// 1...29; in a 29-day month a later nudge day lands on the last day.
  int get effectiveNudgeDay => nudgeDay.clamp(1, 29);

  bool isEnabled(FastKind kind) => !disabled.contains(kind);

  FastingConfig copyWith({int? hijriOffset, int? shawwalStartDay, int? nudgeDay, Set<FastKind>? disabled}) =>
      FastingConfig(
        hijriOffset: hijriOffset ?? this.hijriOffset,
        shawwalStartDay: shawwalStartDay ?? this.shawwalStartDay,
        nudgeDay: nudgeDay ?? this.nudgeDay,
        disabled: disabled ?? this.disabled,
      );

  Map<String, Object?> toJson() => {
    'hijriOffset': hijriOffset,
    'shawwalStartDay': shawwalStartDay,
    'nudgeDay': nudgeDay,
    'disabled': ([for (final k in disabled) k.id]..sort()),
  };

  factory FastingConfig.fromJson(Object? json) {
    if (json is! Map) return const FastingConfig();
    int n(Object? v, int fb) => v is num && v.isFinite ? v.round() : fb;
    final off = <FastKind>{};
    final raw = json['disabled'];
    if (raw is List) {
      for (final e in raw) {
        final k = FastKind.fromId(e);
        if (k != null) off.add(k);
      }
    }
    return FastingConfig(
      hijriOffset: n(json['hijriOffset'], 0).clamp(-maxOffset, maxOffset),
      shawwalStartDay: n(json['shawwalStartDay'], 2),
      nudgeDay: n(json['nudgeDay'], 1),
      disabled: off,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FastingConfig &&
      other.hijriOffset == hijriOffset &&
      other.shawwalStartDay == shawwalStartDay &&
      other.nudgeDay == nudgeDay &&
      other.disabled.length == disabled.length &&
      other.disabled.containsAll(disabled);

  @override
  int get hashCode => Object.hash(hijriOffset, shawwalStartDay, nudgeDay, Object.hashAllUnordered(disabled));
}
