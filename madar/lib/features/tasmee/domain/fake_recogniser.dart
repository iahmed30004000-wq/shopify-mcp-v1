/// «التسميع» · the stub recogniser (Part 13, step 1).
///
/// There is **no speech model in this build and nothing is downloaded**: the
/// whole engine is developed and tested against this stub, which replays a
/// script the test (or a dev screen) writes by hand. It implements
/// [QuranRecogniser] exactly, so step 2 drops a real on-device model in its
/// place and deletes nothing but the wiring.
///
/// A script is written in terms of what a reciter actually does: a clean
/// recitation, a dropped word, an inserted word, a wrong word, a restart
/// mid-verse, a long pause, the verse twice, a basmala first, or a word the
/// recogniser itself was unsure about. The helpers below build those from a
/// clean word list so a test never hand-writes timings.
///
/// It never touches a microphone and holds no audio of any kind.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import 'recogniser.dart';

/// One scripted word: what the stub will claim it heard.
@immutable
final class ScriptWord {
  const ScriptWord(this.heard, {this.confidence = 0.95, this.isFinal = true, this.pauseBefore = Duration.zero});

  /// The word the stub will emit – a plain string, not Quran text.
  final String heard;
  final double confidence;
  final bool isFinal;

  /// Silence before this word, on top of the script's normal gap.
  final Duration pauseBefore;

  ScriptWord copyWith({String? heard, double? confidence, bool? isFinal, Duration? pauseBefore}) => ScriptWord(
    heard ?? this.heard,
    confidence: confidence ?? this.confidence,
    isFinal: isFinal ?? this.isFinal,
    pauseBefore: pauseBefore ?? this.pauseBefore,
  );

  @override
  String toString() => 'ScriptWord($heard, ${confidence.toStringAsFixed(2)})';
}

/// A whole run of recitation, as the stub will report it.
///
/// Every mutator returns a new script, so a test reads like the mistake it
/// describes: `RecitationScript.of(words).drop(3)`.
@immutable
final class RecitationScript {
  const RecitationScript(
    this.words, {
    this.wordLength = const Duration(milliseconds: 600),
    this.gap = const Duration(milliseconds: 120),
    this.start = Duration.zero,
  });

  /// A clean recitation of [said], one word after another.
  factory RecitationScript.of(Iterable<String> said, {double confidence = 0.95}) =>
      RecitationScript([for (final w in said) ScriptWord(w, confidence: confidence)]);

  final List<ScriptWord> words;

  /// How long each word takes.
  final Duration wordLength;

  /// The silence between two words of normal recitation.
  final Duration gap;

  /// When the first word starts.
  final Duration start;

  RecitationScript _with(List<ScriptWord> next) =>
      RecitationScript(next, wordLength: wordLength, gap: gap, start: start);

  /// He skipped the word at [index] (it is simply never heard).
  RecitationScript drop(int index) => _with([...words]..removeAt(index));

  /// He said something extra before the word now at [index].
  RecitationScript insert(int index, String heard, {double confidence = 0.9}) =>
      _with([...words]..insert(index, ScriptWord(heard, confidence: confidence)));

  /// He said [heard] where the word at [index] belongs.
  RecitationScript replace(int index, String heard, {double confidence = 0.9}) =>
      _with([...words]..[index] = ScriptWord(heard, confidence: confidence));

  /// The recogniser itself was unsure about the word at [index] – it heard
  /// something, but barely (background noise, a second voice).
  RecitationScript unsure(int index, {String? heard, double confidence = 0.2}) =>
      _with([...words]..[index] = words[index].copyWith(heard: heard, confidence: confidence));

  /// He started, got to [upTo] words, stopped, and began the verse again.
  RecitationScript restartAfter(int upTo) => _with([...words.take(upTo), ...words]);

  /// He recited the whole thing twice.
  RecitationScript again() => _with([...words, ...words]);

  /// He said something before the first word (the basmala, say).
  RecitationScript precededBy(Iterable<String> said, {double confidence = 0.95}) =>
      _with([for (final w in said) ScriptWord(w, confidence: confidence), ...words]);

  /// He stopped for [length] before the word at [index] and then carried on.
  RecitationScript pauseBefore(int index, Duration length) =>
      _with([...words]..[index] = words[index].copyWith(pauseBefore: length));

  /// The model first guessed [heard] for the word at [index] and then
  /// corrected itself – a partial hypothesis the engine must not score.
  RecitationScript partialAt(int index, String heard) =>
      _with([...words]..insert(index, ScriptWord(heard, confidence: 0.5, isFinal: false)));

  /// The script as the recogniser would report it, with timings.
  List<HeardWord> heardWords() {
    final out = <HeardWord>[];
    var clock = start;
    for (final w in words) {
      clock += w.pauseBefore;
      out.add(
        HeardWord(
          heard: w.heard,
          at: clock,
          until: clock + wordLength,
          confidence: w.confidence,
          isFinal: w.isFinal,
        ),
      );
      clock += wordLength + gap;
    }
    return out;
  }

  /// How long the whole run lasts.
  Duration get length => heardWords().isEmpty ? Duration.zero : heardWords().last.end;
}

/// A [QuranRecogniser] that replays a [RecitationScript]. **A stub, never a
/// judge**: it holds no model, opens no microphone, downloads nothing and
/// touches no audio.
class FakeQuranRecogniser implements QuranRecogniser {
  FakeQuranRecogniser(
    this.script, {
    this.availabilityValue = const RecogniserAvailability.ready(),
    this.info = const RecogniserInfo(
      id: 'fake',
      version: '1',
      name: 'Madar scripted stub',
      licence: 'none (test stub)',
      credit: 'Not a model: a script replayed for the tests of Part 13.',
    ),
    this.emitDelay = Duration.zero,
  });

  /// What it will claim to hear.
  RecitationScript script;

  /// What [availability] answers – a test sets it to
  /// [RecogniserTrouble.noPermission] to drive the degrade path.
  RecogniserAvailability availabilityValue;

  @override
  final RecogniserInfo info;

  /// Wall-clock delay between emitted words (zero in tests).
  final Duration emitDelay;

  /// Runs started, newest last – a test asserts the microphone was closed.
  final List<FakeRecognitionRun> runs = [];

  @override
  Future<RecogniserAvailability> availability() async => availabilityValue;

  @override
  Future<RecognitionRun> start({RecitationHints hints = const RecitationHints.none()}) async {
    if (!availabilityValue.isReady) {
      throw StateError('FakeQuranRecogniser is not ready: ${availabilityValue.trouble}');
    }
    final run = FakeRecognitionRun(script.heardWords(), hints: hints, emitDelay: emitDelay);
    runs.add(run);
    return run;
  }
}

/// One replay of a script.
class FakeRecognitionRun implements RecognitionRun {
  FakeRecognitionRun(this._queue, {this.hints = const RecitationHints.none(), this.emitDelay = Duration.zero}) {
    _controller = StreamController<HeardWord>(onListen: _pump);
  }

  final List<HeardWord> _queue;
  final RecitationHints hints;
  final Duration emitDelay;
  late final StreamController<HeardWord> _controller;
  var _listening = true;
  var _cancelled = false;

  /// True once [stop] or [cancel] has completed – a stand-in for "the
  /// microphone is closed and every buffer is gone".
  var closed = false;

  @override
  bool get isListening => _listening;

  @override
  Stream<HeardWord> get words => _controller.stream;

  Future<void> _pump() async {
    for (final word in _queue) {
      if (!_listening) break;
      if (emitDelay > Duration.zero) await Future<void>.delayed(emitDelay);
      if (!_listening) break;
      _controller.add(word);
    }
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> stop() async {
    _listening = false;
    closed = true;
    if (_controller.isClosed) return;
    // A single-subscription controller's `close()` does not complete until
    // someone listens, so a run nobody read (he changed his mind before the
    // first word) must not be awaited or the caller would hang.
    final listened = _controller.hasListener;
    final closing = _controller.close();
    if (listened) await closing;
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await stop();
  }

  /// Whether this run was thrown away rather than scored.
  bool get wasCancelled => _cancelled;
}
