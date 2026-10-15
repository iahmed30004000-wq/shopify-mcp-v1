import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/typography.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../presentation/together_texts.dart';
import '../domain/coop_goal.dart';
import '../domain/know_me_bank.dart';
import '../domain/know_me_round.dart';
import '../domain/weekly_challenge.dart';

/// The couple specials' user-facing texts: default questions, categories
/// and challenges in the app language (the couple's own edits as typed),
/// numbers in the user's digit style.
class SpecialsTexts {
  const SpecialsTexts(this.tx);

  factory SpecialsTexts.of(BuildContext context) => SpecialsTexts(TogetherTexts.of(context));

  final TogetherTexts tx;

  L10n get l => tx.l;

  String get lang => tx.fmt.languageCode;

  String n(int v) => tx.n(v);

  String category(KnowMeCategory c) => c.nameIn(lang);

  String question(KnowMeQuestion q) => q.textIn(lang);

  String challenge(Challenge c) => c.textIn(lang);

  /// The weekday name of an ISO weekday (1 = Monday).
  String weekday(int isoWeekday) {
    // 1 January 2024 was a Monday.
    final date = DateTime(2024, 1, isoWeekday);
    try {
      return DateFormat.EEEE(lang).format(date);
    } on Object {
      return DateFormat.EEEE('en').format(date);
    }
  }

  String verdict(KnowMeVerdict v) => switch (v) {
    KnowMeVerdict.exact => l.togetherKnowMeExact,
    KnowMeVerdict.close => l.togetherKnowMeClose,
    KnowMeVerdict.miss => l.togetherKnowMeMiss,
  };

  String questions(int count) => tx.digits(l.togetherKnowMeQuestionsCount(count));

  String rounds(int count) => tx.digits(l.togetherKnowMeRoundsCount(count));

  String points(int count) => tx.digits(l.togetherGoalPointsCount(count));

  String weeks(int count) => tx.digits(l.togetherWeeksCount(count));

  String daysLeft(int count) => tx.digits(l.togetherWeeklyDaysLeft(count));

  String percent(double fraction) => tx.fmt.formatPercent(fraction);

  String goalTitle(CoopGoal g) => g.title.isNotEmpty ? g.title : l.togetherGoalTitle;

  String achievedTitle(AchievedGoal g) => g.title.isNotEmpty ? g.title : l.togetherGoalTitle;

  String unit(String unit) => unit.isNotEmpty ? unit : l.togetherGoalCounterDefaultUnit;

  String metric(GoalMetric m) => switch (m) {
    GoalMetric.points => l.togetherGoalMetricPoints,
    GoalMetric.counter => l.togetherGoalMetricCounter,
  };

  /// "12 of 50" with the user's digits.
  String progress(int current, int target) => l.togetherGoalProgress(n(current), n(target));
}

/// Icons and type details of the specials.
abstract final class SpecialsLook {
  /// Big numbers in the UI face: Reem Kufi (the display face) draws
  /// Arabic-Indic digits too stylised to read at a glance.
  static TextStyle? numerals(TextStyle? s) =>
      s?.copyWith(fontFamily: MadarTypography.uiFamily, fontVariations: const [], fontWeight: FontWeight.w700, height: 1.15);

  static IconData categoryIcon(String key) => switch (key) {
    'heart' => Icons.favorite_rounded,
    'sun' => Icons.wb_sunny_rounded,
    'album' => Icons.photo_album_rounded,
    'plane' => Icons.flight_takeoff_rounded,
    'spark' => Icons.auto_awesome_rounded,
    'split' => Icons.call_split_rounded,
    'star' => Icons.star_rounded,
    'home' => Icons.home_rounded,
    'book' => Icons.menu_book_rounded,
    'coffee' => Icons.coffee_rounded,
    'leaf' => Icons.eco_rounded,
    'moon' => Icons.nightlight_round,
    _ => Icons.label_rounded,
  };

  static IconData challengeIcon(String key) => switch (key) {
    'walk' => Icons.directions_walk_rounded,
    'cook' => Icons.soup_kitchen_rounded,
    'quran' => Icons.menu_book_rounded,
    'phoneOff' => Icons.phonelink_erase_rounded,
    'breakfast' => Icons.free_breakfast_rounded,
    'heart' => Icons.volunteer_activism_rounded,
    'family' => Icons.family_restroom_rounded,
    'sunset' => Icons.wb_twilight_rounded,
    'explore' => Icons.explore_rounded,
    'cards' => Icons.style_rounded,
    'photos' => Icons.photo_library_rounded,
    'plant' => Icons.local_florist_rounded,
    'charity' => Icons.handshake_rounded,
    'moon' => Icons.nightlight_round,
    'home' => Icons.cleaning_services_rounded,
    'learn' => Icons.school_rounded,
    'stars' => Icons.auto_awesome_rounded,
    'note' => Icons.mail_rounded,
    'dessert' => Icons.cake_rounded,
    'fitness' => Icons.fitness_center_rounded,
    'book' => Icons.auto_stories_rounded,
    'map' => Icons.map_rounded,
    'crescent' => Icons.brightness_3_rounded,
    'prayer' => Icons.mosque_rounded,
    'album' => Icons.child_care_rounded,
    'tea' => Icons.emoji_food_beverage_rounded,
    _ => Icons.flag_rounded,
  };
}
