/// The few choices «السفرة» remembers, and where its shopping lists live.
///
/// Pure Dart (no Flutter, no database). Stored as one JSON value in the
/// encrypted key/value store, like `FastingPlan` and `AdhanSettings`.
library;

import 'package:meta/meta.dart';

import 'no_repeat.dart';
import 'pantry.dart';
import 'pantry_match.dart';

/// Her settings.
@immutable
class SufraSettings {
  const SufraSettings({
    this.noRepeatDays = NoRepeat.defaultWindowDays,
    this.expiryWarningDays = PantryStock.defaultExpiryWarningDays,
    this.nearlyLimit = PantryMatcher.defaultNearlyLimit,
    this.defaultPeople,
    this.dietMode = false,
  });

  factory SufraSettings.fromJson(Object? json) {
    if (json is! Map) return const SufraSettings();
    final map = json.cast<String, Object?>();
    int? intOf(String key) {
      final v = map[key];
      return v is num && v.isFinite ? v.round() : null;
    }

    return SufraSettings(
      noRepeatDays: NoRepeat.window(intOf('noRepeatDays')),
      expiryWarningDays: intOf('expiryWarningDays')?.clamp(0, 365) ?? PantryStock.defaultExpiryWarningDays,
      nearlyLimit: intOf('nearlyLimit')?.clamp(1, 20) ?? PantryMatcher.defaultNearlyLimit,
      defaultPeople: () {
        final v = intOf('defaultPeople');
        return v == null || v <= 0 ? null : v;
      }(),
      dietMode: map['dietMode'] == true,
    );
  }

  /// The one key this lives under.
  static const String storageKey = 'sufra.settings';

  /// «مش بآخر كم يوم» – her no-repeat window, 0 to turn it off.
  final int noRepeatDays;

  /// How many days before an expiry an item starts to warn.
  final int expiryWarningDays;

  /// How many missing ingredients still counts as a near match.
  final int nearlyLimit;

  /// How many usually eat (null = she never said; nothing is scaled).
  final int? defaultPeople;

  /// **The owner's switch.** Off by default and on a fresh install: while
  /// it is off, «السفرة» is handed [DietLink.off] and knows nothing about
  /// his meal plan, his conditions or anything else of his. Turning it on
  /// is his decision on his own copy, never hers and never automatic.
  final bool dietMode;

  Map<String, Object?> toJson() => {
    'noRepeatDays': noRepeatDays,
    'expiryWarningDays': expiryWarningDays,
    'nearlyLimit': nearlyLimit,
    'defaultPeople': ?defaultPeople,
    'dietMode': dietMode,
  };

  SufraSettings copyWith({
    int? noRepeatDays,
    int? expiryWarningDays,
    int? nearlyLimit,
    int? defaultPeople,
    bool? dietMode,
    bool clearDefaultPeople = false,
  }) => SufraSettings(
    noRepeatDays: NoRepeat.window(noRepeatDays ?? this.noRepeatDays),
    expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
    nearlyLimit: nearlyLimit ?? this.nearlyLimit,
    defaultPeople: clearDefaultPeople ? null : (defaultPeople ?? this.defaultPeople),
    dietMode: dietMode ?? this.dietMode,
  );

  @override
  bool operator ==(Object other) =>
      other is SufraSettings &&
      other.noRepeatDays == noRepeatDays &&
      other.expiryWarningDays == expiryWarningDays &&
      other.nearlyLimit == nearlyLimit &&
      other.defaultPeople == defaultPeople &&
      other.dietMode == dietMode;

  @override
  int get hashCode => Object.hash(noRepeatDays, expiryWarningDays, nearlyLimit, defaultPeople, dietMode);
}

/// Where «السفرة»'s shopping lists hang on Part 3b's list engine.
///
/// The engine addresses a list by `(hostTable, hostId)` and asks nothing
/// about what a host is, so the kitchen needs no second list
/// implementation – only two host names:
///
/// * [houseTable] / [houseId] – the **standing** list of the house
///   («اللي ناقص البيت»). The pantry is one place, not a row, so its list
///   hangs on a fixed singleton host; everything low or finished flows
///   into it and she ticks it in the shop.
/// * [recipesTable] + a recipe's id – **what is missing for this dish**.
///   That list belongs to the dish: it is re-made from the near match
///   whenever she asks, and it is deleted with the recipe.
abstract final class PantryLists {
  /// The singleton host of the house's standing shopping list. The same
  /// two words `ListHost.pantry` names on the engine's side.
  static const String houseTable = 'pantry';
  static const String houseId = 'house';

  /// A recipe's own «ناقص لهذي الطبخة» list (`ListHost.recipes`). The
  /// recipe **is** a row, so the all-lists screen reads the dish's name
  /// off it with no help from here.
  static const String recipesTable = 'recipes';
}
