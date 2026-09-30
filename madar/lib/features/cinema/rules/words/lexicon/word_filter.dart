/// Profanity / inappropriate-word filter for the word games
/// (assets/games/arabic_word_filter.json).
///
/// * blocked – profanity, sexual terms and slurs: never shown, never
///   accepted as guesses, removed from the lexicon.
/// * sensitive – violence, drugs, alcohol, death, insults: valid guesses but
///   never answers and never allowed to appear by accident in a generated
///   grid.
/// * allowed – innocent look-alikes that would otherwise match (كسكس …).
///
/// Matching uses [WordFilter.filterKey] (plain letters, alef family → ا,
/// ى → ي; ة stays distinct from ه so a feminine ending is never taken for the
/// clitic ـه) and strips the listed clitics around a core of at least three
/// letters: وال…ـها, بال…ـهم …
library;

import 'dart:convert';

import '../core/arabic_text.dart';

/// The word filter.
final class WordFilter {
  /// Builds a filter from word lists.
  WordFilter({
    required Iterable<String> blocked,
    required Iterable<String> sensitive,
    Iterable<String> allowed = const [],
    List<String>? prefixes,
    List<String>? suffixes,
  }) : _blocked = {for (final w in blocked) filterKey(w)},
       _sensitive = {for (final w in sensitive) filterKey(w)},
       _allowed = {for (final w in allowed) filterKey(w)},
       _prefixes = ['', ...?(prefixes ?? defaultPrefixes)],
       _suffixes = ['', ...?(suffixes ?? defaultSuffixes)];

  /// Parses assets/games/arabic_word_filter.json.
  factory WordFilter.parse(String jsonText) {
    final j = jsonDecode(jsonText) as Map<String, Object?>;
    List<String> strings(String key) => [for (final v in (j[key] as List<Object?>? ?? const [])) v! as String];
    return WordFilter(
      blocked: strings('blocked'),
      sensitive: strings('sensitive'),
      allowed: strings('allowed'),
      prefixes: j.containsKey('prefixes') ? strings('prefixes') : null,
      suffixes: j.containsKey('suffixes') ? strings('suffixes') : null,
    );
  }

  /// An empty filter (tests, previews).
  factory WordFilter.none() => WordFilter(blocked: const [], sensitive: const []);

  /// Clitic prefixes stripped when matching.
  static const List<String> defaultPrefixes = [
    'و', 'ف', 'ب', 'ل', 'ك', 'ال', 'وال', 'فال', 'بال', 'كال', 'لل', 'ولل', 'فلل', 'وب', 'ول', 'فب', //
  ];

  /// Clitic / inflection suffixes stripped when matching.
  static const List<String> defaultSuffixes = [
    'ه', 'ها', 'هم', 'هن', 'هما', 'ك', 'كم', 'كن', 'ي', 'نا', 'ات', 'ان', 'ين', 'ون', 'تي', 'ته', 'تها', 'تك', //
    'تان', 'تين',
  ];

  final Set<String> _blocked, _sensitive, _allowed;
  final List<String> _prefixes, _suffixes;

  /// Matching key (see the library comment).
  static String filterKey(String word) {
    final p = ArabicText.plain(word);
    return p.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا').replaceAll('ى', 'ي');
  }

  bool _hits(String word, Set<String> bag) {
    final w = filterKey(word);
    if (_allowed.contains(w)) return false;
    if (bag.contains(w)) return true;
    for (final p in _prefixes) {
      if (!w.startsWith(p)) continue;
      for (final s in _suffixes) {
        if ((p.isEmpty && s.isEmpty) || !w.endsWith(s)) continue;
        final end = w.length - s.length;
        if (end - p.length < 3) continue;
        if (bag.contains(w.substring(p.length, end))) return true;
      }
    }
    return false;
  }

  /// Profanity, sexual term or slur.
  bool isBlocked(String word) => _hits(word, _blocked);

  /// Violent / drug / alcohol / death / insult word.
  bool isSensitive(String word) => _hits(word, _sensitive);

  /// Blocked or sensitive.
  bool isUnsuitable(String word) => isBlocked(word) || isSensitive(word);

  /// Folded letter sequences (3+ letters) that must not appear by accident
  /// in a generated letter grid, in any direction.
  late final List<String> unsuitableSequences = {
    for (final w in [..._blocked, ..._sensitive])
      if (ArabicText.fold(w).length >= 3) ArabicText.fold(w),
  }.toList()..sort();

  /// Number of blocked words.
  int get blockedCount => _blocked.length;

  /// Number of sensitive words.
  int get sensitiveCount => _sensitive.length;
}
