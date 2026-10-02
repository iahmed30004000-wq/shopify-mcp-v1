/// One prayer day as the tracker shows it: every tracked prayer with its
/// window, whether it is due yet and its log. Pure Dart.
library;

import 'package:flutter/foundation.dart' show immutable;

import '../../../core/db/database.dart' show PrayerLogRow;
import '../../../core/domain/enums.dart';
import '../../orbit/domain/prayer_schedule.dart';
import 'tracker_prayers.dart';
import 'tracker_timing.dart';

/// A tracked prayer on one day.
@immutable
class TrackerSlot {
  const TrackerSlot({required this.prayer, required this.window, required this.timing, this.log});

  final Prayer prayer;
  final SlotWindow window;
  final SlotTiming timing;
  final PrayerLogRow? log;

  PrayerStatus? get status => log?.status;

  bool get isObligatory => TrackerPrayers.isObligatory(prayer);

  /// Its time has come (upcoming prayers cannot be logged yet).
  bool get canLog => timing != SlotTiming.upcoming;

  bool get isLogged => log != null;

  /// Prayed on time, late or made up.
  bool get prayed => status?.counts ?? false;

  bool get inJamaah => log?.inJamaah ?? false;

  bool get atMosque => log?.atMosque ?? false;

  /// An obligatory prayer whose time is running and which has not been
  /// logged yet (voluntary prayers are never "due").
  bool get isDue => isObligatory && timing == SlotTiming.open && log == null;

  /// Its time has ended without a log.
  bool get unloggedPast => timing == SlotTiming.closed && log == null;
}

/// A prayer day with all its tracked prayers.
@immutable
class TrackerDayView {
  const TrackerDayView({required this.day, required this.now, required this.times, required this.slots});

  /// Builds the view of prayer day [day] at [now] from its [times], the
  /// next day's times (the night ends at the next Fajr) and its [logs].
  factory TrackerDayView.build({
    required DateTime day,
    required DateTime now,
    required DayTimes times,
    required DayTimes nextDay,
    required Iterable<PrayerLogRow> logs,
  }) {
    final byPrayer = {for (final l in logs) l.prayer: l};
    return TrackerDayView(
      day: DateTime(day.year, day.month, day.day),
      now: now,
      times: times,
      slots: {
        for (final p in [...TrackerPrayers.obligatory, ...TrackerPrayers.voluntary])
          p: () {
            final window = TrackerTiming.windowOf(p, times, nextDay);
            return TrackerSlot(prayer: p, window: window, timing: window.at(now), log: byPrayer[p]);
          }(),
      },
    );
  }

  final DateTime day;
  final DateTime now;
  final DayTimes times;
  final Map<Prayer, TrackerSlot> slots;

  TrackerSlot operator [](Prayer p) => slots[p]!;

  List<TrackerSlot> get obligatory => [for (final p in TrackerPrayers.obligatory) slots[p]!];

  List<TrackerSlot> get nawafil => [for (final p in TrackerPrayers.nawafil) slots[p]!];

  /// Obligatory prayers prayed (on time, late or made up).
  int get prayedCount => obligatory.where((s) => s.prayed).length;

  int get onTimeCount => obligatory.where((s) => s.status == PrayerStatus.prayed).length;

  int get jamaahCount => obligatory.where((s) => s.prayed && s.inJamaah).length;

  int get mosqueCount => obligatory.where((s) => s.prayed && s.atMosque).length;

  /// Voluntary prayers logged.
  int get voluntaryCount => [for (final p in TrackerPrayers.voluntary) slots[p]!].where((s) => s.prayed).length;

  /// All five obligatory prayers prayed or made up.
  bool get complete => prayedCount == TrackerPrayers.obligatory.length;

  /// The next obligatory prayer whose time has not come (null once all are
  /// due).
  TrackerSlot? get nextUpcoming {
    for (final s in obligatory) {
      if (s.timing == SlotTiming.upcoming) return s;
    }
    return null;
  }

  /// The obligatory prayer whose time is running now, if any.
  TrackerSlot? get current {
    for (final s in obligatory) {
      if (s.timing == SlotTiming.open) return s;
    }
    return null;
  }
}
