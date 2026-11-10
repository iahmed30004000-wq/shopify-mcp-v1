// Part 15: the router - active path, fallback to the bridge when the model
// fails mid-answer, cancel, the long-input policy, and the guards on every
// answer. No network, no platform: fake models only.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ondevice_ai/domain/input_policy.dart';
import 'package:madar/features/ondevice_ai/domain/model_path.dart';
import 'package:madar/features/ondevice_ai/domain/model_router.dart';
import 'package:madar/features/ondevice_ai/domain/on_device_model.dart';
import 'package:madar/features/ondevice_ai/domain/religious_guard.dart';

import 'support/ondevice_fakes.dart';

void main() {
  // A pretend "Quran" of plain words, so these tests do not depend on the
  // bundled text (religious_guard_test.dart uses the real one).
  final guard = ReligiousOutputGuard(
    QuranVerseIndex.fromSurahs([
      ['سماء زرقاء وبحر عميق جدا ونجوم بعيدة'],
    ]),
  );

  const request = ModelRequest(instructions: 'summarise the day', input: 'I walked and drank water');

  ModelRouter router(
    FakeOnDeviceModel? aicore, {
    ModelPath Function()? path,
    FakeOnDeviceModel? engine,
    Duration timeout = const Duration(seconds: 5),
    InputPolicy policy = const InputPolicy(),
  }) => ModelRouter(
    activePath: path ?? () => ModelPath.aicore,
    models: {ModelPath.aicore: ?aicore, ModelPath.inAppEngine: ?engine},
    guard: guard,
    policy: policy,
    timeout: timeout,
  );

  FakeOnDeviceModel says(List<String> tokens, {ModelPath path = ModelPath.aicore}) =>
      FakeOnDeviceModel(path: path, tokens: tokens);

  group('the active path', () {
    test('a clean answer comes back whole, with the path that gave it', () async {
      final m = says(['You ', 'walked ', 'and drank water.']);
      final out = await router(m).run(request);
      expect(out, isA<Answered>());
      out as Answered;
      expect(out.text, 'You walked and drank water.');
      expect(out.path, ModelPath.aicore);
      expect(out.inputWasCut, isFalse);
      expect(m.requests.single.instructions, 'summarise the day');
    });

    test('the in-app engine path uses the in-app engine', () async {
      final aicore = says(['wrong']);
      final engine = says(['right'], path: ModelPath.inAppEngine);
      final out = await router(aicore, engine: engine, path: () => ModelPath.inAppEngine).run(request);
      expect((out as Answered).text, 'right');
      expect(aicore.requests, isEmpty);
    });

    test('the bridge path never touches a model', () async {
      final m = says(['x']);
      final out = await router(m, path: () => ModelPath.bridge).run(request);
      expect(out, isA<UseBridge>());
      expect((out as UseBridge).reason, BridgeReason.pathIsBridge);
      expect(m.requests, isEmpty);
    });

    test('the path is read at the moment of each call', () async {
      var path = ModelPath.aicore;
      final m = says(['ok']);
      final r = router(m, path: () => path);
      expect(await r.run(request), isA<Answered>());
      path = ModelPath.bridge;
      expect(await r.run(request), isA<UseBridge>());
    });

    test('no engine for the path, or an engine that is not ready: the bridge', () async {
      expect(((await router(null).run(request)) as UseBridge).reason, BridgeReason.modelNotReady);
      final m = says(['x'])..ready = false;
      expect(((await router(m).run(request)) as UseBridge).reason, BridgeReason.modelNotReady);
      expect(m.requests, isEmpty);
    });

    test('the step-A stub engine is never ready, so the bridge is what runs', () async {
      final r = ModelRouter(
        activePath: () => ModelPath.aicore,
        models: const {ModelPath.aicore: StubOnDeviceModel(ModelPath.aicore)},
        guard: guard,
      );
      expect(((await r.run(request)) as UseBridge).reason, BridgeReason.modelNotReady);
    });
  });

  group('falls back to the Part 3 bridge when the model fails mid-answer', () {
    test('an engine error after two tokens: the half answer is dropped, the bridge is used', () async {
      final m = FakeOnDeviceModel(
        tokens: ['half ', 'an ', 'answer'],
        failAfter: 2,
        failure: const ModelFailure(ModelFailureKind.engineError, 'boom'),
      );
      final out = await router(m).run(request);
      expect(out, isA<UseBridge>());
      expect((out as UseBridge).reason, BridgeReason.failedMidAnswer);
      expect(m.cancelled, 1, reason: 'the generation was stopped');
      expect(m.unloaded, 0, reason: 'a plain error does not unload the model');
    });

    test('another app takes the memory: out-of-memory falls back cleanly and unloads the model', () async {
      final m = FakeOnDeviceModel(
        tokens: ['some ', 'text'],
        failAfter: 1,
        failure: const ModelFailure(ModelFailureKind.outOfMemory),
      );
      final out = await router(m).run(request);
      expect((out as UseBridge).reason, BridgeReason.outOfMemory);
      expect(m.unloaded, 1, reason: 'memory is given back');
      expect(m.cancelled, 1);
    });

    test('a failure before the first token', () async {
      final m = FakeOnDeviceModel(
        tokens: ['x'],
        failAfter: 0,
        failure: const ModelFailure(ModelFailureKind.engineError),
      );
      expect(((await router(m).run(request)) as UseBridge).reason, BridgeReason.failedMidAnswer);
    });

    test('any other error from an engine (not a ModelFailure) is also a fallback, never a crash', () async {
      final m = FakeOnDeviceModel(tokens: ['a'], failAfter: 1, failure: StateError('native crash'));
      expect(((await router(m).run(request)) as UseBridge).reason, BridgeReason.failedMidAnswer);
    });

    test('too slow: a time-out is a fallback and the model is stopped', () async {
      final m = FakeOnDeviceModel(tokens: ['a '], hang: true);
      final out = await router(m, timeout: const Duration(milliseconds: 60)).run(request);
      expect((out as UseBridge).reason, BridgeReason.timedOut);
      expect(m.cancelled, 1);
    });

    test('an empty answer is a fallback', () async {
      expect(((await router(says(['  ', '\n'])).run(request)) as UseBridge).reason, BridgeReason.emptyAnswer);
    });
  });

  group('cancel', () {
    test('Stop mid-answer ends with Cancelled, no text, and the model is stopped', () async {
      final m = FakeOnDeviceModel(tokens: ['one ', 'two ', 'three ', 'four '], tokenDelay: const Duration(milliseconds: 40));
      final token = ModelCancelToken();
      final future = router(m).run(request, cancel: token);
      await Future<void>.delayed(const Duration(milliseconds: 70));
      token.cancel();
      expect(await future, isA<Cancelled>());
      expect(m.cancelled, 1);
    });

    test('Stop before the start never calls the model', () async {
      final m = says(['x']);
      final token = ModelCancelToken()..cancel();
      expect(await router(m).run(request, cancel: token), isA<Cancelled>());
      expect(m.requests, isEmpty);
    });

    test('Stop after the answer finished changes nothing', () async {
      final token = ModelCancelToken();
      final out = await router(says(['done'])).run(request, cancel: token);
      token.cancel();
      expect(out, isA<Answered>());
    });
  });

  group('a very long input', () {
    test('is cut by the written policy, the instructions stay whole, and the answer says it was cut', () async {
      final m = says(['summary']);
      final input = [for (var i = 0; i < 400; i++) 'message $i ${'z' * 40}'].join('\n');
      final out = await router(m, policy: const InputPolicy(maxChars: 3000)).run(
        ModelRequest(instructions: 'rules', input: input),
      );
      out as Answered;
      expect(out.inputWasCut, isTrue);
      expect(out.droppedChars, greaterThan(0));
      final sent = m.requests.single;
      expect(sent.instructions, 'rules');
      expect(sent.input, startsWith(truncationMarker));
      expect(sent.input, contains('message 399'));
      expect(sent.input, isNot(contains('message 0 ')));
      expect(sent.instructions.length + sent.input.length, lessThanOrEqualTo(3000));
    });

    test('instructions that alone are too long: the bridge, the model never called', () async {
      final m = says(['x']);
      final out = await router(m, policy: const InputPolicy(maxChars: 1000)).run(
        ModelRequest(instructions: 'r' * 900, input: 'hi'),
      );
      expect((out as UseBridge).reason, BridgeReason.inputTooLong);
      expect(m.requests, isEmpty);
    });
  });

  group('every output goes through the guards before it reaches the screen', () {
    test('a refused answer carries NO text at all, only the reason', () async {
      final out = await router(says(['كلام ', 'عن الصبر: ', 'سماء زرقاء وبحر عميق جدا'])).run(request);
      expect(out, isA<Refused>());
      out as Refused;
      expect(out.kind, GuardKind.quran);
      // The type has no text field: nothing partial can leak.
      expect(out.toString(), isNot(contains('سماء')));
    });

    test('a ruling in the answer is refused', () async {
      final out = await router(says(['هاد الشي ', 'حرام ', 'والله أعلم'])).run(request);
      expect((out as Refused).kind, GuardKind.ruling);
    });

    test('HealthGuard still wraps a dose or a diagnosis: the router runs it', () async {
      final dose = await router(says(['Take 500 mg ', 'twice a day'])).run(request);
      expect(dose, isA<Refused>());
      expect((dose as Refused).kind, GuardKind.health);
      final diagnosis = await router(says(['انت مصاب ', 'بمرض'])).run(request);
      expect((diagnosis as Refused).kind, GuardKind.health);
    });

    test('the religious reason outranks the health one when both are present', () async {
      final out = await router(says(['حرام ', 'وجرعة ', '500 ملغ'])).run(request);
      expect((out as Refused).kind, GuardKind.ruling);
    });

    test('a clean day summary passes', () async {
      final out = await router(says(['Today you ', 'prayed on time, ', 'spent 5 JOD on coffee ', 'and walked 30 minutes.'])).run(request);
      expect(out, isA<Answered>());
    });

    test('the model is stopped for good: tokens are collected, never shown live', () async {
      // A router result exists only after the guard ran on the WHOLE text.
      final m = says(['a verse half ', 'out ', 'سماء زرقاء وبحر عميق']);
      final out = await router(m).run(request);
      expect(out, isA<Refused>());
    });
  });
}
