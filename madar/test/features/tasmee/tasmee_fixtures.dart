// Targets built from the app's own verified Uthmani text, so every test of
// «التسميع» runs against the real data and never against a verse typed by
// hand. Nothing here writes, reflows or regenerates a letter of it.
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/quran/domain/quran_text.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import '../quran/quran_test_data.dart';

/// The verbatim ayah text (without the header basmala) of [ref].
String ayahText(AyahRef ref) => QuranTestData.text.ayahText(QuranTestData.meta.indexOf(ref));

/// A target over [range], with the basmala allowed before it – the same
/// shape `TasmeeTargets.range` builds at run time.
RecitationTarget targetOf(AyahRange range, {bool allowBasmala = true}) {
  final meta = QuranTestData.meta;
  final text = QuranTestData.text;
  final from = meta.indexOf(range.first);
  final to = meta.indexOf(range.last);
  final prelude = <List<String>>[];
  if (allowBasmala) {
    final header = text.basmalaOf(meta.surah(range.first.surah)) ?? QuranText.openingBasmala;
    prelude.add(header.split(' '));
  }
  return RecitationTarget.of([
    for (var i = from; i <= to; i++) (meta.refAt(i), text.ayahText(i)),
  ], prelude: prelude);
}

/// A target over a single ayah.
RecitationTarget targetOfAyah(AyahRef ref, {bool allowBasmala = true}) =>
    targetOf(AyahRange.single(ref), allowBasmala: allowBasmala);

/// The verified words of [target], exactly as the text writes them – what a
/// perfect reciter would be heard as.
List<String> verifiedWords(RecitationTarget target) => [for (final w in target.words) w.text];

/// The basmala as the verified text writes it at the head of a sura.
List<String> basmalaWords() => QuranText.openingBasmala.split(' ');

/// A clean script over [target].
RecitationScript cleanScript(RecitationTarget target) => RecitationScript.of(verifiedWords(target));

/// The verdicts of a check, in the order of the verified text.
List<WordVerdict> verdicts(RecitationCheck check) => [for (final w in check.words) w.verdict];
