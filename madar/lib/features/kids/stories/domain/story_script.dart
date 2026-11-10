import 'package:flutter/foundation.dart';

/// Text in the two languages of the app. A story is content, not interface,
/// so its words live in its script (a story can be added without touching the
/// app's string files).
@immutable
class LocalizedText {
  const LocalizedText({required this.ar, required this.en});

  final String ar;
  final String en;

  String of(String languageCode) => languageCode == 'ar' ? ar : en;
}

/// Where the star is and how brightly it shines, on a stage measured 0..1 in
/// both directions (x from the reading start, y from the top).
@immutable
class StoryPose {
  const StoryPose(this.x, this.y, this.glow);

  final double x, y;

  /// 0 (out) .. 1 (full light).
  final double glow;
}

/// A word the child is asked to say. The app does not recognise speech yet:
/// the story goes on when the microphone hears any sound, or when the child
/// presses «ما بقدر أحكي هلأ». The screen never says the word was understood.
@immutable
class SayPrompt {
  const SayPrompt(this.word);
  final LocalizedText word;
}

/// One beat of a story: a few lines, a small movement of the star and the
/// lantern, and sometimes a word to say.
@immutable
class StoryBeat {
  const StoryBeat({
    required this.narration,
    required this.from,
    required this.to,
    this.lanternFrom = 0,
    this.lanternTo = 0,
    this.trail = false,
    this.sparkles = 0,
    this.say,
    this.motionMs = 2600,
  });

  final LocalizedText narration;

  /// The star at the start and at the end of the beat's movement.
  final StoryPose from, to;

  /// How lit the lantern is (0..1) at the start and the end.
  final double lanternFrom, lanternTo;

  /// Ghost copies of the star behind it while it moves.
  final bool trail;

  /// How many little stars twinkle (0..[StoryScript.maxSparkles]).
  final int sparkles;

  final SayPrompt? say;

  /// How long the movement takes.
  final int motionMs;
}

/// A whole story: plain data (nothing here draws or plays), so more stories
/// can be added by writing another const script.
@immutable
class StoryScript {
  const StoryScript({required this.id, required this.title, required this.beats, this.starReason});

  /// Lower-case, unique.
  final String id;
  final LocalizedText title;
  final List<StoryBeat> beats;

  /// The star reason awarded once at the end (see the rewards).
  final String? starReason;

  static const int maxSparkles = 16;

  /// Beats that ask the child to say something.
  int get promptCount => beats.where((b) => b.say != null).length;
}
