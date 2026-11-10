/// The one door every on-device engine goes through (Part 15).
///
/// Step A of the part builds everything around this interface and proves it
/// with fakes. The real engines (Gemma through AICore, Google AI Edge /
/// LiteRT) are plugged in behind it in step B, after they have been measured
/// on the owner's phone; until then [StubOnDeviceModel] is the only
/// implementation in the app and it says «not ready», so the router falls
/// back to the bridge. No native API is guessed here.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'model_path.dart';

/// What to ask the model. The two parts are kept apart because the long-input
/// policy may cut [input] but never [instructions] (the rules the model must
/// follow).
@immutable
class ModelRequest {
  const ModelRequest({required this.instructions, required this.input, this.maxOutputTokens = 512});

  /// The fixed rules / system prompt. Never truncated.
  final String instructions;

  /// What the model reads: his day's chat, his data. Truncated when long.
  final String input;

  final int maxOutputTokens;

  ModelRequest withInput(String value) =>
      ModelRequest(instructions: instructions, input: value, maxOutputTokens: maxOutputTokens);
}

/// Why a generation ended in an error.
enum ModelFailureKind {
  /// The engine ran out of memory (another app took it, mid-answer).
  outOfMemory,

  /// The engine or the system service failed.
  engineError,

  /// Not loaded / not installed / not available now.
  notReady,
}

class ModelFailure implements Exception {
  const ModelFailure(this.kind, [this.detail]);

  final ModelFailureKind kind;

  /// For logs and tests only; never shown (it may be an engine's raw text).
  final String? detail;

  @override
  String toString() => 'ModelFailure(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// One running generation: its tokens, and a way to stop it.
abstract interface class ModelGeneration {
  /// Pieces of text as the model writes them. Errors arrive as a
  /// [ModelFailure]. Listen once.
  Stream<String> get tokens;

  /// Stops the model and frees what it holds. Safe to call twice.
  Future<void> cancel();
}

abstract interface class OnDeviceModel {
  /// Which path this engine serves ([ModelPath.aicore] or
  /// [ModelPath.inAppEngine]).
  ModelPath get path;

  /// Whether a [generate] would start now (weights present, service bound).
  Future<bool> isReady();

  /// Starts a generation. Never throws for an engine problem: the problem is
  /// delivered on the stream as a [ModelFailure].
  ModelGeneration generate(ModelRequest request);

  /// Releases the model's memory (the owner leaves, the phone is low on
  /// memory, a generation ran out of it).
  Future<void> unload();
}

/// A stop button shared between a screen and a running [ModelRouter.run].
class ModelCancelToken {
  final Completer<void> _done = Completer<void>();

  bool get isCancelled => _done.isCompleted;
  Future<void> get whenCancelled => _done.future;

  void cancel() {
    if (!_done.isCompleted) _done.complete();
  }
}

/// The only engine in the app until step B: never ready. A call that reaches
/// it anyway fails with [ModelFailureKind.notReady] instead of guessing.
class StubOnDeviceModel implements OnDeviceModel {
  const StubOnDeviceModel(this.path);

  @override
  final ModelPath path;

  @override
  Future<bool> isReady() async => false;

  @override
  ModelGeneration generate(ModelRequest request) => _StubGeneration();

  @override
  Future<void> unload() async {}
}

class _StubGeneration implements ModelGeneration {
  @override
  Stream<String> get tokens => Stream<String>.error(const ModelFailure(ModelFailureKind.notReady, 'stub engine'));

  @override
  Future<void> cancel() async {}
}
