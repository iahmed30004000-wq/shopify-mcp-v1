/// UN member and observer states for Capitals & Flags
/// (assets/games/countries.json).
library;

import 'dart:convert';

import '../quiz/quiz_engine.dart';
import 'flag_spec.dart';

/// Continent grouping (UN M49; Central America and the Caribbean belong to
/// North America).
enum Continent {
  /// Africa.
  africa,

  /// Asia (including the Middle East, the Caucasus and Cyprus).
  asia,

  /// Europe.
  europe,

  /// North and Central America and the Caribbean.
  northAmerica,

  /// South America.
  southAmerica,

  /// Oceania.
  oceania;

  /// Parses the asset spelling (`north_america` …).
  static Continent parse(String s) => switch (s) {
    'africa' => africa,
    'asia' => asia,
    'europe' => europe,
    'north_america' => northAmerica,
    'south_america' => southAmerica,
    'oceania' => oceania,
    _ => throw FormatException('unknown continent', s),
  };
}

/// A state.
final class Country {
  /// Creates a country.
  const Country({
    required this.iso,
    required this.name,
    required this.capital,
    required this.continent,
    required this.isObserver,
    required this.flag,
    this.altCapitals = const [],
    this.capitalDisputed = false,
    this.needsReview = false,
    this.note,
  });

  /// ISO 3166-1 alpha-2 code.
  final String iso;

  /// Short name.
  final LocalizedText name;

  /// Capital.
  final LocalizedText capital;

  /// Other capitals / seats of government.
  final List<LocalizedText> altCapitals;

  /// Continent.
  final Continent continent;

  /// UN observer state (Holy See, Palestine).
  final bool isObserver;

  /// The capital's status is disputed (excluded from capital questions).
  final bool capitalDisputed;

  /// Facts flagged for human review (recent or pending changes).
  final bool needsReview;

  /// Explanatory note (English).
  final String? note;

  /// Code-drawable flag.
  final FlagSpec flag;

  /// Parses all countries.
  static List<Country> parseAll(String jsonText) {
    final j = jsonDecode(jsonText) as Map<String, Object?>;
    return List.unmodifiable([
      for (final raw in j['countries']! as List<Object?>)
        () {
          final m = raw! as Map<String, Object?>;
          return Country(
            iso: m['iso']! as String,
            name: LocalizedText.fromJson(m['name']),
            capital: LocalizedText.fromJson(m['capital']),
            altCapitals: [for (final a in (m['altCapitals'] as List<Object?>? ?? const [])) LocalizedText.fromJson(a)],
            continent: Continent.parse(m['continent']! as String),
            isObserver: m['status'] == 'observer',
            capitalDisputed: m['capitalDisputed'] == true,
            needsReview: m['review'] == true,
            note: m['note'] as String?,
            flag: FlagSpec.fromJson(m['flag']! as Map<String, Object?>),
          );
        }(),
    ]);
  }
}
