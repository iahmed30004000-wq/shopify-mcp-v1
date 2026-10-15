/// «التسميع» · the recogniser boundary (Part 13, step 1).
///
/// **What the real on-device model must provide, exactly.** A
/// [QuranRecogniser] owns the microphone itself and hands this engine
/// nothing but words: it is started with [QuranRecogniser.start] (which may
/// be given [RecitationHints] – the ayah range the user said he is about to
/// recite, and whether he wants diacritics – as *hints only*, never as an
/// answer the model may echo back), it streams [HeardWord] values as it
/// decodes, each carrying the word as the model heard it ([HeardWord.heard],
/// a plain string that is **not** Quran text), the time it started and
/// ended measured from the start of listening, a confidence in `0.0 … 1.0`
/// that is comparable between words of one run, and `isFinal` false for a
/// hypothesis it may still revise and true once it will not; it must emit
/// every final word exactly once, in the order it was recited, with
/// non-decreasing [HeardWord.at]; it must run with no network at all; it
/// must close the microphone and destroy every audio buffer when
/// [RecognitionRun.stop] or [RecognitionRun.cancel] completes; it must
/// report through [QuranRecogniser.availability] – before anything is
/// recorded – that it cannot run on this phone, that the microphone
/// permission is missing, or that its files are not installed; and it must
/// describe itself in [RecogniserInfo] with the model's name, version and
/// **licence**, because the About screen credits it and a test asserts the
/// licence file ships. It is **not** asked for: audio, a waveform, a file
/// path, a transcript of a whole verse, punctuation, or any judgement about
/// right and wrong – all the judging happens here, against the verified
/// text. Step 2 swaps the implementation behind this one file and nothing
/// else changes.
///
/// **Why there is no audio in this API at all.** The owner's rule is that
/// audio never leaves the phone and that a recording is gone after scoring.
/// The cheapest way to keep that promise is to make it the only possible
/// shape: no type in this library holds bytes, a buffer, a file path or a
/// duration of recorded sound, so there is nothing for the engine, a screen
/// or an export to keep by accident. The recogniser may buffer audio inside
/// itself while it decodes; it may not hand it over.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';

/// One word as the recogniser heard it.
///
/// [heard] is deliberately **not** called `text`: it is the model's guess at
/// what the reciter said, it is never the Quran, and a screen must label it
/// as «اللي سمعه التطبيق» and style it differently from the verified text.
@immutable
final class HeardWord {
  const HeardWord({
    required this.heard,
    required this.at,
    this.until,
    this.confidence = 1.0,
    this.isFinal = true,
  }) : assert(confidence >= 0.0 && confidence <= 1.0);

  /// What the model thought it heard. **Not Quran text.**
  final String heard;

  /// When the word started, from the start of listening.
  final Duration at;

  /// When it ended, if the model knows.
  final Duration? until;

  /// `0.0 … 1.0`, comparable within one run.
  final double confidence;

  /// False while the model may still revise this word.
  final bool isFinal;

  /// The end of the word, falling back to its start.
  Duration get end => until ?? at;

  HeardWord copyWith({String? heard, Duration? at, Duration? until, double? confidence, bool? isFinal}) => HeardWord(
    heard: heard ?? this.heard,
    at: at ?? this.at,
    until: until ?? this.until,
    confidence: confidence ?? this.confidence,
    isFinal: isFinal ?? this.isFinal,
  );

  @override
  String toString() => 'HeardWord($heard @${at.inMilliseconds}ms, ${confidence.toStringAsFixed(2)}'
      '${isFinal ? '' : ', partial'})';
}

/// Why the recogniser cannot be used right now – always answerable
/// **before** a microphone is opened, so the screen can fall back to
/// reading and listening instead of crashing.
enum RecogniserTrouble {
  /// It is ready.
  none,

  /// The phone cannot run the model (too little memory, no accelerator).
  /// The owner's rule: say so plainly and keep listening-only working.
  phoneCannotRun,

  /// `RECORD_AUDIO` was never granted.
  noPermission,

  /// Granted once and then refused for good (Android's "don't ask again").
  permissionDeniedForever,

  /// The model's files are not on the phone yet.
  modelMissing,

  /// There is no real recogniser in this build (the stub).
  notImplemented,
}

/// What the recogniser can do right now.
@immutable
final class RecogniserAvailability {
  const RecogniserAvailability({this.trouble = RecogniserTrouble.none, this.detail});

  const RecogniserAvailability.ready() : trouble = RecogniserTrouble.none, detail = null;

  final RecogniserTrouble trouble;

  /// A technical detail for the log, never shown as-is.
  final String? detail;

  bool get isReady => trouble == RecogniserTrouble.none;

  @override
  String toString() => 'RecogniserAvailability($trouble${detail == null ? '' : ': $detail'})';
}

/// Who the recogniser is, for the About screen and the log.
///
/// [licence] and [licenceFile] are not decoration: Part 13's definition of
/// done has a test that the licence file ships and is credited, and the
/// mistake log records [id]/[version] with every session so a result is
/// never mistaken for the verdict of a different model.
@immutable
final class RecogniserInfo {
  const RecogniserInfo({
    required this.id,
    required this.version,
    required this.name,
    required this.licence,
    this.licenceFile,
    this.credit,
    this.onDevice = true,
  });

  /// Stable short id written into the log (`fake`, `whisper-quran` …).
  final String id;
  final String version;

  /// The model's own name, as its authors write it.
  final String name;

  /// The licence's name (`Apache-2.0`, `CC-BY-4.0` …).
  final String licence;

  /// The asset path of the full licence text that ships with the app.
  final String? licenceFile;

  /// The credit line the About screen shows.
  final String? credit;

  /// False would mean audio leaves the phone – never allowed; the engine
  /// refuses such a recogniser.
  final bool onDevice;

  @override
  String toString() => 'RecogniserInfo($id $version, $licence)';
}

/// What the engine tells the recogniser before it listens: hints, never an
/// answer.
///
/// A model that is told the range may use it to bias its decoding, but the
/// engine never trusts the output more because of it, and the model must
/// not simply read the expected words back.
@immutable
final class RecitationHints {
  const RecitationHints({this.range, this.wantsTashkeel = false});

  const RecitationHints.none() : range = null, wantsTashkeel = false;

  /// What he said he is about to recite, when he said it (recite-to-find
  /// passes null: it has no idea yet, and that is the point).
  final AyahRange? range;

  /// Whether the caller would like diacritics in [HeardWord.heard]. Even
  /// when true the tashkeel check stays experimental and off by default.
  final bool wantsTashkeel;

  @override
  String toString() => 'RecitationHints(${range ?? 'open'}${wantsTashkeel ? ', tashkeel' : ''})';
}

/// One run of listening. It exists only while the microphone is open.
abstract interface class RecognitionRun {
  /// The words as they are decoded. A single-subscription stream that
  /// closes when the run ends.
  Stream<HeardWord> get words;

  /// Stops listening normally: closes the microphone, drops every audio
  /// buffer, flushes the last final words and closes [words].
  Future<void> stop();

  /// Stops listening and throws away whatever was decoded (he changed his
  /// mind). Also closes the microphone and drops every buffer.
  Future<void> cancel();

  /// False once [stop] or [cancel] has completed.
  bool get isListening;
}

/// On-device recognition of Quranic recitation.
///
/// The whole contract is in this library's own doc comment. Implementations
/// live behind it: [FakeQuranRecogniser] today, the real model in step 2.
abstract interface class QuranRecogniser {
  RecogniserInfo get info;

  /// Checked **before** the microphone is opened.
  Future<RecogniserAvailability> availability();

  /// Opens the microphone and starts decoding. Throws [StateError] when
  /// [availability] is not ready – the caller is expected to ask first.
  Future<RecognitionRun> start({RecitationHints hints = const RecitationHints.none()});
}
