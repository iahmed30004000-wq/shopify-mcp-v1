// Fixtures for «الحفظ» (Part 14). The mushaf's shape is the real Madani
// structure of the test catalogue, and every "result" is a row in the shape
// Part 13 writes – no second log is invented here.
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/hifz/hifz_memorisation.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import '../wird/fake_quran_catalog.dart';

/// The mushaf's shape over the test catalogue (real page / juz' starts).
MushafShape testShape() => CatalogMushafShape(FakeQuranCatalog());

/// Counts in the shape `tasmee_ayat` stores them.
RecitationCounts counts({
  required int words,
  int? right,
  int wrong = 0,
  int skipped = 0,
  int unsure = 0,
  int pending = 0,
  int extras = 0,
  int hints = 0,
}) => RecitationCounts(
  words: words,
  right: right ?? (words - wrong - skipped - unsure - pending),
  wrong: wrong,
  skipped: skipped,
  unsure: unsure,
  pending: pending,
  extras: extras,
  hints: hints,
  tashkeelDifferent: 0,
);

/// A flawless attempt at an ayah of [words] words.
RecitationCounts cleanCounts(int words) => counts(words: words);

/// One session of the log: [ayat] is what each ayah of it scored.
TasmeeSession sessionOf({
  required DateTime at,
  required Map<AyahRef, RecitationCounts> ayat,
  TasmeeMode mode = TasmeeMode.recite,
  String? id,
}) {
  final day = DateTime(at.year, at.month, at.day);
  final sessionId = id ?? 's-${at.microsecondsSinceEpoch}-${ayat.length}';
  var words = 0, right = 0, wrong = 0, skipped = 0, unsure = 0, pending = 0, extras = 0, hints = 0;
  for (final c in ayat.values) {
    words += c.words;
    right += c.right;
    wrong += c.wrong;
    skipped += c.skipped;
    unsure += c.unsure;
    pending += c.pending;
    extras += c.extras;
    hints += c.hints;
  }
  return TasmeeSession(
    id: sessionId,
    startedAt: at,
    day: day,
    mode: mode,
    range: AyahRange(ayat.keys.first, ayat.keys.last),
    counts: RecitationCounts(
      words: words,
      right: right,
      wrong: wrong,
      skipped: skipped,
      unsure: unsure,
      pending: pending,
      extras: extras,
      hints: hints,
      tashkeelDifferent: 0,
    ),
    seconds: 30,
    recogniserId: 'typed',
    recogniserVersion: '1',
    textSource: 'tanzil-uthmani',
    ayat: [
      for (final e in ayat.entries)
        TasmeeAyahResult(
          id: '$sessionId-${e.key}',
          sessionId: sessionId,
          day: day,
          ref: e.key,
          counts: e.value,
        ),
    ],
  );
}

/// One clean attempt at every ayah of [range], on [at].
TasmeeSession cleanSessionOf(MushafShape shape, AyahRange range, DateTime at, {TasmeeMode mode = TasmeeMode.recite}) =>
    sessionOf(
      at: at,
      mode: mode,
      ayat: {for (final ref in Mushaf.ayatIn(shape, range)) ref: cleanCounts(10)},
    );

/// Every ayah of every portion of a plan, in order.
List<AyahRef> planAyat(MushafShape shape, HifzDailyPlan plan) => [
  for (final p in plan.portions) ...Mushaf.ayatIn(shape, p.range),
];

/// The modes a phone with no speech model can offer.
List<HifzMethodState> methodsWithoutRecogniser() => HifzMethods.all(
  recogniser: const RecogniserAvailability(trouble: RecogniserTrouble.notImplemented),
);

/// The modes a phone whose model works can offer.
List<HifzMethodState> methodsWithRecogniser() =>
    HifzMethods.all(recogniser: const RecogniserAvailability.ready());
