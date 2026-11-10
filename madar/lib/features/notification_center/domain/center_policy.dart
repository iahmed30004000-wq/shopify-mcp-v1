import 'package:flutter/foundation.dart';

import 'center_models.dart';

/// A notification snoozed from the center: [notice] as it first arrived,
/// arriving again at [until].
@immutable
class SnoozedNotice {
  const SnoozedNotice({required this.notice, required this.until});

  final CenterNotice notice;
  final DateTime until;

  /// The firing of the snooze (same id, new moment).
  CenterNotice get again => notice.copyWith(at: until.toUtc());

  Map<String, Object?> toJson() => {'n': notice.toJson(), 'u': until.millisecondsSinceEpoch};

  static SnoozedNotice? fromJson(Object? json) {
    if (json is! Map) return null;
    final n = CenterNotice.fromJson(json['n']);
    final u = json['u'];
    if (n == null || u is! int) return null;
    return SnoozedNotice(notice: n, until: DateTime.fromMillisecondsSinceEpoch(u));
  }

  @override
  bool operator ==(Object other) => other is SnoozedNotice && other.notice == notice && other.until == until;

  @override
  int get hashCode => Object.hash(notice, until);
}

/// What the user asked the center to hold back (pure, JSON-persisted):
///
/// * [mutedUntil] – a group is quiet until then: its notifications due
///   before that moment never sound (they stay listed, marked muted);
/// * [skipped] – single upcoming firings ([CenterNotice.key]) that must not
///   arrive;
/// * [snoozed] – delivered notifications re-armed for later, by id.
///
/// Enforced by `NotificationGate` (the platform decorator the notification
/// service schedules through); the center only edits and persists it.
@immutable
class CenterPolicy {
  const CenterPolicy({this.mutedUntil = const {}, this.skipped = const {}, this.snoozed = const {}});

  final Map<NotificationGroup, DateTime> mutedUntil;
  final Set<String> skipped;
  final Map<int, SnoozedNotice> snoozed;

  static const empty = CenterPolicy();

  bool get isEmpty => mutedUntil.isEmpty && skipped.isEmpty && snoozed.isEmpty;

  /// The end of [group]'s mute when it is still muted at [now].
  DateTime? muteOf(NotificationGroup group, DateTime now) {
    final until = mutedUntil[group];
    return until != null && until.isAfter(now) ? until : null;
  }

  /// Whether a notification of [group] firing at [at] is held back by a mute.
  bool mutes(NotificationGroup group, DateTime at) {
    final until = mutedUntil[group];
    return until != null && at.isBefore(until);
  }

  bool skips(CenterNotice notice) => skipped.contains(notice.key);

  /// Why [notice] (of [group]) must not reach the system, or null.
  CenterItemState? holdOf(CenterNotice notice, NotificationGroup group, {required DateTime now}) {
    if (skips(notice)) return CenterItemState.skipped;
    final at = notice.at ?? now;
    if (mutes(group, at)) return CenterItemState.muted;
    return null;
  }

  CenterPolicy mute(NotificationGroup group, DateTime until) => _copy(mutedUntil: {...mutedUntil, group: until});

  CenterPolicy unmute(NotificationGroup group) =>
      mutedUntil.containsKey(group) ? _copy(mutedUntil: {...mutedUntil}..remove(group)) : this;

  CenterPolicy skip(CenterNotice notice) => _copy(skipped: {...skipped, notice.key});

  CenterPolicy unskip(CenterNotice notice) =>
      skipped.contains(notice.key) ? _copy(skipped: {...skipped}..remove(notice.key)) : this;

  CenterPolicy snooze(SnoozedNotice s) => _copy(snoozed: {...snoozed, s.notice.id: s});

  CenterPolicy dropSnooze(int id) => snoozed.containsKey(id) ? _copy(snoozed: {...snoozed}..remove(id)) : this;

  /// Forgets what no longer matters at [now]: ended mutes, skips of
  /// moments already past, snoozes that have arrived.
  CenterPolicy pruned(DateTime now) {
    final mutes = {
      for (final e in mutedUntil.entries)
        if (e.value.isAfter(now)) e.key: e.value,
    };
    final skips = {
      for (final k in skipped)
        if ((CenterNotice.atOfKey(k) ?? now).isAfter(now.subtract(const Duration(hours: 1)))) k,
    };
    final snoozes = {
      for (final e in snoozed.entries)
        if (e.value.until.isAfter(now)) e.key: e.value,
    };
    if (mutes.length == mutedUntil.length && skips.length == skipped.length && snoozes.length == snoozed.length) {
      return this;
    }
    return CenterPolicy(mutedUntil: mutes, skipped: skips, snoozed: snoozes);
  }

  CenterPolicy _copy({
    Map<NotificationGroup, DateTime>? mutedUntil,
    Set<String>? skipped,
    Map<int, SnoozedNotice>? snoozed,
  }) => CenterPolicy(
    mutedUntil: mutedUntil ?? this.mutedUntil,
    skipped: skipped ?? this.skipped,
    snoozed: snoozed ?? this.snoozed,
  );

  Map<String, Object?> toJson() => {
    'mutes': {for (final e in mutedUntil.entries) e.key.name: e.value.millisecondsSinceEpoch},
    'skips': skipped.toList()..sort(),
    'snoozes': [for (final s in snoozed.values) s.toJson()],
  };

  static CenterPolicy fromJson(Object? json) {
    if (json is! Map) return empty;
    final mutes = <NotificationGroup, DateTime>{};
    final m = json['mutes'];
    if (m is Map) {
      for (final e in m.entries) {
        final g = NotificationGroup.byName(e.key);
        if (g != null && e.value is int) mutes[g] = DateTime.fromMillisecondsSinceEpoch(e.value as int);
      }
    }
    final s = json['skips'];
    final z = json['snoozes'];
    return CenterPolicy(
      mutedUntil: mutes,
      skipped: {if (s is List) ...s.whereType<String>()},
      snoozed: {
        if (z is List)
          for (final sn in [for (final raw in z) ?SnoozedNotice.fromJson(raw)]) sn.notice.id: sn,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CenterPolicy &&
      mapEquals(other.mutedUntil, mutedUntil) &&
      setEquals(other.skipped, skipped) &&
      mapEquals(other.snoozed, snoozed);

  @override
  int get hashCode => Object.hash(mutedUntil.length, skipped.length, snoozed.length);

  @override
  String toString() => 'CenterPolicy(mutes: $mutedUntil, skips: $skipped, snoozes: ${snoozed.keys})';
}

/// The mute lengths the center offers.
enum MuteLength {
  hour,
  fourHours,
  untilMorning,
  week;

  /// When a mute started at [now] ends ([morningHour] local: "until
  /// tomorrow morning" – the next morning after [now]).
  DateTime endFrom(DateTime now, {int morningHour = 7}) => switch (this) {
    MuteLength.hour => now.add(const Duration(hours: 1)),
    MuteLength.fourHours => now.add(const Duration(hours: 4)),
    MuteLength.untilMorning => _nextMorning(now, morningHour),
    MuteLength.week => now.add(const Duration(days: 7)),
  };

  static DateTime _nextMorning(DateTime now, int hour) {
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day, hour);
    // Before dawn "tomorrow morning" is still today's morning.
    return local.isBefore(today.subtract(const Duration(hours: 4)))
        ? today
        : DateTime(local.year, local.month, local.day + 1, hour);
  }
}

/// The snooze lengths the center offers.
const List<Duration> centerSnoozeLengths = [Duration(minutes: 10), Duration(minutes: 30), Duration(hours: 1)];
