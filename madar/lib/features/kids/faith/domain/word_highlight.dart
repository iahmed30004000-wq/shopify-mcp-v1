// Which word is lit while a surah is heard.
//
// The Quran feature exposes NO per-word timing (its player reports only the
// ayah being recited, and no duration). So the highlight divides the ayah's
// duration evenly between its words. When the real duration is unknown (the
// player does not say), [estimatedAyahDuration] is a stand-in of
// [kidsSecondsPerWord] per word, and the lit word simply rests on the last
// word until the player moves to the next ayah. Real timing, if the Quran
// feature ever gets it, replaces [litWordIndex]'s inputs, not its callers.

/// Rough pace of a measured recitation, used only when no duration is known.
const double kidsSecondsPerWord = 0.75;

Duration estimatedAyahDuration(int wordCount) =>
    Duration(milliseconds: (wordCount * kidsSecondsPerWord * 1000).round());

/// The index of the lit word after [elapsed] of an ayah of [wordCount] words
/// lasting [duration]; null when nothing should be lit (no words, not started).
int? litWordIndex({required int wordCount, required Duration elapsed, required Duration duration}) {
  if (wordCount <= 0 || elapsed.isNegative) return null;
  if (duration <= Duration.zero) return wordCount - 1;
  final i = elapsed.inMicroseconds * wordCount ~/ duration.inMicroseconds;
  return i >= wordCount ? wordCount - 1 : i;
}

final RegExp _hasLetter = RegExp('[\u0621-\u064A\u0671-\u06D3]');

/// The words of an ayah as laid out on the page. A token with no letter in it
/// (a lone pause sign) belongs to the word before it, so it never becomes a
/// "word" of its own that lights up for a moment of silence.
List<String> ayahWords(String ayahText) {
  final words = <String>[];
  for (final t in ayahText.split(' ')) {
    if (t.trim().isEmpty) continue;
    if (words.isNotEmpty && !_hasLetter.hasMatch(t)) {
      words[words.length - 1] = '${words.last} $t';
    } else {
      words.add(t);
    }
  }
  return words;
}
