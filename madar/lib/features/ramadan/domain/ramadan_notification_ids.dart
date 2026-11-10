/// What a Ramadan notification is for.
enum RamadanReminderKind {
  /// A little before Fajr, to eat suhoor.
  suhoor,

  /// Iftar (Maghrib).
  iftar,

  /// Taraweeh (after Isha).
  taraweeh,

  /// Today's khatmah portion.
  khatmah,

  /// A last-ten night.
  lastTenNight,
}

/// Ramadan's notification ids: the block 210000-210999 (repo blocks are
/// 100000-199999, Part 9b takes 200000-200999).
///
/// Day-bound reminders sit at `210000 + kind × 50 + day` (day 1…30), so
/// re-arming a day overwrites its own id and never touches another kind's.
/// 210900-210999 is for one-off ids.
abstract final class RamadanNotificationIds {
  static const int first = 210000;
  static const int last = 210999;

  /// "Ramadan begins tomorrow" (armed ahead of the first night).
  static const int startingSoon = 210900;

  /// The Eid / end-of-month note.
  static const int eid = 210901;

  static const int _kindStride = 50;

  /// The id of [kind] on day [day] of Ramadan (1…30).
  static int forDay(RamadanReminderKind kind, int day) {
    if (day < 1 || day > 30) throw RangeError.range(day, 1, 30, 'day');
    return first + kind.index * _kindStride + day;
  }

  static bool owns(int id) => id >= first && id <= last;
}
