import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/today/domain/day_snapshot.dart';
import 'package:madar/features/today/domain/objective_engine.dart';
import 'package:madar/features/today/domain/objective_state.dart';

/// A Tuesday; the clock times mirror `PrayerDayTimes.placeholder`.
final DateTime day = DateTime(2026, 11, 10);

DateTime at(int h, int m, {int dayOffset = 0}) => DateTime(2026, 11, 10 + dayOffset, h, m);

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _prayerTimes = <Prayer, (int, int)>{
  Prayer.fajr: (4, 45),
  Prayer.dhuhr: (12, 25),
  Prayer.asr: (15, 50),
  Prayer.maghrib: (18, 30),
  Prayer.isha: (19, 50),
};

/// The five prayers of [day]; [logged] / [adhanOff] pick which are logged or
/// have the adhan off. Fajr ends at sunrise (06:10), Isha at the next Fajr.
List<PrayerSlot> prayers({Set<Prayer> logged = const {}, Set<Prayer> adhanOff = const {}, int dayOffset = 0}) => [
  for (final e in _prayerTimes.entries)
    PrayerSlot(
      prayer: e.key,
      at: at(e.value.$1, e.value.$2, dayOffset: dayOffset),
      endsAt: e.key == Prayer.fajr
          ? at(6, 10, dayOffset: dayOffset)
          : e.key == Prayer.isha
          ? at(4, 45, dayOffset: dayOffset + 1)
          : null,
      logged: logged.contains(e.key),
      adhanOn: !adhanOff.contains(e.key),
    ),
];

List<AdhkarWindowSlot> standardAdhkar({bool morningDone = false, bool eveningDone = false}) => AdhkarWindowSlot.standard(
  fajr: at(4, 45),
  dhuhr: at(12, 25),
  asr: at(15, 50),
  isha: at(19, 50),
  morningDone: morningDone,
  eveningDone: eveningDone,
);

/// Runs the engine every 5 minutes from [from] to 23:55 and returns only the
/// changes as `HH:mm=id` (`-` = nothing now): the shape of the whole day.
List<String> timeline(
  DaySnapshot Function(DateTime now) build, {
  ObjectiveState state = const ObjectiveState.empty(),
  ObjectiveEngine engine = const ObjectiveEngine(),
  DateTime? from,
  DateTime? to,
}) {
  final out = <String>[];
  String? last;
  final end = to ?? at(23, 55);
  for (var t = from ?? at(4, 0); !t.isAfter(end); t = t.add(const Duration(minutes: 5))) {
    final id = engine.next(build(t), state).current?.id ?? '-';
    if (id != last) {
      out.add('${hhmm(t)}=$id');
      last = id;
    }
  }
  return out;
}
