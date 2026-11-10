import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/guide/guide.dart';

void main() {
  const start = FirstRunFlow.start();

  test('six steps in the order the brief names', () {
    expect(FirstRunFlow.steps.map((s) => s.id), ['welcome', 'city', 'planets', 'reminders', 'lock', 'ready']);
    expect(start.current, FirstRunStep.welcome);
    expect(start.isInProgress, isTrue);
    expect(start.total, 6);
  });

  group('next / back', () {
    test('next walks forward and marks the step done', () {
      final f = start.next();
      expect(f.current, FirstRunStep.city);
      expect(f.done, {FirstRunStep.welcome});
      expect(f.progress, closeTo(2 / 6, 1e-9));
    });

    test('back returns to the previous step and keeps what was done; nothing before the first', () {
      final f = start.next().next().back();
      expect(f.current, FirstRunStep.city);
      expect(f.done, {FirstRunStep.welcome, FirstRunStep.city});
      expect(start.back(), start);
      expect(start.canGoBack, isFalse);
    });

    test('next from the last step completes the first run', () {
      var f = start;
      for (var i = 0; i < 5; i++) {
        f = f.next();
      }
      expect(f.current, FirstRunStep.ready);
      expect(f.isLast, isTrue);
      expect(f.isInProgress, isTrue);
      f = f.next();
      expect(f.status, FirstRunStatus.completed);
      expect(f.isFinished, isTrue);
      expect(f.done.length, 6);
      expect(f.skipped, isEmpty);
    });

    test('a finished flow no longer moves', () {
      var f = start;
      for (var i = 0; i < 6; i++) {
        f = f.next();
      }
      expect(f.next(), f);
      expect(f.back(), f);
      expect(f.skipStep(), f);
      expect(f.skipAll(), f);
    });

    test('redoing a skipped step by going back removes it from skipped', () {
      final f = start.next().skipStep().back().next();
      expect(f.skipped, isEmpty);
      expect(f.done, contains(FirstRunStep.city));
    });
  });

  group('skip', () {
    test('skip-step moves on and remembers the step as skipped', () {
      final f = start.next().skipStep();
      expect(f.current, FirstRunStep.planets);
      expect(f.skipped, {FirstRunStep.city});
      expect(f.wasSkipped(FirstRunStep.city), isTrue);
    });

    test('the last step cannot be skipped, only started', () {
      var f = start;
      for (var i = 0; i < 5; i++) {
        f = f.next();
      }
      expect(f.canSkipStep, isFalse);
      expect(f.canSkipAll, isFalse);
      expect(f.skipStep(), f);
      expect(f.skipAll(), f);
    });

    test('skip-all ends it, marking everything not yet done as skipped', () {
      final f = start.next().next().skipAll();
      expect(f.status, FirstRunStatus.skippedAll);
      expect(f.isFinished, isTrue);
      expect(f.done, {FirstRunStep.welcome, FirstRunStep.city});
      expect(f.skipped, {FirstRunStep.planets, FirstRunStep.reminders, FirstRunStep.lock, FirstRunStep.ready});
    });
  });

  group('the backup branch at step one', () {
    test('offered only at the first step while in progress', () {
      expect(start.canOfferBackup, isTrue);
      expect(start.next().canOfferBackup, isFalse);
      expect(start.next().haveBackup(), start.next());
    });

    test('yes, I have a backup: restoring; when it works the first run is over', () {
      final r = start.haveBackup();
      expect(r.status, FirstRunStatus.restoringBackup);
      expect(r.isFinished, isFalse);
      expect(r.next(), r, reason: 'steps do not move while restoring');
      final done = r.backupRestored();
      expect(done.status, FirstRunStatus.completed);
      expect(done.isFinished, isTrue);
      expect(done.done, {FirstRunStep.welcome});
    });

    test('a cancelled or failed restore goes back to the welcome step', () {
      final f = start.haveBackup().backupCancelled();
      expect(f, start);
      expect(f.next().current, FirstRunStep.city);
    });

    test('restore results are ignored when not restoring', () {
      expect(start.backupRestored(), start);
      expect(start.backupCancelled(), start);
    });
  });

  group('saving and resuming', () {
    test('an interrupted first run resumes where it stopped', () {
      final f = start.next().skipStep(); // city done?, planets next
      final back = FirstRunFlow.decode(f.encode());
      expect(back, f);
      expect(back.current, FirstRunStep.planets);
      expect(back.next().current, FirstRunStep.reminders);
    });

    test('every state round-trips: in progress, restoring, completed, skipped-all', () {
      final states = [
        start,
        start.next().next(),
        start.haveBackup(),
        start.haveBackup().backupRestored(),
        start.next().skipAll(),
        start.skipStep().skipStep().next(),
      ];
      for (final s in states) {
        expect(FirstRunFlow.decode(s.encode()), s, reason: '$s');
        expect(FirstRunFlow.fromJson(s.toJson()), s);
      }
    });

    test('resuming in the middle of a restore stays in the restore', () {
      expect(FirstRunFlow.decode(start.haveBackup().encode()).status, FirstRunStatus.restoringBackup);
    });

    test('garbage, empty and unknown data give a fresh start', () {
      expect(FirstRunFlow.decode(null), start);
      expect(FirstRunFlow.decode(''), start);
      expect(FirstRunFlow.decode('not json'), start);
      expect(FirstRunFlow.decode('[1,2]'), start);
      expect(FirstRunFlow.fromJson({'current': 'nope', 'status': 'inProgress'}), start);
      expect(FirstRunFlow.fromJson({'current': 'city', 'status': 'weird'}), start);
    });

    test('unknown step ids from a newer build are ignored', () {
      final f = FirstRunFlow.fromJson({
        'v': 9,
        'current': 'lock',
        'status': 'inProgress',
        'done': ['welcome', 'telepathy'],
        'skipped': 'oops',
      });
      expect(f.current, FirstRunStep.lock);
      expect(f.done, {FirstRunStep.welcome});
      expect(f.skipped, isEmpty);
    });
  });
}
