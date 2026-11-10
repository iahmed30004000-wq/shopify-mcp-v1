/// Capitals & Flags question builder: capital → country, country → capital
/// and flag → country, with distractors from the same continent.
///
/// Countries whose capital is disputed never appear in the two capital
/// modes, and a country whose capital has the same name (Kuwait, Tunis …)
/// is skipped in capital → country (the prompt would give it away).
/// Levels: 1 for widely known states (G20, Arab League and a few others),
/// 3 for microstates and small island states, 2 otherwise.
library;

import '../core/words_rng.dart';
import '../quiz/quiz_engine.dart';
import 'countries.dart';

/// Question kinds.
enum CapitalsQuizMode {
  /// "What is the capital of X?"
  countryToCapital,

  /// "X is the capital of which country?"
  capitalToCountry,

  /// "Whose flag is this?" (payload `flag` = ISO code).
  flagToCountry,
}

/// Builds questions.
final class CapitalsQuiz {
  /// Creates a builder over [countries].
  CapitalsQuiz(List<Country> countries) : countries = List.unmodifiable(countries);

  /// All countries.
  final List<Country> countries;

  static const Set<String> _wellKnown = {
    'AR', 'AU', 'BR', 'CA', 'CN', 'FR', 'DE', 'IN', 'ID', 'IT', 'JP', 'KR', 'MX', 'RU', 'SA', 'ZA', 'TR', 'GB', //
    'US', 'DZ', 'BH', 'KM', 'DJ', 'EG', 'IQ', 'JO', 'KW', 'LB', 'LY', 'MR', 'MA', 'OM', 'PS', 'QA', 'SO', 'SD',
    'SY', 'TN', 'AE', 'YE', 'PK', 'IR', 'ES', 'MY', 'NG',
  };

  static const Set<String> _obscure = {
    'AD', 'AG', 'BB', 'DM', 'FM', 'GD', 'KI', 'KN', 'LC', 'LI', 'MH', 'MC', 'NR', 'PW', 'SB', 'SM', 'ST', 'TO', //
    'TV', 'VC', 'VU', 'WS', 'CV', 'SC', 'MV', 'BT', 'TL', 'SZ', 'LS', 'KM',
  };

  /// Difficulty level of a country.
  static int levelOf(Country c) => _wellKnown.contains(c.iso) ? 1 : (_obscure.contains(c.iso) ? 3 : 2);

  bool _eligible(Country c, CapitalsQuizMode mode) => switch (mode) {
    CapitalsQuizMode.countryToCapital => !c.capitalDisputed,
    CapitalsQuizMode.capitalToCountry => !c.capitalDisputed && c.capital.ar != c.name.ar && c.capital.en != c.name.en,
    CapitalsQuizMode.flagToCountry => true,
  };

  /// Builds [count] questions of [mode] (no country twice), optionally
  /// limited to [continent] and [levels].
  List<QuizQuestion> build(
    CapitalsQuizMode mode, {
    required int count,
    required int seed,
    Continent? continent,
    Set<int>? levels,
    bool includeObservers = true,
  }) {
    final rng = WordsRng(WordsRng.mix([seed, mode.index]));
    final pool = rng.shuffle([
      for (final c in countries)
        if (_eligible(c, mode) &&
            (continent == null || c.continent == continent) &&
            (levels == null || levels.contains(levelOf(c))) &&
            (includeObservers || !c.isObserver))
          c,
    ]);
    return [for (final c in pool.take(count)) question(c, mode, rng)];
  }

  /// One question about [c].
  QuizQuestion question(Country c, CapitalsQuizMode mode, WordsRng rng) {
    final others = [for (final o in countries) if (o.iso != c.iso && _eligible(o, mode)) o];
    final same = rng.shuffle([for (final o in others) if (o.continent == c.continent) o]);
    final rest = rng.shuffle([for (final o in others) if (o.continent != c.continent) o]);
    final distractors = [...same, ...rest].take(3).toList();
    LocalizedText label(Country x) => mode == CapitalsQuizMode.countryToCapital ? x.capital : x.name;
    final options = [label(c), ...distractors.map(label)];
    final order = rng.shuffle(List<int>.generate(options.length, (i) => i));
    final prompt = switch (mode) {
      CapitalsQuizMode.countryToCapital => c.name,
      CapitalsQuizMode.capitalToCountry => c.capital,
      CapitalsQuizMode.flagToCountry => LocalizedText(c.iso, c.iso),
    };
    return QuizQuestion(
      id: '${mode.name}-${c.iso}',
      category: mode.name,
      level: levelOf(c),
      prompt: prompt,
      options: [for (final i in order) options[i]],
      answerIndex: order.indexOf(0),
      payload: {'iso': c.iso, if (mode == CapitalsQuizMode.flagToCountry) 'flag': c.iso},
    );
  }
}
