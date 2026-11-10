/// THE RELIGIOUS GUARD (Part 15, absolute rule of the owner).
///
/// The model **never gives a religious ruling** and **never quotes a verse or
/// a hadith from its own memory**. Religious text reaches the screen only
/// from the app's verified data (the Quran reader, the adhkar, the hadith
/// with its source and grading). So every model output passes through
/// [ReligiousOutputGuard.check] before anything is shown, and a hit **refuses
/// the whole answer**: the caller shows one fixed message pointing to the
/// verified sources inside the app. No partial text is ever returned.
///
/// What it detects (Arabic and English):
///  * **Quran** – a run of [QuranVerseIndex.minWords] or more consecutive
///    words that match the bundled Uthmani text after normalisation (the same
///    folding the Quran search uses, so Uthmani and everyday spelling match),
///    the ornate brackets ﴿ ﴾, and the introducers «قال الله تعالى» /
///    «قال تعالى» / «يقول الله تعالى» / "Allah says".
///  * **Hadith** – attribution formulas («قال رسول الله», «عن النبي»,
///    «رواه», a narrator «عن … رضي الله عنه», the six books and «متفق عليه»,
///    «حدثنا»), and in English "the Prophet said", "narrated by", "Sahih
///    Bukhari", "in a hadith" …
///  * **Ruling language** – «حلال», «حرام», «يجوز», «لا يجوز», «يحرم»,
///    «مكروه», «فتوى», «حكم شرعي», "permissible", "haram", "fatwa", "it is
///    forbidden" …
///
/// **Documented false positives (the price of a strict guard)** – a refused
/// answer costs the owner one tap to ask again or to use the bridge; a miss
/// would put an invented ruling on his screen:
///  * words are matched **as whole words** (after the one-letter prefixes و ف
///    ب ل ك and «ال»), so «حرامي» (a thief) and «حلالنا» are NOT flagged;
///  * the idioms «يا حرام» (what a pity), «ابن الحلال» / «ولاد الحلال» and the
///    place names «المسجد الحرام», «البيت الحرام», «الشهر الحرام» are NOT
///    flagged;
///  * **still flagged on purpose**: «حلال»/«حرام» in any other use («اللحم
///    حلال»), a bare «يجوز» meaning "maybe", «رواه» meaning "watered him";
///  * the Quran match needs a run of ≥ 4 words AND ≥ 10 letters once alef and
///    hamza are folded away, so four short function words are not a verse. It
///    reads the Arabic Uthmani text only: a verse paraphrased, or quoted in
///    an English translation, is caught only by the introducers above.
///
/// **Fails closed**: the guard cannot be built without the Quran text, so a
/// phone where that text did not load never lets a model answer through
/// (`modelRouterProvider` stays in error and the callers use the bridge).
///
/// Pure Dart.
library;

import 'package:meta/meta.dart';

import '../../ai_bridge/domain/health_guard.dart';
import '../../quran/domain/arabic_search.dart';
import '../../quran/domain/quran_meta.dart';
import '../../quran/domain/quran_text.dart';

/// Why an answer was refused.
enum GuardKind {
  /// Quranic text, or the introducer of a verse.
  quran,

  /// A hadith, or the attribution of one.
  hadith,

  /// A religious ruling.
  ruling,

  /// A dose or a diagnosis (`HealthGuard`).
  health,
}

@immutable
class GuardFlag {
  const GuardFlag(this.kind, this.match);

  final GuardKind kind;

  /// What matched, for logs and tests. Never shown to the owner.
  final String match;

  @override
  String toString() => 'GuardFlag(${kind.name}, $match)';
}

@immutable
class GuardVerdict {
  const GuardVerdict(this.flags);

  const GuardVerdict.clean() : flags = const [];

  /// Everything that matched, strongest first (Quran, hadith, ruling).
  final List<GuardFlag> flags;

  bool get allowed => flags.isEmpty;

  /// The reason shown (the strongest), null when [allowed].
  GuardKind? get kind => flags.isEmpty ? null : flags.first.kind;
}

/// The bundled Quran, folded, for run matching. One string with the suras
/// separated by `|` (a run never crosses from one sura to the next).
class QuranVerseIndex {
  QuranVerseIndex._(this._folded, this._grams, this.minWords, this.minLetters);

  /// From the suras' ayat, in order (each inner list is one sura).
  factory QuranVerseIndex.fromSurahs(
    Iterable<Iterable<String>> surahs, {
    int minWords = defaultMinWords,
    int minLetters = defaultMinLetters,
  }) {
    final out = StringBuffer();
    var first = true;
    for (final ayat in surahs) {
      if (!first) out.write('|');
      first = false;
      for (final a in ayat) {
        out.write(ArabicSearch.normalize(a).text);
      }
    }
    final folded = out.toString();
    final grams = <String>{};
    for (var i = 0; i + _gram <= folded.length; i++) {
      grams.add(folded.substring(i, i + _gram));
    }
    return QuranVerseIndex._(folded, grams, minWords, minLetters);
  }

  /// From the app's bundled Uthmani text.
  factory QuranVerseIndex.fromQuran(QuranText text, QuranMeta meta, {int minWords = defaultMinWords}) =>
      QuranVerseIndex.fromSurahs([
        for (final s in meta.surahs) [for (var i = s.firstIndex; i < s.firstIndex + s.ayahCount; i++) text.line(i)],
      ], minWords: minWords);

  /// A run of this many consecutive words is a verse (the owner's rule: N≥4).
  static const int defaultMinWords = 4;

  /// …and must be at least this many letters long once folded (alef and
  /// hamza fold away, so very short words would otherwise make «من في ما لا»
  /// a «verse»).
  static const int defaultMinLetters = 10;

  static const int _gram = 5;

  final String _folded;
  final Set<String> _grams;
  final int minWords;
  final int minLetters;

  /// The words of [text] as folded Arabic (empty ones dropped).
  static List<String> wordsOf(String text) {
    final n = ArabicSearch.normalize(text);
    final words = <String>[];
    final buf = StringBuffer();
    var current = -1;
    for (var i = 0; i < n.text.length; i++) {
      final w = n.words[i];
      if (w != current) {
        if (buf.isNotEmpty) words.add(buf.toString());
        buf.clear();
        current = w;
      }
      buf.writeCharCode(n.text.codeUnitAt(i));
    }
    if (buf.isNotEmpty) words.add(buf.toString());
    return words;
  }

  /// The first run of [minWords] consecutive words of [text] found in the
  /// Quran, or null. The window is compared without the spaces between its
  /// words, because the Uthmani script joins some words the everyday spelling
  /// writes apart («يَـٰٓأَيُّهَا» / «يا أيها»).
  String? findRun(String text) {
    final words = wordsOf(text);
    for (var i = 0; i + minWords <= words.length; i++) {
      final window = words.sublist(i, i + minWords).join();
      if (window.length < minLetters) continue;
      // Cheap pre-filter: the first five letters must exist somewhere.
      if (window.length >= _gram && !_grams.contains(window.substring(0, _gram))) continue;
      if (_folded.contains(window)) return words.sublist(i, i + minWords).join(' ');
    }
    return null;
  }
}

class ReligiousOutputGuard {
  ReligiousOutputGuard(this.quran);

  final QuranVerseIndex quran;

  /// Checks one complete model answer.
  GuardVerdict check(String text) {
    if (text.trim().isEmpty) return const GuardVerdict.clean();
    final flags = <GuardFlag>[];

    final run = quran.findRun(text);
    if (run != null) flags.add(GuardFlag(GuardKind.quran, run));
    if (_ornateBrackets.hasMatch(text)) flags.add(const GuardFlag(GuardKind.quran, '﴿ ﴾'));

    final prepared = _prepare(text);
    final lower = text.toLowerCase();

    for (final p in _quranIntroducers) {
      if (p.hasMatch(prepared)) flags.add(GuardFlag(GuardKind.quran, p.pattern));
    }
    for (final p in _quranIntroducersEn) {
      if (p.hasMatch(lower)) flags.add(GuardFlag(GuardKind.quran, p.pattern));
    }
    for (final p in _hadithPatterns) {
      if (p.hasMatch(prepared)) {
        flags.add(GuardFlag(GuardKind.hadith, p.pattern));
        break;
      }
    }
    for (final p in _hadithPatternsEn) {
      if (p.hasMatch(lower)) {
        flags.add(GuardFlag(GuardKind.hadith, p.pattern));
        break;
      }
    }
    final ruling = _rulingWord(prepared);
    if (ruling != null) flags.add(GuardFlag(GuardKind.ruling, ruling));
    for (final p in _rulingPatternsEn) {
      if (p.hasMatch(lower)) {
        flags.add(GuardFlag(GuardKind.ruling, p.pattern));
        break;
      }
    }
    // Strongest first: a verse outranks a hadith outranks a ruling.
    flags.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    return GuardVerdict(flags);
  }

  // ---------------------------------------------------------------- text --

  static final RegExp _ornateBrackets = RegExp('[\u{FD3E}\u{FD3F}]');
  static final RegExp _notWord = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  /// Folded Arabic with the punctuation turned into spaces; «ﷺ» expanded
  /// first (it carries the salawat).
  static String _prepare(String raw) {
    final expanded = raw.replaceAll('\u{FDFA}', ' صلى الله عليه وسلم ');
    return HealthGuard.fold(expanded.replaceAll(_notWord, ' '));
  }

  static String _f(String s) => HealthGuard.fold(s);

  static RegExp _phrase(String arabic) =>
      RegExp('(?:^|\\s)(?:و|ف)?${RegExp.escape(_f(arabic))}(?=\\s|\$)', unicode: true);

  // The introducer of a verse. The verse itself is caught by the run match;
  // an introducer with the verse cut off is refused too (never partial).
  static final List<RegExp> _quranIntroducers = [
    for (final p in [
      'قال الله تعالى',
      'قال تعالى',
      'يقول الله تعالى',
      'يقول تعالى',
      'قال الله عز وجل',
      'قال الله سبحانه',
      'في كتابه العزيز',
      'قال الله في كتابه',
    ])
      _phrase(p),
  ];

  static final List<RegExp> _quranIntroducersEn = [
    RegExp(r"\b(allah|god) (says|said|states|declares) in the (holy )?(qur'?an|koran|quran)"),
    RegExp(r"\bthe (holy )?(qur'?an|koran|quran) (says|states|declares)"),
    RegExp(r"\b(allah|god) (the exalted )?says\b"),
    RegExp(r"\bverse \d+ of (surah|sura|chapter)\b"),
  ];

  static final List<RegExp> _hadithPatterns = [
    for (final p in [
      'قال رسول الله',
      'قال النبي',
      'قال الرسول',
      'يقول رسول الله',
      'يقول النبي',
      'قال صلى الله عليه وسلم',
      'قال عليه الصلاة والسلام',
      'عن رسول الله',
      'عن النبي',
      'عن الرسول',
      'رواه',
      'اخرجه',
      'روي عن النبي',
      'متفق عليه',
      'صحيح البخاري',
      'صحيح مسلم',
      'سنن ابي داود',
      'سنن الترمذي',
      'سنن النسائي',
      'سنن ابن ماجه',
      'مسند احمد',
      'موطا مالك',
      'حديث صحيح',
      'حديث حسن',
      'حديث ضعيف',
      'حديث شريف',
      'الحديث الشريف',
      'في الحديث',
      'حدثنا',
      'حدثني',
    ])
      _phrase(p),
    // «عن أبي هريرة رضي الله عنه», «عن عائشة رضي الله عنها».
    RegExp('(?:^|\\s)عن\\s+(?:\\S+\\s+){0,3}?${_f('رضي الله عن')}(?:ه|ها|هما|هم)(?=\\s|\$)', unicode: true),
    // «قالت عائشة رضي الله عنها».
    RegExp('(?:^|\\s)قال(?:ت)?\\s+(?:\\S+\\s+){0,3}?${_f('رضي الله عن')}(?:ه|ها|هما|هم)(?=\\s|\$)', unicode: true),
    // «صلى الله عليه وسلم قال».
    RegExp('${_f('صلى الله عليه وسلم')}\\s+(?:\\S+\\s+){0,2}?(?:قال|يقول)(?=\\s|\$)', unicode: true),
  ];

  static final List<RegExp> _hadithPatternsEn = [
    RegExp(
      r"\b(the )?(prophet|messenger of allah|apostle of allah|rasulullah)( muhammad)?"
      r"( \(?(pbuh|saw|s\.a\.w|peace be upon him|may peace be upon him|sallallahu alayhi wa sallam)\)?)?"
      r" (said|says|stated|told|declared|narrated)\b",
    ),
    RegExp(r"\bnarrated (by|from|that)\b"),
    RegExp(r"\bnarrated (abu|aisha|a'isha|ibn|anas|umar|ali|jabir|uthman)\b"),
    RegExp(r"\bsahih (al[- ])?(bukhari|muslim)\b"),
    RegExp(r"\b(reported|related|recorded|collected) by (al[- ])?(bukhari|muslim|tirmidhi|abu dawud|nasa'?i|ibn majah|ahmad|malik)\b"),
    RegExp(r"\b(bukhari|muslim|tirmidhi|abu dawud|nasa'?i|ibn majah) (reported|narrated|recorded|collected)\b"),
    RegExp(r"\b(according to|in) (a|the) hadith\b"),
    RegExp(r"\bhadith (states|says|narrates|reports|qudsi)\b"),
  ];

  // ------------------------------------------------------------- rulings --

  /// Whole-word rulings, after stripping the one-letter prefixes and «ال».
  static final Set<String> _rulingWords = {
    for (final w in [
      'حلال',
      'حرام',
      'يجوز',
      'تجوز',
      'جائز',
      'يحرم',
      'تحرم',
      'مباح',
      'مكروه',
      'فتوى',
      'فتاوى',
      'أفتى',
      'يفتي',
      'شرعا',
    ])
      _f(w),
  };

  static final List<RegExp> _rulingPhrases = [
    for (final p in ['حكم شرعي', 'الحكم الشرعي', 'حكمه الشرعي', 'من الناحية الشرعية', 'في الشرع', 'واجب شرعا'])
      _phrase(p),
  ];

  static final RegExp _prefix = RegExp(r'^(?:[وف])?(?:[بلك])?(?:ال)?');

  /// Preceding words that make «حرام»/«حلال» an idiom or a place name.
  static final Set<String> _beforeIdiom = {
    for (final w in ['يا', 'ابن', 'ولاد', 'اولاد', 'بنت', 'المسجد', 'البيت', 'الشهر', 'الاشهر', 'مسجد', 'بيت'])
      _f(w),
  };

  static String? _rulingWord(String prepared) {
    final tokens = prepared.split(RegExp(r'\s+'));
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.isEmpty) continue;
      final bare = t.replaceFirst(_prefix, '');
      // `_prefix` can eat letters of a real word («بلال»…): try the bare
      // token and the stripped one.
      final hit = _rulingWords.contains(t)
          ? t
          : (bare.isNotEmpty && _rulingWords.contains(bare) ? bare : null);
      if (hit == null) continue;
      if (hit == _f('حرام') || hit == _f('حلال')) {
        final before = i > 0 ? tokens[i - 1] : '';
        if (_beforeIdiom.contains(before)) continue;
      }
      return hit;
    }
    for (final p in _rulingPhrases) {
      if (p.hasMatch(prepared)) return p.pattern;
    }
    return null;
  }

  static final List<RegExp> _rulingPatternsEn = [
    RegExp(r"\b(haram|halal|makruh|mubah|fatwa|fatawa|impermissible|permissible)\b"),
    RegExp(r"\bit(?:'s| is)\s+(?:not\s+)?(?:forbidden|prohibited|lawful|unlawful)\b"),
    RegExp(r"\b(?:is|are)\s+(?:not\s+)?(?:forbidden|prohibited|lawful|unlawful|allowed|permitted)\s+(?:in|by|under)\s+(?:islam|sharia|shariah|islamic law|the religion)\b"),
    RegExp(r"\b(islamic|sharia|shariah|religious) (ruling|verdict|law says|law states)\b"),
    RegExp(r"\bforbidden in islam\b"),
  ];
}
