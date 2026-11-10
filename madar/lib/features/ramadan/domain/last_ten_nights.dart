import 'package:flutter/foundation.dart';

/// How one night of Ramadan is marked.
@immutable
class NightMark {
  const NightMark({required this.night, required this.isLastTen, required this.isOddSought});

  final int night;

  /// One of the last ten nights (21 to the end of the month).
  final bool isLastTen;

  /// 21, 23, 25, 27 or 29: the nights usually sought for Laylat al-Qadr.
  final bool isOddSought;
}

/// The last ten nights of Ramadan.
///
/// CONVENTION: night N is the evening that BEGINS day N of Ramadan (the
/// Islamic day starts at Maghrib), so "the 27th night" starts at the Maghrib
/// of 26 Ramadan. See `RamadanSpan.eveningOfNight` for the civil date.
///
/// The last ten are nights 21 to the end of the month (21-30, or 21-29 in a
/// 29-day month, which has no night 30). Whether the sought nights follow
/// this count in a 29-day month is a religious question for the owner's
/// scholar (see the report), not decided here.
abstract final class LastTenNights {
  static const int first = 21;

  /// The odd nights usually sought for Laylat al-Qadr.
  static const List<int> oddSoughtNights = [21, 23, 25, 27, 29];

  /// Content slot of the Laylat al-Qadr supplication. The text, its source and
  /// its grading are supplied by the owner; this id is only where it plugs in.
  static const String qadrSupplicationSlotId = 'ramadan.qadr.supplication';

  static bool isLastTen(int night, {int monthLength = 30}) => night >= first && night <= monthLength;

  static bool isOddSought(int night) => oddSoughtNights.contains(night);

  /// Nights 21…[monthLength].
  static List<int> nights({int monthLength = 30}) => [for (var n = first; n <= monthLength; n++) n];

  static NightMark markOf(int night, {int monthLength = 30}) => NightMark(
    night: night,
    isLastTen: isLastTen(night, monthLength: monthLength),
    isOddSought: isOddSought(night),
  );
}
