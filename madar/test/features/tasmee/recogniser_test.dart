// The recogniser boundary: what the stub promises, and what the real model
// of step 2 will have to promise in its place. No model, no microphone, no
// audio – and the API has no shape for any of them.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import 'tasmee_fixtures.dart';

void main() {
  group('the scripted stub', () {
    test('it streams the script in order, with monotonic timings and a confidence', () async {
      final target = targetOfAyah(const AyahRef(1, 2));
      final stub = FakeQuranRecogniser(cleanScript(target));
      expect((await stub.availability()).isReady, isTrue);
      final run = await stub.start(hints: RecitationHints(range: AyahRange.single(const AyahRef(1, 2))));
      final heard = await run.words.toList();
      expect(heard.map((w) => w.heard), verifiedWords(target));
      for (var i = 1; i < heard.length; i++) {
        expect(heard[i].at, greaterThanOrEqualTo(heard[i - 1].end));
      }
      expect(heard.every((w) => w.confidence > 0 && w.confidence <= 1), isTrue);
      expect(heard.every((w) => w.isFinal), isTrue);
      await run.stop();
      expect(run.isListening, isFalse);
      expect((stub.runs.single).closed, isTrue, reason: 'the microphone is closed and the buffers are gone');
    });

    test('a pause in the script shows up as a real gap in the timings', () async {
      final target = targetOfAyah(const AyahRef(1, 2));
      final stub = FakeQuranRecogniser(cleanScript(target).pauseBefore(2, const Duration(seconds: 8)));
      final run = await stub.start();
      final heard = await run.words.toList();
      expect(heard[2].at - heard[1].end, greaterThanOrEqualTo(const Duration(seconds: 8)));
      await run.stop();
    });

    test('a run thrown away says so, and still closes', () async {
      final stub = FakeQuranRecogniser(RecitationScript.of(const ['a', 'b']));
      final run = await stub.start();
      await run.cancel();
      expect(run.isListening, isFalse);
      expect((run as FakeRecognitionRun).wasCancelled, isTrue);
      expect(run.closed, isTrue);
    });
  });

  group('a recogniser that cannot run', () {
    test('it says so before the microphone is ever opened, and refuses to start', () async {
      for (final trouble in [
        RecogniserTrouble.phoneCannotRun,
        RecogniserTrouble.noPermission,
        RecogniserTrouble.permissionDeniedForever,
        RecogniserTrouble.modelMissing,
        RecogniserTrouble.notImplemented,
      ]) {
        final stub = FakeQuranRecogniser(
          RecitationScript.of(const ['a']),
          availabilityValue: RecogniserAvailability(trouble: trouble),
        );
        final availability = await stub.availability();
        expect(availability.isReady, isFalse);
        expect(availability.trouble, trouble);
        expect(stub.start, throwsStateError);
        expect(stub.runs, isEmpty, reason: 'nothing was recorded');
      }
    });
  });

  group('the contract step 2 has to satisfy', () {
    test('a recogniser names itself, its version and its licence', () {
      const stub = RecogniserInfo(id: 'fake', version: '1', name: 'stub', licence: 'none (test stub)');
      expect(stub.id, isNotEmpty);
      expect(stub.version, isNotEmpty);
      expect(stub.licence, isNotEmpty);
      expect(stub.onDevice, isTrue, reason: 'a recogniser that is not on the device is never allowed');
    });

    test('what crosses the boundary is a word, a time and a confidence – never audio', () {
      const word = HeardWord(heard: 'الحمد', at: Duration(milliseconds: 120), confidence: 0.9);
      expect(word.heard, 'الحمد');
      expect(word.end, word.at, reason: 'an end the model does not know falls back to the start');
      // The field is called `heard`, never `text`, so a screen cannot render
      // it as the verse by accident.
      expect(word.toString(), contains('الحمد'));
    });

    test('a confidence outside 0…1 is a programming error, not a silently clamped number', () {
      expect(() => HeardWord(heard: 'x', at: Duration.zero, confidence: 1.5), throwsA(isA<AssertionError>()));
    });
  });
}
