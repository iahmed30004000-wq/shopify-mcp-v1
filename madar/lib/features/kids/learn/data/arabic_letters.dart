// The 28 Arabic letters for a child: name, the four written forms and one
// non-religious example word each.
//
// Content, not interface text: the alphabet and its example words are data
// (like the Quran text), so they live here rather than in the ARB files.
import 'package:flutter/foundation.dart';

/// Which of the simple original pictures (drawn in code) goes with a word.
enum LetterPicture {
  rabbit,
  house,
  apple,
  snowflake,
  carrot,
  bag,
  tent,
  bicycle,
  corn,
  pomegranate,
  daisy,
  fish,
  sun,
  rocket,
  frog,
  bird,
  envelope,
  grapes,
  cloud,
  butterfly,
  moon,
  ball,
  lemon,
  umbrella,
  star,
  pyramid,
  rose,
  sailboat,
}

/// The four places a letter can sit in a word.
enum LetterForm { isolated, initial, medial, final_ }

@immutable
class ArabicLetter {
  const ArabicLetter({
    required this.id,
    required this.glyph,
    required this.name,
    required this.word,
    required this.picture,
    this.joinsNext = true,
    this.at = 0,
  });

  /// Stable ASCII id, also the voice file name stem (`letter_<id>`).
  final String id;

  /// The letter on its own.
  final String glyph;

  /// "عين" (the name, without the word "حرف").
  final String name;

  /// The example word, with the vowel marks a child's book would show.
  final String word;

  final LetterPicture picture;

  /// False for the six letters that never join the letter after them
  /// (ا د ذ ر ز و): they have no real initial or medial shape.
  final bool joinsNext;

  /// Index in [word] where the highlighted letter starts.
  final int at;

  /// The text of the letter in [form], shaped by the text engine: a zero-width
  /// joiner on the side(s) that connect makes it pick the right glyph, so
  /// nothing is hand-drawn.
  String form(LetterForm f) => switch (f) {
    LetterForm.isolated => glyph,
    LetterForm.initial => '$glyph$zwj',
    LetterForm.medial => '$zwj$glyph$zwj',
    LetterForm.final_ => '$zwj$glyph',
  };

  /// Whether [f] is a form the letter really has (a non-joining letter looks
  /// like its isolated/final shape in initial/medial position).
  bool hasForm(LetterForm f) => joinsNext || f == LetterForm.isolated || f == LetterForm.final_;

  /// Where the highlight in [word] starts and ends: the letter plus the vowel
  /// marks sitting on it.
  (int, int) get highlight {
    var end = at + 1;
    while (end < word.length && _isMark(word.codeUnitAt(end))) {
      end++;
    }
    return (at, end);
  }

  static const String zwj = '‍';

  static bool _isMark(int u) => (u >= 0x064B && u <= 0x0652) || u == 0x0670;
}

const List<ArabicLetter> arabicLetters = [
  ArabicLetter(id: 'alif', glyph: 'ا', name: 'ألف', word: 'أَرْنَب', picture: LetterPicture.rabbit, joinsNext: false),
  ArabicLetter(id: 'ba', glyph: 'ب', name: 'باء', word: 'بَيْت', picture: LetterPicture.house),
  ArabicLetter(id: 'ta', glyph: 'ت', name: 'تاء', word: 'تُفَّاح', picture: LetterPicture.apple),
  ArabicLetter(id: 'tha', glyph: 'ث', name: 'ثاء', word: 'ثَلْج', picture: LetterPicture.snowflake),
  ArabicLetter(id: 'jim', glyph: 'ج', name: 'جيم', word: 'جَزَر', picture: LetterPicture.carrot),
  ArabicLetter(id: 'ha', glyph: 'ح', name: 'حاء', word: 'حَقِيبَة', picture: LetterPicture.bag),
  ArabicLetter(id: 'kha', glyph: 'خ', name: 'خاء', word: 'خَيْمَة', picture: LetterPicture.tent),
  ArabicLetter(id: 'dal', glyph: 'د', name: 'دال', word: 'دَرَّاجَة', picture: LetterPicture.bicycle, joinsNext: false),
  ArabicLetter(id: 'dhal', glyph: 'ذ', name: 'ذال', word: 'ذُرَة', picture: LetterPicture.corn, joinsNext: false),
  ArabicLetter(id: 'ra', glyph: 'ر', name: 'راء', word: 'رُمَّان', picture: LetterPicture.pomegranate, joinsNext: false),
  ArabicLetter(id: 'zay', glyph: 'ز', name: 'زاي', word: 'زَهْرَة', picture: LetterPicture.daisy, joinsNext: false),
  ArabicLetter(id: 'sin', glyph: 'س', name: 'سين', word: 'سَمَكَة', picture: LetterPicture.fish),
  ArabicLetter(id: 'shin', glyph: 'ش', name: 'شين', word: 'شَمْس', picture: LetterPicture.sun),
  ArabicLetter(id: 'sad', glyph: 'ص', name: 'صاد', word: 'صَارُوخ', picture: LetterPicture.rocket),
  ArabicLetter(id: 'dad', glyph: 'ض', name: 'ضاد', word: 'ضِفْدَع', picture: LetterPicture.frog),
  ArabicLetter(id: 'ta2', glyph: 'ط', name: 'طاء', word: 'طَائِر', picture: LetterPicture.bird),
  ArabicLetter(id: 'dha', glyph: 'ظ', name: 'ظاء', word: 'ظَرْف', picture: LetterPicture.envelope),
  ArabicLetter(id: 'ain', glyph: 'ع', name: 'عين', word: 'عِنَب', picture: LetterPicture.grapes),
  ArabicLetter(id: 'ghain', glyph: 'غ', name: 'غين', word: 'غَيْمَة', picture: LetterPicture.cloud),
  ArabicLetter(id: 'fa', glyph: 'ف', name: 'فاء', word: 'فَرَاشَة', picture: LetterPicture.butterfly),
  ArabicLetter(id: 'qaf', glyph: 'ق', name: 'قاف', word: 'قَمَر', picture: LetterPicture.moon),
  ArabicLetter(id: 'kaf', glyph: 'ك', name: 'كاف', word: 'كُرَة', picture: LetterPicture.ball),
  ArabicLetter(id: 'lam', glyph: 'ل', name: 'لام', word: 'لَيْمُون', picture: LetterPicture.lemon),
  ArabicLetter(id: 'mim', glyph: 'م', name: 'ميم', word: 'مِظَلَّة', picture: LetterPicture.umbrella),
  ArabicLetter(id: 'nun', glyph: 'ن', name: 'نون', word: 'نَجْمَة', picture: LetterPicture.star),
  ArabicLetter(id: 'ha2', glyph: 'ه', name: 'هاء', word: 'هَرَم', picture: LetterPicture.pyramid),
  ArabicLetter(id: 'waw', glyph: 'و', name: 'واو', word: 'وَرْدَة', picture: LetterPicture.rose, joinsNext: false),
  ArabicLetter(id: 'ya', glyph: 'ي', name: 'ياء', word: 'يَخْت', picture: LetterPicture.sailboat),
];
