// Probes (kept as regression tests): highlight ranges on fully vowelled
// Arabic, hamza forms, prefixes with the article and Arabic-Indic digits
// cover exactly the matched letters with their marks, and never cut a
// letter from its marks or a surrogate pair.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/search/domain/search_doc.dart';
import 'package:madar/features/search/domain/search_index.dart';

String lit(String text, List<HighlightRange> ranges) => [for (final r in ranges) text.substring(r.start, r.end)].join('|');

bool isMark(int c) =>
    (c >= 0x064B && c <= 0x065F) || c == 0x0670 || (c >= 0x06D6 && c <= 0x06ED) || c == 0x0640 || (c >= 0x0300 && c <= 0x036F);

bool isLowSurrogate(int c) => c >= 0xDC00 && c <= 0xDFFF;

/// No range starts on a mark / low surrogate, and none ends right before one.
void expectClean(String text, List<HighlightRange> ranges) {
  for (final r in ranges) {
    expect(r.start, inInclusiveRange(0, text.length));
    expect(r.end, inInclusiveRange(r.start, text.length));
    if (r.start < text.length) {
      final c = text.codeUnitAt(r.start);
      expect(isMark(c) || isLowSurrogate(c), isFalse, reason: 'range $r of «$text» starts inside a letter');
    }
    if (r.end < text.length) {
      final c = text.codeUnitAt(r.end);
      expect(isMark(c) || isLowSurrogate(c), isFalse, reason: 'range $r of «$text» cuts a letter from its marks');
    }
  }
}

void main() {
  const cases = <(String, String, String)>[
    // text, query, expected lit
    ('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً', 'حسنة', 'حَسَنَةً'),
    ('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً', 'دنيا', 'دُّنْيَا'),
    ('رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً', 'اتنا', 'آتِنَا'),
    ('مُحَمَّدٌ رَسُولُ اللَّهِ', 'محم', 'مُحَمَّ'),
    ('بِالْمَالِ وَالْبَنِينَ', 'مال', 'مَالِ'),
    ('لِلْمُسْتَشْفَى غَدًا', 'مستشف', 'مُسْتَشْفَ'),
    ('المَسْؤُولُ عَنِ الدَّوَاءِ', 'مسؤول', 'مَسْؤُولُ'),
    ('المَسْؤُولُ عَنِ الدَّوَاءِ', 'الدواء', 'الدَّوَاءِ'),
    ('دفعت ١٢٫٥ JOD للصيدلية', '12', '١٢'),
    ('مـحـمـد الخطيب', 'محمد', 'مـحـمـد'),
    ('🌙رمضان كريم 🌙', 'رمضان', 'رمضان'),
    ('Café crème brûlée', 'creme', 'crème'),
  ];
  for (final (text, query, expected) in cases) {
    test('«$query» lights «$expected» in «$text»', () {
      final ranges = SearchIndex.highlightQuery(text, query);
      expect(lit(text, ranges), expected);
      expectClean(text, ranges);
    });
  }
}
