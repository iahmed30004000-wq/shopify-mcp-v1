import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/hajj/hajj.dart';

RoundCounter _counter() => RoundCounter(newId: () => 'id', monotonic: () => Duration.zero)..start(RoundKind.tawaf);

void main() {
  test('save then load through the store restores the counter', () async {
    final store = MemoryRoundCounterStore();
    final p = RoundCounterPersister(store);
    final c = _counter();
    c.setRound(4);
    p.save(c);
    await p.flush();
    final back = await RoundCounterPersister(store).load();
    expect(back.sessions, c.sessions);
    p.dispose();
  });

  test('nothing saved gives an empty counter', () async {
    final back = await RoundCounterPersister(MemoryRoundCounterStore()).load();
    expect(back.sessions, isEmpty);
  });

  test('unreadable saved text gives an empty counter', () async {
    final back = await RoundCounterPersister(MemoryRoundCounterStore('{not json')).load();
    expect(back.sessions, isEmpty);
  });

  test('a burst of changes in one turn is written once, with the newest state', () async {
    final store = MemoryRoundCounterStore();
    final p = RoundCounterPersister(store);
    final c = _counter();
    for (var n = 1; n <= 5; n++) {
      c.setRound(n);
      p.save(c);
    }
    await p.flush();
    expect(store.writes, hasLength(1));
    expect((await p.load()).active!.currentRound, 5);
    p.dispose();
  });

  test('a failed write keeps the count in memory, reports it and is retried by the next change', () async {
    final store = MemoryRoundCounterStore()..failWrites = true;
    final p = RoundCounterPersister(store);
    final c = _counter();
    c.setRound(3);
    p.save(c);
    await p.flush();
    expect(p.lastError.value, isNotNull);
    expect(c.active!.currentRound, 3);
    expect(store.writes, isEmpty);

    store.failWrites = false;
    await p.flush(); // flush itself retries what is still pending
    expect(p.lastError.value, isNull);
    expect((await p.load()).active!.currentRound, 3);
    p.dispose();
  });

  test('a change that arrives while a write is running is written right after it', () async {
    final store = MemoryRoundCounterStore();
    final p = RoundCounterPersister(store);
    final c = _counter();
    c.setRound(2);
    p.save(c);
    await Future<void>.value();
    await Future<void>.value();
    c.setRound(6);
    p.save(c);
    await p.flush();
    expect((await p.load()).active!.currentRound, 6);
    p.dispose();
  });
}
