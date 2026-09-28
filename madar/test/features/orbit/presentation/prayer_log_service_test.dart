import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/presentation/prayer/prayer_log_service.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  var now = DateTime(2026, 9, 27, 18, 40);
  final day = DateTime(2026, 9, 27);

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    now = DateTime(2026, 9, 27, 18, 40);
  });
  tearDown(() => db.close());

  PrayerLogService service() => PrayerLogService(repos, clock: () => now);
  Future<List<ActivityRow>> completions() => repos.activity.since(DateTime(2026), kind: PrayerLogService.kind);

  test('logging a prayer writes one row and one Faith completion; undo removes both', () async {
    final undo = await service().log(day, Prayer.maghrib, PrayerStatus.prayed);
    final row = await service().logOf(day, Prayer.maghrib);
    expect(row?.status, PrayerStatus.prayed);
    expect(row?.loggedAt, now);
    final done = await completions();
    expect(done.single.refId, row!.id);
    expect(done.single.planetKey, PrayerLogService.planetKey);

    await undo();
    expect(await service().logOf(day, Prayer.maghrib), isNull);
    expect(await completions(), isEmpty);
  });

  test('re-logging replaces the earlier log; its undo restores the earlier log and completion exactly', () async {
    await service().log(day, Prayer.asr, PrayerStatus.prayed);
    final first = (await service().logOf(day, Prayer.asr))!;
    final firstActivity = (await completions()).single;

    now = now.add(const Duration(minutes: 30));
    final undo = await service().log(day, Prayer.asr, PrayerStatus.late);
    final second = (await service().logOf(day, Prayer.asr))!;
    expect(second.status, PrayerStatus.late);
    expect(await repos.prayerLogs.getAll(), hasLength(1), reason: 'one row per prayer day and prayer');
    expect((await completions()).single.refId, second.id);

    await undo();
    final back = (await service().logOf(day, Prayer.asr))!;
    expect((back.id, back.status, back.loggedAt), (first.id, first.status, first.loggedAt));
    final activity = (await completions()).single;
    expect((activity.id, activity.refId, activity.at), (firstActivity.id, first.id, firstActivity.at));
  });

  test('a missed prayer is logged without a completion; clear() undoes exactly', () async {
    await service().log(day, Prayer.fajr, PrayerStatus.missed);
    expect((await service().logOf(day, Prayer.fajr))?.status, PrayerStatus.missed);
    expect(await completions(), isEmpty);

    await service().log(day, Prayer.dhuhr, PrayerStatus.prayed);
    final dhuhr = (await service().logOf(day, Prayer.dhuhr))!;
    final undo = await service().clear(day, Prayer.dhuhr);
    expect(await service().logOf(day, Prayer.dhuhr), isNull);
    expect(await completions(), isEmpty);
    await undo();
    expect((await service().logOf(day, Prayer.dhuhr))?.id, dhuhr.id);
    expect((await completions()).single.refId, dhuhr.id);
  });

  test('only a believable log time is shown (imports carry the time they were written)', () {
    final maghrib = DateTime(2026, 9, 27, 18, 31);
    expect(PrayerLogService.plausibleLoggedAt(DateTime(2026, 9, 27, 18, 40), maghrib), DateTime(2026, 9, 27, 18, 40));
    expect(PrayerLogService.plausibleLoggedAt(DateTime(2026, 9, 28, 1, 5), maghrib), DateTime(2026, 9, 28, 1, 5));
    expect(
      PrayerLogService.plausibleLoggedAt(DateTime(2026, 9, 27, 7, 30), maghrib),
      isNull,
      reason: 'before its time',
    );
    expect(PrayerLogService.plausibleLoggedAt(DateTime(2026, 10, 2, 9), maghrib), isNull, reason: 'days later');
    expect(PrayerLogService.plausibleLoggedAt(null, maghrib), isNull);
  });
}
