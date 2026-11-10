import 'story_script.dart';

enum StoryPhase {
  /// The beat's movement is playing.
  moving,

  /// The movement is done and the beat asks the child to say a word.
  waitingToSay,

  /// The movement is done; the child goes on with «التالي».
  readyToContinue,

  /// The last movement is done.
  finished,
}

/// Where the child is in a story, as plain state (no widgets, no timers).
///
/// Saying a word moves on from a beat that asks for one: [soundHeard] when the
/// microphone noticed a sound, [skipSay] for «ما بقدر أحكي هلأ». Both do the
/// same thing on purpose; the story never knows what was said.
class StoryRunner {
  StoryRunner(this.script) : assert(script.beats.isNotEmpty);

  final StoryScript script;

  int _beat = 0;
  StoryPhase _phase = StoryPhase.moving;
  int _spoken = 0;
  int _skipped = 0;

  /// Index of the current beat.
  int get beatIndex => _beat;

  StoryBeat get beat => script.beats[_beat];

  StoryPhase get phase => _phase;

  bool get isLastBeat => _beat == script.beats.length - 1;

  bool get isFinished => _phase == StoryPhase.finished;

  /// The beat asks for a word and the movement is done.
  bool get isAskingToSay => _phase == StoryPhase.waitingToSay;

  /// How many words were followed by a sound / by the skip button.
  int get soundsHeard => _spoken;
  int get wordsSkipped => _skipped;

  /// The beat's movement reached its end.
  void motionDone() {
    if (_phase != StoryPhase.moving) return;
    if (isLastBeat) {
      _phase = StoryPhase.finished;
    } else if (beat.say != null) {
      _phase = StoryPhase.waitingToSay;
    } else {
      _phase = StoryPhase.readyToContinue;
    }
  }

  /// «التالي».
  bool next() {
    if (_phase != StoryPhase.readyToContinue) return false;
    _advance();
    return true;
  }

  /// A sound was heard. Counts only while the beat is waiting for a word.
  bool soundHeard() {
    if (_phase != StoryPhase.waitingToSay) return false;
    _spoken++;
    _advance();
    return true;
  }

  /// «ما بقدر أحكي هلأ».
  bool skipSay() {
    if (_phase != StoryPhase.waitingToSay) return false;
    _skipped++;
    _advance();
    return true;
  }

  /// Plays the current beat's movement again (stays on the same beat).
  void replayBeat() {
    _phase = StoryPhase.moving;
  }

  /// From the first beat.
  void restart() {
    _beat = 0;
    _phase = StoryPhase.moving;
    _spoken = 0;
    _skipped = 0;
  }

  void _advance() {
    if (_beat < script.beats.length - 1) _beat++;
    _phase = StoryPhase.moving;
  }
}
