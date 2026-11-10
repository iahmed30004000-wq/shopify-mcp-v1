/// Runs one request on the active path and makes sure that **whatever
/// happens, the owner gets either a checked answer, a plain refusal, or the
/// Part 3 bridge** – never a half answer, never a crash.
///
/// The daily chat will call this later (Part 7 stays as it is: its offline
/// parser is the first reader, the model only takes what the parser could not
/// read, and nothing is written without his confirmation).
///
/// What [run] does:
///  1. the active path is the bridge → [UseBridge] straight away, no model
///     is touched;
///  2. the model is missing or not ready → [UseBridge];
///  3. the input is cut by [InputPolicy] (the answer says so);
///  4. the model streams; **the text is collected, not shown live** – a verse
///     could be half out before it is recognised, and the rule is «never
///     partial text»;
///  5. the model fails mid-answer (any [ModelFailure], an out-of-memory
///     because another app took the memory, any other error, a time-out) →
///     the half answer is dropped, the model is unloaded when it ran out of
///     memory, and the result is [UseBridge] with the reason;
///  6. the complete answer goes through [ReligiousOutputGuard] and then
///     `HealthGuard`; a hit → [Refused] and **no text at all**;
///  7. otherwise [Answered].
///
/// The router makes no network call of its own and holds no HTTP client: the
/// on-device paths are on-device (asserted in the tests, and by a scan of
/// this folder's imports).
library;

import 'dart:async';

import 'package:meta/meta.dart';

import '../../ai_bridge/domain/health_guard.dart';
import 'input_policy.dart';
import 'model_path.dart';
import 'on_device_model.dart';
import 'religious_guard.dart';

/// Why the router hands the request to the bridge.
enum BridgeReason {
  /// The active path IS the bridge (the phone cannot run a model, or he chose
  /// it).
  pathIsBridge,

  /// The model is not installed / not ready.
  modelNotReady,

  /// The model failed while answering.
  failedMidAnswer,

  /// Memory ran out while answering (another app took it).
  outOfMemory,

  /// It took longer than the limit.
  timedOut,

  /// The model returned nothing.
  emptyAnswer,

  /// The instructions alone do not fit the model.
  inputTooLong,
}

@immutable
sealed class RouterOutcome {
  const RouterOutcome();
}

/// A checked answer.
final class Answered extends RouterOutcome {
  const Answered(this.text, {required this.path, this.droppedChars = 0});

  final String text;
  final ModelPath path;

  /// Characters of the input left out by the long-input policy (0 = none).
  final int droppedChars;

  bool get inputWasCut => droppedChars > 0;
}

/// The guard refused the answer. There is **no text** here by design; the
/// screen shows its own fixed message for [kind].
final class Refused extends RouterOutcome {
  const Refused(this.kind, {required this.path});

  final GuardKind kind;
  final ModelPath path;
}

/// Use the Part 3 bridge for this request (the screen opens the export
/// sheet), and say why.
final class UseBridge extends RouterOutcome {
  const UseBridge(this.reason);

  final BridgeReason reason;
}

/// He pressed Stop.
final class Cancelled extends RouterOutcome {
  const Cancelled();
}

class ModelRouter {
  ModelRouter({
    required this.activePath,
    required this.models,
    required this.guard,
    this.policy = const InputPolicy(),
    this.timeout = const Duration(seconds: 90),
  });

  /// Read at the moment of every call, so a changed choice applies at once.
  final ModelPath Function() activePath;

  /// The engines by path. A path with no engine here falls back.
  final Map<ModelPath, OnDeviceModel> models;

  final ReligiousOutputGuard guard;
  final InputPolicy policy;

  /// The longest a generation may take.
  final Duration timeout;

  Future<RouterOutcome> run(ModelRequest request, {ModelCancelToken? cancel}) async {
    final path = activePath();
    if (path == ModelPath.bridge) return const UseBridge(BridgeReason.pathIsBridge);
    final model = models[path];
    if (model == null) return const UseBridge(BridgeReason.modelNotReady);
    if (cancel?.isCancelled ?? false) return const Cancelled();

    final bool ready;
    try {
      ready = await model.isReady();
    } catch (_) {
      return const UseBridge(BridgeReason.modelNotReady);
    }
    if (!ready) return const UseBridge(BridgeReason.modelNotReady);
    if (cancel?.isCancelled ?? false) return const Cancelled();

    final TruncatedRequest cut;
    try {
      cut = policy.apply(request);
    } on InputTooLong {
      return const UseBridge(BridgeReason.inputTooLong);
    }

    final generation = model.generate(cut.request);
    final buffer = StringBuffer();
    final done = Completer<RouterOutcome?>();
    void finish(RouterOutcome? o) {
      if (!done.isCompleted) done.complete(o);
    }

    final sub = generation.tokens.listen(
      buffer.write,
      onError: (Object e, StackTrace _) {
        finish(
          UseBridge(
            e is ModelFailure && e.kind == ModelFailureKind.outOfMemory
                ? BridgeReason.outOfMemory
                : e is ModelFailure && e.kind == ModelFailureKind.notReady
                ? BridgeReason.modelNotReady
                : BridgeReason.failedMidAnswer,
          ),
        );
      },
      onDone: () => finish(null),
      cancelOnError: true,
    );
    unawaited(cancel?.whenCancelled.then((_) => finish(const Cancelled())));
    final timer = Timer(timeout, () => finish(const UseBridge(BridgeReason.timedOut)));

    final RouterOutcome? early;
    try {
      early = await done.future;
    } finally {
      timer.cancel();
    }

    if (early != null) {
      // Stop the model whatever the reason, drop the half answer.
      await sub.cancel();
      try {
        await generation.cancel();
      } catch (_) {}
      if (early is UseBridge && early.reason == BridgeReason.outOfMemory) {
        try {
          await model.unload();
        } catch (_) {}
      }
      return early;
    }
    await sub.cancel();

    final text = buffer.toString().trim();
    if (text.isEmpty) return const UseBridge(BridgeReason.emptyAnswer);

    // Religious first (absolute rule), then health.
    final verdict = guard.check(text);
    if (!verdict.allowed) return Refused(verdict.kind!, path: path);
    if (HealthGuard.scanOne(text) != null) return Refused(GuardKind.health, path: path);

    return Answered(text, path: path, droppedChars: cut.droppedChars);
  }
}
