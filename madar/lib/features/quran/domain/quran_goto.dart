import 'package:meta/meta.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/quran/ayah.dart';
import 'arabic_search.dart';
import 'quran_meta.dart';

enum GoToKind { surah, ayah, page, juz, hizb }

/// Where "go to" can take the reader.
@immutable
class GoToTarget {
  const GoToTarget(this.kind, this.ref, {required this.number, this.page});

  final GoToKind kind;

  /// The ayah the reader opens at.
  final AyahRef ref;

  /// Sura / page / juz / hizb number (for [GoToKind.ayah], the sura).
  final int number;

  /// Set for [GoToKind.page]: the reader opens that mushaf page.
  final int? page;

  @override
  bool operator ==(Object other) =>
      other is GoToTarget && other.kind == kind && other.ref == ref && other.number == number && other.page == page;

  @override
  int get hashCode => Object.hash(kind, ref, number, page);

  @override
  String toString() => '${kind.name} $number → $ref${page == null ? '' : ' p$page'}';
}

/// Parses what a reader types to jump somewhere: `2:255`, `٢:٢٥٥`, `2 255`,
/// `البقرة ٢٥٥`, `Baqarah 255`, `ص ٥٠` / `صفحة 50` / `page 50`, `جزء ٣` /
/// `juz 3`, `حزب ٥` / `hizb 5`, a sura name, or a bare number (a sura, a
/// page and a juz as far as each exists).
abstract final class QuranGoTo {
  static final RegExp _pair = RegExp(r'^(\d{1,3})\s*[:：.\-/،,\s]\s*(\d{1,3})$');
  static final RegExp _single = RegExp(r'^(\d{1,3})$');
  static final RegExp _keyword = RegExp(
    r'^(page|pg|p|صفحة|صفحه|الصفحة|ص|juz|juzu|jz|جزء|الجزء|ج|hizb|حزب|الحزب|ح)\.?\s*(\d{1,3})$',
    caseSensitive: false,
  );
  static final RegExp _trailingNumber = RegExp(r'^(.*?)[\s:]*(\d{1,3})$');

  static List<GoToTarget> parse(String input, QuranMeta meta) {
    final q = Digits.toWestern(input).trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.isEmpty) return const [];
    final out = <GoToTarget>[];
    var m = _pair.firstMatch(q);
    if (m != null) {
      final s = int.parse(m.group(1)!);
      final a = int.parse(m.group(2)!);
      if (s >= 1 && s <= meta.surahs.length && a >= 1 && a <= meta.surah(s).ayahCount) {
        out.add(GoToTarget(GoToKind.ayah, AyahRef(s, a), number: s));
      }
      return out;
    }
    m = _keyword.firstMatch(q);
    if (m != null) {
      final k = m.group(1)!.toLowerCase();
      final n = int.parse(m.group(2)!);
      final target = switch (k) {
        'page' || 'pg' || 'p' || 'صفحة' || 'صفحه' || 'الصفحة' || 'ص' => _page(meta, n),
        'juz' || 'juzu' || 'jz' || 'جزء' || 'الجزء' || 'ج' => _juz(meta, n),
        _ => _hizb(meta, n),
      };
      if (target != null) out.add(target);
      return out;
    }
    m = _single.firstMatch(q);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      if (n >= 1 && n <= meta.surahs.length) out.add(GoToTarget(GoToKind.surah, AyahRef(n, 1), number: n));
      final page = _page(meta, n);
      if (page != null) out.add(page);
      final juz = _juz(meta, n);
      if (juz != null) out.add(juz);
      return out;
    }
    // A sura name, optionally followed by an ayah number.
    String name = q;
    int? ayah;
    m = _trailingNumber.firstMatch(q);
    if (m != null && m.group(1)!.trim().isNotEmpty) {
      name = m.group(1)!.trim();
      ayah = int.parse(m.group(2)!);
    }
    for (final s in matchSurahs(name, meta)) {
      if (ayah == null) {
        out.add(GoToTarget(GoToKind.surah, s.first, number: s.number));
      } else if (ayah >= 1 && ayah <= s.ayahCount) {
        out.add(GoToTarget(GoToKind.ayah, AyahRef(s.number, ayah), number: s.number));
      }
    }
    return out;
  }

  static GoToTarget? _page(QuranMeta meta, int n) => n >= 1 && n <= QuranMeta.pageCount
      ? GoToTarget(GoToKind.page, meta.pageStart(n), number: n, page: n)
      : null;

  static GoToTarget? _juz(QuranMeta meta, int n) =>
      n >= 1 && n <= QuranMeta.juzCount ? GoToTarget(GoToKind.juz, meta.juzStart(n), number: n) : null;

  static GoToTarget? _hizb(QuranMeta meta, int n) =>
      n >= 1 && n <= QuranMeta.hizbCount ? GoToTarget(GoToKind.hizb, meta.hizbStart(n), number: n) : null;

  /// Suras whose Arabic or English name matches [query] (folded: diacritics,
  /// hamza and alef forms, «سورة», "Al-", apostrophes and case ignored),
  /// best first: exact names, then prefixes, then substrings.
  static List<SurahInfo> matchSurahs(String query, QuranMeta meta) {
    final arabic = _foldArabicName(query);
    final latin = _foldLatin(query);
    if (arabic.isEmpty && latin.isEmpty) return const [];
    final scored = <(int, SurahInfo)>[];
    for (final s in meta.surahs) {
      var score = 0;
      if (arabic.isNotEmpty) {
        final name = _foldArabicName(s.nameArabic);
        score = name == arabic ? 3 : name.startsWith(arabic) ? 2 : name.contains(arabic) ? 1 : 0;
      }
      if (score == 0 && latin.isNotEmpty) {
        final name = _foldLatin(s.nameEnglish);
        final meaning = _foldLatin(s.meaningEnglish);
        score = name == latin
            ? 3
            : name.startsWith(latin)
            ? 2
            : (name.contains(latin) || (latin.length >= 3 && meaning.contains(latin)))
            ? 1
            : 0;
      }
      if (score > 0) scored.add((score, s));
    }
    scored.sort((a, b) => b.$1 != a.$1 ? b.$1.compareTo(a.$1) : a.$2.number.compareTo(b.$2.number));
    return [for (final e in scored) e.$2];
  }

  static String _foldArabicName(String s) {
    var t = ArabicSearch.normalize(s).text.replaceAll(' ', '');
    // «سورة» (folded: سوره) in front of a name.
    if (t.startsWith('سوره') && t.length > 4) t = t.substring(4);
    // The article: الـ folds to ل (alef dropped); drop it on both sides.
    if (t.startsWith('ل') && t.length > 2) t = t.substring(1);
    return t;
  }

  static final RegExp _surahWord = RegExp(r'^(surah|surat|sura|soorah)\s+');
  static final RegExp _article = RegExp(r"^(al|an|ar|as|at|ad|adh|ash|az|ath)[-\s]+");

  static String _foldLatin(String s) {
    var lower = s.toLowerCase().trim().replaceFirst(_surahWord, '');
    lower = lower.replaceFirst(_article, '');
    var t = lower.replaceAll(RegExp(r'[^a-z]'), '');
    // Long vowels spelled twice (Faatiha) or with h (Fatihah) read the same.
    t = t.replaceAllMapped(RegExp(r'([aeiou])\1+'), (m) => m.group(1)!);
    if (t.endsWith('h') && t.length > 3) t = t.substring(0, t.length - 1);
    return t;
  }
}
