import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/features/widgets/widgets.dart';

void main() {
  final ar = WidgetTexts.forLanguage('ar');
  final en = WidgetTexts.forLanguage('en');
  final now = DateTime(2026, 9, 30, 13, 5);

  List<WidgetDose> today() => [
    WidgetDose(name: 'Metformin', dose: '500 mg', at: DateTime(2026, 9, 30, 8), state: WidgetRowState.done),
    WidgetDose(name: 'فيتامين د', at: DateTime(2026, 9, 30, 9), state: WidgetRowState.skipped),
    WidgetDose(name: 'Metformin', dose: '500 mg', at: DateTime(2026, 9, 30, 20)),
    WidgetDose(name: 'أوميغا ٣', at: DateTime(2026, 9, 30, 14)),
  ];
  List<WidgetDose> tomorrow() => [
    WidgetDose(name: 'Metformin', dose: '500 mg', at: DateTime(2026, 10, 1, 8)),
    WidgetDose(name: 'Metformin', dose: '500 mg', at: DateTime(2026, 10, 1, 20)),
  ];

  WidgetSnapshot build({WidgetTexts? texts, bool details = true, List<WidgetDose>? t, List<WidgetDose>? tm, bool hasMeds = true}) =>
      MedsWidgetBuilder.build(
        now: now,
        today: t ?? today(),
        tomorrow: tm ?? tomorrow(),
        hasMeds: hasMeds,
        texts: texts ?? ar,
        details: details,
      );

  test('details: answered of total, the next open dose, a row per dose in time order', () {
    final s = build();
    final p = s.pages.first;
    expect(s.kind, MadarWidgetKind.meds);
    expect(s.link, WidgetLinks.meds);
    expect(p.headline, '٢/٤');
    expect(p.detail, ar.l.widgetsMedsNext(ar.fmt.formatTime(DateTime(2026, 9, 30, 14)), ar.name('أوميغا ٣')));
    expect([for (final r in p.rows) r.state], [
      WidgetRowState.done,
      WidgetRowState.skipped,
      WidgetRowState.open,
      WidgetRowState.open,
    ]);
    expect(p.rows.first.text, '${ar.name('Metformin')} · 500 mg');
    expect(p.rows.first.time, ar.fmt.formatTime(DateTime(2026, 9, 30, 8)));
    expect(p.rows.first.time, contains('٨'));
    expect(p.rows[2].text, ar.name('أوميغا ٣'), reason: 'sorted by time');
    expect(p.rows.every((r) => r.link == WidgetLinks.meds), isTrue);
    expect(p.more, hasLength(3), reason: 'one line per number of hidden rows');
    expect(p.more.first, ar.digits(ar.l.widgetsMore(1)));
  });

  test('counts only: no names, no times, nothing personal in the JSON', () {
    final s = build(details: false);
    final json = s.encode();
    for (final secret in ['Metformin', 'فيتامين', 'أوميغا', '500', '٨:٠٠']) {
      expect(json, isNot(contains(secret)), reason: secret);
    }
    final p = s.pages.first;
    expect(s.private, isTrue);
    expect(p.rows, isEmpty);
    expect(p.headline, '٢/٤');
    expect(p.detail, ar.digits(ar.l.widgetsMedsPending(2)));
    expect(p.note, '● ● ○ ○');
  });

  test('midnight rollover: tomorrow\'s doses from midnight, stale the day after', () {
    final s = build();
    expect(s.pages, hasLength(2));
    expect(s.pages[1].from, DateTime(2026, 10, 1));
    expect(s.until, DateTime(2026, 10, 2));
    final atMidnight = s.pageAt(DateTime(2026, 10, 1, 0, 0, 1))!;
    expect(atMidnight.headline, '٠/٢');
    expect(atMidnight.rows, hasLength(2));
    expect(s.pageAt(DateTime(2026, 9, 30, 23, 59))!.headline, '٢/٤');
    expect(s.pageAt(DateTime(2026, 10, 2)), isNull);
  });

  test('all answered, nothing today, no medications at all', () {
    final done = [
      for (final d in today()) WidgetDose(name: d.name, dose: d.dose, at: d.at, state: WidgetRowState.done),
    ];
    expect(build(t: done).pages.first.detail, ar.l.widgetsMedsAllDone);
    expect(build(t: const []).pages.first.empty, ar.l.widgetsMedsNoneToday);
    expect(build(t: const [], tm: const [], hasMeds: false).pages.first.empty, ar.l.widgetsMedsSetUp);
    expect(build(t: const []).pages.first.headline, isNull);
  });

  test('English: Western digits and English texts', () {
    final s = build(texts: en);
    expect(s.rtl, isFalse);
    expect(s.pages.first.headline, '2/4');
    expect(s.pages.first.rows.first.time, '8:00 AM');
    expect(s.pages.first.detail, startsWith('Next at 2:00'));
    expect(Digits.hasEasternDigits(s.pages.first.detail!), isFalse);
  });

  test('a long day is cut at the row limit and the "more" lines count every dose', () {
    final many = [for (var h = 6; h < 18; h++) WidgetDose(name: 'Dose $h', at: DateTime(2026, 9, 30, h))];
    final p = build(t: many, texts: en).pages.first;
    expect(p.rows, hasLength(MedsWidgetBuilder.maxRows));
    expect(p.more, hasLength(many.length - 1));
    // Three rows shown → nine hidden.
    expect(p.more[many.length - 3 - 1], en.l.widgetsMore(9));
  });
}
