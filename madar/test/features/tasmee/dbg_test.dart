import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import 'tasmee_fixtures.dart';

void main() {
  test('debug', () {
    final t = targetOfAyah(const AyahRef(1, 2));
    final said = verifiedWords(t);
    final script = RecitationScript.of(said).restartAfter(2);
    print('heard: ${script.words.map((w) => w.heard).toList()}');
    final r = TasmeeAligner.align(t, script.heardWords());
    print('verdicts: ${[for (final w in r.words) w.verdict.name]}');
    for (final e in r.extras) {
      print('extra "${e.heard}" gap=${e.beforeWord} reason=${e.reason}');
    }
    print('expected folded: ${[for (final w in t.words) w.folded]}');
    print('prelude folded: ${t.foldedPrelude}');
  });
}
