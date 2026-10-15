/// Typing Race passages (assets/games/typing_passages.json) and the Quran
/// text they reference.
///
/// Quran passages store only a reference (sura, first and last ayah). Their
/// text is read verbatim from the bundled Tanzil file
/// (assets/quran/quran-uthmani.txt) by [QuranTextIndex] – it is never copied
/// or altered; typing comparison happens on normalised units (see
/// typing_text.dart) while the display shows the exact text.
library;

import 'dart:convert';

import '../core/words_rng.dart';
import '../quiz/quiz_engine.dart';

/// Ayah lookup over Tanzil's "text with aya numbers" format (`sura|aya|text`).
final class QuranTextIndex {
  QuranTextIndex._(this._ayat);

  /// Parses the file content.
  factory QuranTextIndex.parse(String tanzilText) {
    final ayat = <int, String>{};
    for (final line in tanzilText.split('\n')) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final a = line.indexOf('|');
      final b = a < 0 ? -1 : line.indexOf('|', a + 1);
      if (b < 0) continue;
      final s = int.tryParse(line.substring(0, a)), n = int.tryParse(line.substring(a + 1, b));
      if (s == null || n == null) continue;
      ayat[s * 1000 + n] = line.substring(b + 1).replaceAll('\r', '');
    }
    return QuranTextIndex._(ayat);
  }

  final Map<int, String> _ayat;

  /// Number of ayat.
  int get length => _ayat.length;

  /// The exact text of sura [sura], ayah [ayah] (Tanzil's line; ayah 1 of
  /// suras other than 1 and 9 starts with the basmala), or null.
  String? ayah(int sura, int ayah) => _ayat[sura * 1000 + ayah];

  /// Ayat [from]–[to] joined by a space, or null when any is missing.
  String? range(int sura, int from, int to) {
    final parts = <String>[];
    for (var a = from; a <= to; a++) {
      final t = ayah(sura, a);
      if (t == null) return null;
      parts.add(t);
    }
    return parts.join(' ');
  }
}

/// Passage kinds.
enum PassageKind {
  /// Written for Madar.
  original,

  /// Written for Madar, fully vowelled (for the strict tashkeel mode).
  vowelled,

  /// Proverb or public-domain verse.
  saying,

  /// Quran reference.
  quran,
}

/// A passage.
final class TypingPassage {
  /// Creates a passage.
  const TypingPassage({
    required this.id,
    required this.kind,
    required this.level,
    this.text,
    this.attribution,
    this.sura,
    this.fromAyah,
    this.toAyah,
    this.cite,
  });

  /// Stable id.
  final String id;

  /// Kind.
  final PassageKind kind;

  /// 1 short, 2 medium, 3 long.
  final int level;

  /// Text (all kinds but quran).
  final String? text;

  /// Author / "Arabic proverb" (sayings).
  final LocalizedText? attribution;

  /// Quran reference.
  final int? sura, fromAyah, toAyah;

  /// Citation (quran).
  final LocalizedText? cite;

  /// The text to show and type; Quran passages need [quran].
  String? resolve([QuranTextIndex? quran]) =>
      kind == PassageKind.quran ? quran?.range(sura!, fromAyah!, toAyah!) : text;
}

/// The passage bank.
final class TypingPassageBank {
  TypingPassageBank._(this.passages);

  /// Parses the asset file.
  factory TypingPassageBank.parse(String jsonText) {
    final j = jsonDecode(jsonText) as Map<String, Object?>;
    return TypingPassageBank._(List.unmodifiable([
      for (final raw in j['passages']! as List<Object?>)
        () {
          final m = raw! as Map<String, Object?>;
          final ref = m['ref'] as Map<String, Object?>?;
          return TypingPassage(
            id: m['id']! as String,
            kind: PassageKind.values.byName(m['kind']! as String),
            level: m['lvl']! as int,
            text: m['text'] as String?,
            attribution: m['by'] == null ? null : LocalizedText.fromJson(m['by']),
            sura: ref?['s'] as int?,
            fromAyah: ref?['a'] as int?,
            toAyah: ref?['to'] as int?,
            cite: m['cite'] == null ? null : LocalizedText.fromJson(m['cite']),
          );
        }(),
    ]));
  }

  /// All passages.
  final List<TypingPassage> passages;

  /// Passages of [kinds] and [levels] (null = any).
  List<TypingPassage> filter({Set<PassageKind>? kinds, Set<int>? levels}) => [
    for (final p in passages)
      if ((kinds == null || kinds.contains(p.kind)) && (levels == null || levels.contains(p.level))) p,
  ];

  /// A seeded pick avoiding [recent] ids when possible.
  TypingPassage pick(WordsRng rng, {Set<PassageKind>? kinds, Set<int>? levels, Set<String> recent = const {}}) {
    final pool = filter(kinds: kinds, levels: levels);
    if (pool.isEmpty) throw StateError('no passage matches');
    final fresh = [for (final p in pool) if (!recent.contains(p.id)) p];
    return rng.pick(fresh.isEmpty ? pool : fresh);
  }
}
