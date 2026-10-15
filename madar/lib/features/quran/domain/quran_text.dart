import '../../../core/quran/ayah.dart';
import 'quran_meta.dart';

/// The bundled Tanzil Uthmani text (assets/quran/quran-uthmani.txt), kept
/// exactly as distributed: one `sura|aya|text` line per ayah, the basmala
/// leading ayah 1 of every sura but 1 and 9. The reader shows that basmala
/// as the sura's header ([basmalaOf]) and the rest as the ayah ([ayahText]).
class QuranText {
  QuranText._(this._lines, this._basmalaLength, this.copyrightNotice);

  /// Parses the file. Throws [FormatException] when it is not the full,
  /// ordered 6236-ayah text.
  factory QuranText.parse(String source, QuranMeta meta) {
    final lines = List<String>.filled(meta.ayahCount, '');
    final basmala = List<int>.filled(meta.ayahCount, 0);
    final notice = StringBuffer();
    var index = 0;
    for (final raw in source.split('\n')) {
      final line = raw.endsWith('\r') ? raw.substring(0, raw.length - 1) : raw;
      if (line.isEmpty) continue;
      if (line.startsWith('#')) {
        notice.writeln(line);
        continue;
      }
      final a = line.indexOf('|');
      final b = a < 0 ? -1 : line.indexOf('|', a + 1);
      if (b < 0) throw FormatException('Bad Quran text line', line);
      final surah = int.parse(line.substring(0, a));
      final ayah = int.parse(line.substring(a + 1, b));
      if (index >= lines.length || meta.refAt(index) != AyahRef(surah, ayah)) {
        throw FormatException('Quran text out of order at $surah:$ayah');
      }
      final text = line.substring(b + 1);
      lines[index] = text;
      basmala[index] = ayah == 1 && surah != 1 && surah != 9 ? basmalaPrefixLength(text) : 0;
      index++;
    }
    if (index != meta.ayahCount) throw FormatException('Quran text has $index ayat, expected ${meta.ayahCount}');
    return QuranText._(List.unmodifiable(lines), List.unmodifiable(basmala), notice.toString());
  }

  final List<String> _lines;
  final List<int> _basmalaLength;

  /// Tanzil's copyright block, as shipped at the end of the file.
  final String copyrightNotice;

  /// Words in the basmala.
  static const int basmalaWords = 4;

  /// The basmala exactly as ayah 1:1 of the bundled text (a test checks) –
  /// for previews that should not load the whole text.
  static const String openingBasmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

  /// Length of the four-word basmala plus the space after it.
  static int basmalaPrefixLength(String line) {
    var spaces = 0;
    for (var i = 0; i < line.length; i++) {
      if (line.codeUnitAt(i) == 0x20 && ++spaces == basmalaWords) return i + 1;
    }
    throw FormatException('No basmala before ayah 1', line);
  }

  /// The verbatim Tanzil line of the ayah at absolute [index] (basmala
  /// included for ayah 1 of suras 2–8, 10–114).
  String line(int index) => _lines[index];

  /// Code units of [line] taken by the basmala (0 when none).
  int basmalaLength(int index) => _basmalaLength[index];

  /// The ayah alone (no basmala, no number).
  String ayahText(int index) {
    final cut = _basmalaLength[index];
    return cut == 0 ? _lines[index] : _lines[index].substring(cut);
  }

  /// The basmala written at the head of [surah] in this text (suras 95 and
  /// 97 carry a shadda on the ba in Tanzil's text), or null for 1 and 9.
  String? basmalaOf(SurahInfo surah) {
    if (!surah.hasBasmalaHeader) return null;
    final i = surah.firstIndex;
    return _lines[i].substring(0, _basmalaLength[i] - 1);
  }

  int get length => _lines.length;
}
