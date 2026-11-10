import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/today/domain/objective_state.dart';

import 'today_fixtures.dart';

void main() {
  const empty = ObjectiveState.empty();

  test('starts empty', () {
    expect(empty.isEmpty, isTrue);
    expect(empty.marks, isEmpty);
    expect(empty.markFor('x', '2026-11-10'), isNull);
  });

  test('done, snooze and skip are kept by id and day; the latest answer wins', () {
    final s = empty.markDone('a', day).snooze('b', day, at(9, 0)).skip('c', day);
    expect(s.markFor('a', '2026-11-10')?.kind, ObjectiveMarkKind.done);
    expect(s.markFor('b', '2026-11-10')?.until, at(9, 0));
    expect(s.markFor('c', '2026-11-10')?.kind, ObjectiveMarkKind.skipped);
    expect(s.markFor('a', '2026-11-11'), isNull);
    final changed = s.skip('b', day);
    expect(changed.markFor('b', '2026-11-10')?.kind, ObjectiveMarkKind.skipped);
    expect(changed.markFor('b', '2026-11-10')?.until, isNull);
    expect(s.clear('a', day).markFor('a', '2026-11-10'), isNull);
    expect(identical(s.clear('nope', day), s), isTrue);
  });

  test('is immutable', () {
    final s = empty.markDone('a', day);
    expect(empty.isEmpty, isTrue);
    expect(s.isEmpty, isFalse);
  });

  test('JSON round trip keeps everything, in a stable order', () {
    final s = empty.markDone('b', day).snooze('a', day, at(9, 30)).skip('c', at(1, 0, dayOffset: 1));
    final copy = ObjectiveState.decode(s.encode());
    expect(copy, s);
    expect(copy.hashCode, s.hashCode);
    expect(copy.encode(), s.encode());
    final json = jsonDecode(s.encode()) as Map;
    expect(json['v'], ObjectiveState.version);
    expect(json['marks'], hasLength(3));
  });

  test('corrupt input never throws and costs only the broken marks', () {
    expect(ObjectiveState.decode(null), empty);
    expect(ObjectiveState.decode(''), empty);
    expect(ObjectiveState.decode('{not json'), empty);
    expect(ObjectiveState.fromJson(42), empty);
    expect(ObjectiveState.fromJson({'marks': 'x'}), empty);
    final s = ObjectiveState.fromJson({
      'v': 99,
      'marks': [
        {'id': 'ok', 'day': '2026-11-10', 'kind': 'skipped'},
        {'id': '', 'day': '2026-11-10', 'kind': 'done'},
        {'id': 'x', 'day': '2026-11-10', 'kind': 'nonsense'},
        {'id': 'y', 'day': '2026-11-10', 'kind': 'snoozed'},
        {'id': 'z', 'day': '2026-11-10', 'kind': 'snoozed', 'until': 'garbage'},
        'string',
        null,
      ],
    });
    expect(s.marks.map((m) => m.id), ['ok']);
  });

  test('pruneBefore drops older days only', () {
    final y = day.subtract(const Duration(days: 1));
    final s = empty.skip('old', y).skip('today', day);
    expect(s.pruneBefore(day).marks.map((m) => m.id), ['today']);
    expect(identical(s.pruneBefore(y), s), isTrue);
  });

  test('snooze options are 15, 30 and 60 minutes', () {
    expect(SnoozeOption.values.map((o) => o.duration.inMinutes), [15, 30, 60]);
  });

  test('dayKey is zero padded', () {
    expect(ObjectiveState.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
  });
}
