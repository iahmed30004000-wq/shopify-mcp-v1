/// Limits and small shared helpers of the couple specials ("How well do you
/// know me?", the weekly challenge and the cooperative goal).
///
/// Pure Dart (no Flutter).
library;

import 'dart:math' as math;

import '../../domain/together_bounds.dart';

/// Persistence and input bounds. Every stored JSON value stays well below
/// [TogetherBounds.maxStoredBytes] even when every list is full of
/// four-byte characters (checked by the persistence tests).
abstract final class SpecialsBounds {
  // ----------------------------------------------------------- know me

  /// A question, in characters (runes).
  static const int maxQuestionLength = 120;

  /// A category name, in characters.
  static const int maxCategoryNameLength = 24;

  /// Questions in the bank (defaults included).
  static const int maxQuestions = 150;

  /// Categories in the bank (defaults included).
  static const int maxCategories = 16;

  /// One answer or guess, in characters.
  static const int maxAnswerLength = 80;

  /// Questions per round (each asked about both players).
  static const List<int> roundSizes = [3, 5, 7, 10];
  static const int defaultRoundSize = 5;
  static const int maxRoundSize = 15;

  /// Recently asked question ids remembered (asked again only when the
  /// fresh ones run out).
  static const int maxRecentAsked = 120;

  /// A perfect round – every guess spot on – earns "Mind reader" from this
  /// many scored questions up.
  static const int perfectRoundMin = 5;

  // ----------------------------------------------------------- weekly

  /// A challenge, in characters.
  static const int maxChallengeLength = 90;

  /// Challenges in the list (defaults included).
  static const int maxChallenges = 64;

  /// Weeks kept in the challenge log (about three years); lifetime totals
  /// and streaks do not depend on the window.
  static const int maxWeeks = 156;

  /// Weekly challenge streak that earns "Challenge champions".
  static const int championStreak = 4;

  // ----------------------------------------------------------- goal

  static const int maxGoalTitleLength = 40;
  static const int maxRewardLength = 120;
  static const int maxUnitLength = 20;
  static const int maxGoalTarget = 9999;
  static const int maxCounter = 99999;

  /// Unlocked goals kept in "our rewards".
  static const int maxAchieved = 50;

  /// Goal points for a weekly challenge both players completed.
  static const int challengePoints = 5;

  /// Goal points for a match played together.
  static const int matchPoints = 1;

  // ----------------------------------------------------------- ids

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_.\-]{1,40}$');

  /// Whether [s] is a storable specials id (letters, digits, `_ . -`).
  static bool isValidId(String s) => _id.hasMatch(s);

  static const String _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';

  /// A fresh random id: [prefix] and ten base-36 characters.
  static String newId(String prefix, [math.Random? random]) {
    final r = random ?? math.Random.secure();
    return '$prefix${String.fromCharCodes([for (var i = 0; i < 10; i++) _alphabet.codeUnitAt(r.nextInt(36))])}';
  }

  /// Cleaned text (see [TogetherBounds.cleanText]).
  static String clean(Object? input, int maxRunes) => TogetherBounds.cleanText(input, maxRunes);
}

/// A default text in both app languages. The user's own edits replace it
/// with the text as typed.
final class BiText {
  const BiText(this.ar, this.en);

  final String ar;
  final String en;

  /// The text for [languageCode] (Arabic unless it is `en`).
  String of(String languageCode) => languageCode == 'en' ? en : ar;
}

/// Calendar weeks in the device's local time zone, as whole local days
/// ([TogetherDays.indexOf]) – no hour arithmetic, so a DST change at
/// midnight (Amman moved its clocks at 00:00 on Fridays until 2022) can
/// never shift a boundary.
abstract final class SpecialWeeks {
  /// Default first day of the week: Saturday (as in Jordan).
  static const int defaultWeekStart = DateTime.saturday;

  /// ISO weekday (1 = Monday … 7 = Sunday) of local day [day]
  /// (day 0 = Thursday 1 January 1970).
  static int weekdayOfDay(int day) => (day + 3) % 7 + 1;

  /// The first day of the week containing [day] for weeks starting on
  /// [weekStart] (an ISO weekday).
  static int startOf(int day, int weekStart) => day - (weekdayOfDay(day) - weekStart) % 7;

  /// The week (its first local day) containing [now].
  static int weekOf(DateTime now, int weekStart) => startOf(TogetherDays.indexOf(now), weekStart);

  /// The week a stored week belongs to under the current [weekStart]: the
  /// one containing its middle day. A log written under another week start
  /// keeps its order and its streaks when the setting changes.
  static int canonical(int storedStart, int weekStart) => startOf(storedStart + 3, weekStart);

  /// Local midnight of [day] (for display).
  static DateTime dateOf(int day) {
    final utc = DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true);
    return DateTime(utc.year, utc.month, utc.day);
  }

  /// Whole days left in [week] as of [now] (1 on its last day).
  static int daysLeft(int week, DateTime now) => (week + 7 - TogetherDays.indexOf(now)).clamp(1, 7);

  /// A stored week start (1..7), else [defaultWeekStart].
  static int parseWeekStart(Object? v) => v is int && v >= DateTime.monday && v <= DateTime.sunday ? v : defaultWeekStart;

  /// Stored day indices stay within what [DateTime] can hold.
  static int? parseDay(Object? v) => v is int && v.abs() <= 100000000 ? v : null;
}
