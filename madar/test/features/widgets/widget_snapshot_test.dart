import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart' show BudgetPeriod;
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/widgets/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(MadarTimeZones.ensure);

  final t0 = DateTime(2026, 9, 30, 10);
  WidgetSnapshot snapshot({List<WidgetPage>? pages}) => WidgetSnapshot(
    kind: MadarWidgetKind.meds,
    languageCode: 'ar',
    private: false,
    title: 'أدوية اليوم',
    until: DateTime(2026, 10, 2),
    stale: 'افتح مدار',
    link: WidgetLinks.meds,
    pages:
        pages ??
        [
          const WidgetPage(
            from: null,
            headline: '١/٢',
            rows: [
              WidgetRow(text: 'أ', time: '٨:٠٠ ص', state: WidgetRowState.done, link: '/meds'),
              WidgetRow(text: 'ب', time: '٨:٠٠ م'),
            ],
            more: ['و١ أخرى'],
          ),
          WidgetPage(from: DateTime(2026, 10, 1), empty: 'لا جرعات'),
        ],
  );

  group('WidgetSnapshot', () {
    test('round-trips through the JSON Android reads', () {
      final s = snapshot();
      final back = WidgetSnapshot.decode(s.encode())!;
      expect(back.kind, MadarWidgetKind.meds);
      expect(back.rtl, isTrue);
      expect(back.until, s.until);
      expect(back.pages, hasLength(2));
      expect(back.pages.first.from, isNull);
      expect(back.pages.first.rows, s.pages.first.rows);
      expect(back.pages.first.more, ['و١ أخرى']);
      expect(back.pages.last.from, DateTime(2026, 10, 1));
      expect(back.encode(), s.encode());
    });

    test('uses the compact keys and leaves out what is absent', () {
      final j = jsonDecode(snapshot().encode()) as Map<String, Object?>;
      expect(j['v'], WidgetSnapshot.version);
      expect(j['kind'], 'meds');
      expect(j['lang'], 'ar');
      expect(j['rtl'], true);
      expect(j['until'], DateTime(2026, 10, 2).millisecondsSinceEpoch);
      final pages = (j['pages'] as List).cast<Map<String, Object?>>();
      expect(pages.first.containsKey('from'), isFalse);
      expect(pages.first['big'], '١/٢');
      expect(pages.first.containsKey('sub'), isFalse);
      expect((pages.first['rows'] as List).first, {'text': 'أ', 'time': '٨:٠٠ ص', 'st': 'd', 'link': '/meds'});
      expect((pages.first['rows'] as List).last, {'text': 'ب', 'time': '٨:٠٠ م', 'st': 'o'});
      expect(pages.last['from'], DateTime(2026, 10, 1).millisecondsSinceEpoch);
      expect(pages.last.containsKey('warn'), isFalse);
    });

    test('holds nothing volatile: the same content encodes identically', () {
      expect(snapshot().encode(), snapshot().encode());
    });

    test('records the phone\'s UTC offsets, so Android can tell the time zone changed', () {
      // Dose times, midnights and the budget's days are wall-clock texts of
      // the zone the app built them in: once the phone's zone gives another
      // offset for these instants, Android shows "Open Madar to refresh"
      // (MadarWidgetRenderer.Doc.zoneMatches) instead of wrong times.
      int phoneOffset(DateTime at) =>
          DateTime.fromMillisecondsSinceEpoch(at.millisecondsSinceEpoch).timeZoneOffset.inMinutes;
      final j = jsonDecode(snapshot().encode()) as Map<String, Object?>;
      expect(j['untilOff'], phoneOffset(DateTime(2026, 10, 2)));
      final pages = (j['pages'] as List).cast<Map<String, Object?>>();
      expect(pages.first.containsKey('off'), isFalse, reason: 'the first page has no start');
      expect(pages.last['off'], phoneOffset(DateTime(2026, 10, 1)));
      // A prayer time is a TZDateTime of the location's zone: still the
      // phone's offset at that instant (what Android's TimeZone.getDefault() gives).
      final kiritimati = tz.TZDateTime(tz.getLocation('Pacific/Kiritimati'), 2026, 10, 1, 5);
      expect(kiritimati.timeZoneOffset.inMinutes, 14 * 60);
      final page = WidgetPage(from: kiritimati).toJson();
      expect(page['off'], phoneOffset(kiritimati));
    });

    test('keeps the offsets of the zone it was built in, however late it is written', () {
      // Built at UTC+3 (the dose times are UTC+3 wall-clock texts), written
      // after the phone moved to UTC+1 (the bridge rewrites a cached build
      // when a widget is added while the app is in the background): the
      // JSON must still say UTC+3, so Android refuses the stale times.
      final saved = widgetPhoneOffsetOf;
      addTearDown(() => widgetPhoneOffsetOf = saved);
      widgetPhoneOffsetOf = (_) => 180;
      final s = snapshot();
      widgetPhoneOffsetOf = (_) => 60;
      final j = jsonDecode(s.encode()) as Map<String, Object?>;
      expect(j['untilOff'], 180);
      final pages = (j['pages'] as List).cast<Map<String, Object?>>();
      expect(pages.first.containsKey('off'), isFalse);
      expect(pages.last['off'], 180);
      // A snapshot made in the new zone says so.
      expect(jsonDecode(snapshot().encode())['untilOff'], 60);
    });

    test('picks the last started page, like the Android provider', () {
      final s = snapshot();
      expect(s.pageAt(t0)!.headline, '١/٢');
      expect(s.pageAt(DateTime(2026, 10, 1))!.empty, 'لا جرعات');
      expect(s.pageAt(DateTime(2026, 10, 1, 23, 59))!.empty, 'لا جرعات');
      expect(s.pageAt(DateTime(2026, 10, 2)), isNull, reason: 'stale after until');
      expect(s.nextChangeAfter(t0), DateTime(2026, 10, 1));
      expect(s.nextChangeAfter(DateTime(2026, 10, 1, 5)), DateTime(2026, 10, 2));
    });

    test('rejects other versions and garbage', () {
      expect(WidgetSnapshot.decode('{"v":2,"kind":"meds"}'), isNull);
      expect(WidgetSnapshot.decode('not json'), isNull);
      expect(WidgetSnapshot.decode('{"v":1,"kind":"weather","until":0}'), isNull);
    });
  });

  group('WidgetPrefs', () {
    test('details are hidden by default while the app lock is on, shown when it is off', () {
      const p = WidgetPrefs();
      for (final k in MadarWidgetKind.values) {
        expect(p.showsDetails(k, appLockOn: true), isFalse);
        expect(p.showsDetails(k, appLockOn: false), isTrue);
      }
    });

    test('an explicit choice wins over the default, and can be reset', () {
      final p = const WidgetPrefs().withDetails(MadarWidgetKind.meds, true).withDetails(MadarWidgetKind.budget, false);
      expect(p.showsDetails(MadarWidgetKind.meds, appLockOn: true), isTrue);
      expect(p.showsDetails(MadarWidgetKind.budget, appLockOn: false), isFalse);
      expect(p.withDetails(MadarWidgetKind.meds, null).showsDetails(MadarWidgetKind.meds, appLockOn: true), isFalse);
    });

    test('round-trips through JSON and ignores unknown kinds', () {
      final p = const WidgetPrefs()
          .withDetails(MadarWidgetKind.tasks, true)
          .withBudgetPeriod(BudgetPeriod.weekly);
      expect(WidgetPrefs.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, Object?>), p);
      final odd = WidgetPrefs.fromJson({
        'details': {'weather': true, 'prayer': 'yes', 'meds': false},
        'budgetPeriod': 'daily',
      });
      expect(odd.details, {MadarWidgetKind.meds: false});
      expect(odd.budgetPeriod, BudgetPeriod.monthly);
    });
  });

  group('WidgetLinks', () {
    test('lets through the pages a widget opens', () {
      expect(WidgetLinks.isAllowed(WidgetLinks.prayer), isTrue);
      expect(WidgetLinks.isAllowed(WidgetLinks.meds), isTrue);
      expect(WidgetLinks.isAllowed(WidgetLinks.budget), isTrue);
      expect(WidgetLinks.isAllowed(WidgetLinks.tasks), isTrue);
      expect(WidgetLinks.isAllowed(WidgetLinks.task('7f3c-11')), isTrue);
      expect(WidgetLinks.isAllowed(WidgetLinks.card('c1', boardId: 'b-9')), isTrue);
      expect(WidgetLinks.card('c1'), WidgetLinks.tasks);
    });

    test('refuses anything else a forged intent could carry', () {
      for (final bad in [
        null,
        '',
        '/settings/security',
        '/import',
        'https://evil.example/meds',
        '//evil.example/meds',
        '/planet/money?item=wallets:1',
        '/planet/work?item=people:1',
        '/planet/work?item=tasks:1&x=2',
        '/planet/work?item=tasks:1%2F..%2F',
        '/meds?tab=meds&x=1',
        '/planet/work?item=${'a' * 300}',
      ]) {
        expect(WidgetLinks.isAllowed(bad), isFalse, reason: '$bad');
      }
    });
  });

  test('state dots: filled for done, open for the rest, none when too many', () {
    expect(WidgetTexts.dots(2, 3), '● ● ○');
    expect(WidgetTexts.dots(0, 1), '○');
    expect(WidgetTexts.dots(5, 3), '● ● ●');
    expect(WidgetTexts.dots(0, 0), isNull);
    expect(WidgetTexts.dots(1, WidgetTexts.maxDots + 1), isNull);
  });
}
