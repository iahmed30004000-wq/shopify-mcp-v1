/// Arabic text normalisation shared by the Madar Cinema word games.
///
/// Mirrors assets/games/source/arabic_norm.py (the content build) – the two
/// must stay in step. Levels of normalisation, from lightest to loosest:
///
/// * [ArabicText.plain] – tashkeel (harakat, tanwin, shadda, sukun, madda /
///   hamza marks), the superscript alef, Quranic annotation signs and tatweel
///   removed; alef wasla (ٱ) → ا; Persian look-alikes (ی ک) → ي ك. Hamza
///   forms, ة and ى are kept. This is how game words are stored and shown.
/// * [ArabicText.fold] – game-letter identity used for feedback and
///   matching: ا أ إ آ → ا, ى → ي, ة → ه. ء ؤ ئ stay distinct.
/// * [ArabicText.lookupKey] – dictionary identity: fold + ؤ ئ → ء, so both
///   spellings of e.g. مسؤول / مسئول are accepted as guesses.
/// * [ArabicText.skeleton] – loose letter skeleton for citation checks
///   against the Uthmani Quran text and hadith editions.
library;

/// Static helpers for Arabic strings (all Arabic letters are single UTF-16
/// code units, so strings are processed per code unit).
abstract final class ArabicText {
  /// The 36 letters a game word may contain after [plain].
  static const String letters = 'ءآأؤإئابةتثجحخدذرزسشصضطظعغفقكلمنهوىي';

  static final Set<int> _letterSet = letters.codeUnits.toSet();

  /// Tatweel (kashida), U+0640.
  static const int tatweel = 0x0640;

  /// Alef wasla, U+0671.
  static const int alefWasla = 0x0671;

  /// True for tashkeel, madda / hamza combining marks, the superscript alef
  /// and the Quranic annotation signs (pause, sajdah, rub-el-hizb, small
  /// letters).
  static bool isMark(int cu) =>
      (cu >= 0x064B && cu <= 0x065F) || cu == 0x0670 || (cu >= 0x06D6 && cu <= 0x06ED);

  /// True for the eight "vowelling" marks a typist can type (fathatan …
  /// sukun, U+064B–U+0652).
  static bool isHaraka(int cu) => cu >= 0x064B && cu <= 0x0652;

  /// True for a game letter (see [letters]).
  static bool isLetter(int cu) => _letterSet.contains(cu);

  /// True when [s] is non-empty and made only of game [letters].
  static bool isGameWord(String s) => s.isNotEmpty && s.codeUnits.every(isLetter);

  static const Map<String, String> _compose = {
    'آ': 'آ',
    'أ': 'أ',
    'إ': 'إ',
    'ؤ': 'ؤ',
    'ئ': 'ئ',
    'ىٔ': 'ئ',
  };

  /// Composes the decomposed hamza / madda pairs (NFC for these pairs).
  static String compose(String s) {
    var out = s;
    for (final e in _compose.entries) {
      if (out.contains(e.key)) out = out.replaceAll(e.key, e.value);
    }
    return out;
  }

  /// Removes marks and tatweel but changes no letter.
  static String stripMarks(String s) {
    final b = StringBuffer();
    for (final cu in compose(s).codeUnits) {
      if (isMark(cu) || cu == tatweel) continue;
      b.writeCharCode(cu);
    }
    return b.toString();
  }

  /// Stored / displayed game form (see the library comment).
  static String plain(String s) {
    final b = StringBuffer();
    for (final cu in compose(s).codeUnits) {
      if (isMark(cu) || cu == tatweel || cu == 0x200C || cu == 0x200D) continue;
      switch (cu) {
        case alefWasla:
          b.write('ا');
        case 0x06CC: // Persian yeh
          b.write('ي');
        case 0x06A9: // keheh
          b.write('ك');
        default:
          b.writeCharCode(cu);
      }
    }
    return b.toString();
  }

  /// Folds one plain letter to its game-letter class.
  static String foldLetter(String letter) => switch (letter) {
    'أ' || 'إ' || 'آ' || 'ٱ' => 'ا',
    'ى' => 'ي',
    'ة' => 'ه',
    _ => letter,
  };

  /// Game-letter identity: [plain] + alef family → ا, ى → ي, ة → ه.
  static String fold(String s) {
    final p = plain(s);
    final b = StringBuffer();
    for (var i = 0; i < p.length; i++) {
      b.write(foldLetter(p[i]));
    }
    return b.toString();
  }

  /// Dictionary identity: [fold] + ؤ ئ → ء.
  static String lookupKey(String s) => fold(s).replaceAll('ؤ', 'ء').replaceAll('ئ', 'ء');

  /// Loose letter skeleton: [fold], ؤ → و, ئ → ي, ء dropped; everything that
  /// is not a game letter (spaces, punctuation, digits) removed.
  static String skeleton(String s) {
    final f = fold(s).replaceAll('ؤ', 'و').replaceAll('ئ', 'ي').replaceAll('ء', '');
    final b = StringBuffer();
    for (final cu in f.codeUnits) {
      if (isLetter(cu)) b.writeCharCode(cu);
    }
    return b.toString();
  }

  /// The plain letters of [word] (one string per letter).
  static List<String> lettersOf(String word) {
    final p = plain(word);
    return [for (var i = 0; i < p.length; i++) p[i]];
  }

  /// Number of game letters in [word] (tashkeel and tatweel not counted).
  static int letterCount(String word) => plain(word).codeUnits.where(isLetter).length;

  /// Splits [s] into grapheme clusters: a base character followed by its
  /// marks (tatweel counts as a mark carrier and joins the cluster before
  /// it). Used by the typing race.
  static List<String> clusters(String s) {
    final text = compose(s);
    final out = <String>[];
    final cur = StringBuffer();
    for (final cu in text.codeUnits) {
      final joins = isMark(cu) || cu == tatweel;
      if (!joins && cur.isNotEmpty) {
        out.add(cur.toString());
        cur.clear();
      }
      cur.writeCharCode(cu);
    }
    if (cur.isNotEmpty) out.add(cur.toString());
    return out;
  }

  /// Converts Western digits to Arabic-Indic digits.
  static String arabicDigits(Object value) {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().replaceAllMapped(RegExp('[0-9]'), (m) => digits[int.parse(m[0]!)]);
  }
}
