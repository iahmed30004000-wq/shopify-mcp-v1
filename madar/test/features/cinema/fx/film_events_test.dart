import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';

/// Runs [events] for [seconds] of game time at 60 Hz and returns a log of
/// what was visible each film frame.
List<({int frame, double splice, double slip, double blotch, double cue, double hair})> _run(
  FilmEvents events,
  FilmLook look, {
  double seconds = 10,
  double fps = 24,
  double wear = 1,
  bool reduced = false,
}) {
  final clock = FilmClock(projectionFps: fps);
  final log = <({int frame, double splice, double slip, double blotch, double cue, double hair})>[];
  var last = -1;
  for (var t = 0.0; t < seconds; t += 1 / 60) {
    clock.advance(1 / 60);
    events.advance(clock, look, wear: wear, reducedMotion: reduced);
    if (clock.filmFrame != last) {
      last = clock.filmFrame;
      log.add((
        frame: clock.filmFrame,
        splice: events.splice,
        slip: events.frameSlip,
        blotch: events.blotch,
        cue: events.cue,
        hair: events.hair,
      ));
    }
  }
  return log;
}

void main() {
  const busy = FilmLook(
    splicesPerMinute: 30,
    frameSlipsPerMinute: 20,
    blotchesPerMinute: 30,
    hairsPerMinute: 20,
    cueMarks: true,
    reelSeconds: 6,
  );

  test('the same seed replays the same reel', () {
    final a = _run(FilmEvents(seed: 4), busy);
    final b = _run(FilmEvents(seed: 4), busy);
    final c = _run(FilmEvents(seed: 5), busy);
    expect(a, b);
    expect(a, isNot(c));
  });

  test('a busy print splices, slips, stains and grows hairs', () {
    final log = _run(FilmEvents(seed: 1), busy, seconds: 30);
    expect(log.where((e) => e.splice > 0), isNotEmpty);
    expect(log.where((e) => e.slip > 0), isNotEmpty);
    expect(log.where((e) => e.blotch > 0), isNotEmpty);
    expect(log.where((e) => e.hair > 0), isNotEmpty);
    // A frame slip rolls back into frame within a few film frames.
    var run = 0, longest = 0;
    for (final e in log) {
      run = e.slip > 0 ? run + 1 : 0;
      if (run > longest) longest = run;
    }
    expect(longest, lessThanOrEqualTo(8));
  });

  test('reel change: motor cue, then the changeover cue a few seconds later', () {
    final log = _run(FilmEvents(seed: 2), const FilmLook(cueMarks: true, reelSeconds: 5), seconds: 16);
    // Group consecutive cue frames into marks.
    final marks = <({int start, int length})>[];
    for (var i = 0; i < log.length; i++) {
      if (log[i].cue > 0 && (i == 0 || log[i - 1].cue == 0)) {
        var n = 0;
        while (i + n < log.length && log[i + n].cue > 0) {
          n++;
        }
        marks.add((start: log[i].frame, length: n));
      }
    }
    expect(marks.length, greaterThanOrEqualTo(2));
    for (final m in marks) {
      expect(m.length, 4, reason: 'a cue mark shows for four frames');
    }
    final gap = (marks[1].start - marks[0].start) / 24;
    expect(gap, inInclusiveRange(2.9, 4.1));
  });

  test('reduced motion keeps the calm wear and drops what jumps or flashes', () {
    final log = _run(FilmEvents(seed: 1), busy, seconds: 30, reduced: true);
    expect(log.every((e) => e.slip == 0), isTrue);
    expect(log.every((e) => e.blotch == 0), isTrue);
    expect(log.every((e) => e.splice <= 0.4), isTrue);
    expect(log.where((e) => e.cue > 0), isNotEmpty);
  });

  test('no wear, no events', () {
    final log = _run(FilmEvents(seed: 1), busy, seconds: 20, wear: 0);
    expect(log.every((e) => e.splice == 0 && e.slip == 0 && e.blotch == 0 && e.cue == 0 && e.hair == 0), isTrue);
  });

  test('forced events and reset', () {
    final events = FilmEvents(seed: 9)
      ..cueNow()
      ..spliceNow(y: 0.3, slip: 0.2);
    expect(events.cue, 1);
    expect(events.splice, 1);
    expect(events.spliceY, 0.3);
    expect(events.frameSlip, 0.2);
    final clock = FilmClock()..advance(1);
    events.advance(clock, FilmLook.clean);
    clock.reset();
    events.advance(clock, FilmLook.clean);
    expect(events.cue, 0);
    expect(events.frameSlip, 0);
  });

  test('every era look has sane event rates', () {
    for (final era in Era.values) {
      final look = eraLook(era);
      expect(look.splicesPerMinute, inInclusiveRange(0, 10), reason: era.name);
      expect(look.frameSlipsPerMinute, inInclusiveRange(0, 3), reason: era.name);
      expect(look.reelSeconds, greaterThan(10), reason: era.name);
    }
    expect(eraLook(Era.vhs).cueMarks, isFalse, reason: 'videotape has no reels');
  });
}
