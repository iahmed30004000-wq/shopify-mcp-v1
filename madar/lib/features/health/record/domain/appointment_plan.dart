import '../../../../core/db/database.dart';
import '../../../../core/notifications/notification_models.dart';

/// Upcoming / past split of appointments. Pure.
abstract final class AppointmentTimeline {
  /// An appointment stays "upcoming" until this long after it starts (it is
  /// probably still going on), unless it is marked done.
  static const Duration grace = Duration(hours: 3);

  static bool isUpcoming(AppointmentRow a, DateTime now) => !a.done && a.at.isAfter(now.subtract(grace));

  /// Upcoming soonest first; past most recent first.
  static ({List<AppointmentRow> upcoming, List<AppointmentRow> past}) split(
    Iterable<AppointmentRow> all,
    DateTime now,
  ) {
    final upcoming = <AppointmentRow>[];
    final past = <AppointmentRow>[];
    for (final a in all) {
      (isUpcoming(a, now) ? upcoming : past).add(a);
    }
    upcoming.sort(_byTime);
    past.sort((a, b) => _byTime(b, a));
    return (upcoming: upcoming, past: past);
  }

  /// The next appointment that is not done (or null).
  static AppointmentRow? next(Iterable<AppointmentRow> all, DateTime now) {
    final up = split(all, now).upcoming;
    return up.isEmpty ? null : up.first;
  }

  /// Calendar days from [now]'s day to [at]'s day (0 = today, 1 = tomorrow,
  /// negative = past).
  static int daysUntil(DateTime at, DateTime now) =>
      DateTime.utc(at.year, at.month, at.day).difference(DateTime.utc(now.year, now.month, now.day)).inDays;

  static int _byTime(AppointmentRow a, AppointmentRow b) {
    final t = a.at.compareTo(b.at);
    return t != 0 ? t : a.id.compareTo(b.id);
  }
}

/// One planned appointment reminder.
class AppointmentReminder {
  const AppointmentReminder({
    required this.id,
    required this.appointmentId,
    required this.appointmentAt,
    required this.offsetMinutes,
    required this.at,
  });

  /// Notification id inside [AppointmentReminderIds].
  final int id;
  final String appointmentId;
  final DateTime appointmentAt;

  /// How long before the appointment it fires.
  final int offsetMinutes;
  final DateTime at;

  @override
  String toString() => 'AppointmentReminder#$id($appointmentId −${offsetMinutes}m @ $at)';
}

/// The record's block inside the shared health namespace (150000–150999):
/// offsets 0–399 = 150000–150399. The medication-refill and worry-window
/// packages use other offsets of the same namespace; syncing only ever
/// touches ids for which [owns] is true.
abstract final class AppointmentReminderIds {
  static const NotificationNamespace namespace = NotificationNamespaces.health;
  static const int firstOffset = 0;
  static const int size = 400;

  /// Reminders per appointment (the settings allow at most this many).
  static const int perAppointment = 4;

  /// Appointments planned at once.
  static const int maxAppointments = size ~/ perAppointment;

  static int get first => namespace.first + firstOffset;
  static int get last => first + size - 1;

  static bool owns(int id) => id >= first && id <= last;

  /// Id of the [offsetIndex]-th reminder of the [slot]-th planned
  /// appointment.
  static int of(int slot, int offsetIndex) {
    if (slot < 0 || slot >= maxAppointments) throw RangeError.range(slot, 0, maxAppointments - 1, 'slot');
    if (offsetIndex < 0 || offsetIndex >= perAppointment) {
      throw RangeError.range(offsetIndex, 0, perAppointment - 1, 'offsetIndex');
    }
    return namespace.id(firstOffset + slot * perAppointment + offsetIndex);
  }
}

abstract final class AppointmentReminderPlanner {
  /// Appointments further ahead are planned on a later sync.
  static const Duration horizon = Duration(days: 45);

  /// Reminders for the upcoming, not-done appointments within [horizon]
  /// ([offsets] in minutes before; duplicates and non-positive values are
  /// dropped, at most [AppointmentReminderIds.perAppointment], largest
  /// first). Reminders already past are left out.
  static List<AppointmentReminder> plan({
    required Iterable<AppointmentRow> appointments,
    required DateTime now,
    required List<int> offsets,
  }) {
    final offs = normalizeOffsets(offsets);
    if (offs.isEmpty) return const [];
    final until = now.add(horizon);
    final upcoming = appointments.where((a) => !a.done && a.at.isAfter(now) && !a.at.isAfter(until)).toList()
      ..sort((a, b) {
        final t = a.at.compareTo(b.at);
        return t != 0 ? t : a.id.compareTo(b.id);
      });
    final out = <AppointmentReminder>[];
    for (var slot = 0; slot < upcoming.length && slot < AppointmentReminderIds.maxAppointments; slot++) {
      final a = upcoming[slot];
      for (var j = 0; j < offs.length; j++) {
        final at = a.at.subtract(Duration(minutes: offs[j]));
        if (!at.isAfter(now)) continue;
        out.add(
          AppointmentReminder(
            id: AppointmentReminderIds.of(slot, j),
            appointmentId: a.id,
            appointmentAt: a.at,
            offsetMinutes: offs[j],
            at: at,
          ),
        );
      }
    }
    return out;
  }

  static List<int> normalizeOffsets(List<int> offsets) {
    final set = offsets.where((m) => m > 0).toSet().toList()..sort((a, b) => b.compareTo(a));
    return set.take(AppointmentReminderIds.perAppointment).toList();
  }
}
