import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart' show BudgetPeriod;
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/features/widgets/widgets.dart';

void main() {
  final ar = WidgetTexts.forLanguage('ar');
  final en = WidgetTexts.forLanguage('en');

  group('Top 3', () {
    final now = DateTime(2026, 9, 30, 16, 20);
    final items = [
      WidgetTask(title: 'Call the bank', done: true, link: WidgetLinks.task('t1')),
      WidgetTask(title: 'إنهاء التقرير', link: WidgetLinks.card('c2', boardId: 'b1')),
      WidgetTask(title: 'زيارة الجدة', link: WidgetLinks.task('t3')),
    ];

    test('details: done of total and each item with its check and link', () {
      final s = TasksWidgetBuilder.build(now: now, items: items, texts: ar, details: true);
      final p = s.pages.first;
      expect(s.kind, MadarWidgetKind.tasks);
      expect(p.headline, '١/٣');
      expect(p.detail, ar.digits(ar.l.widgetsTasksLeft(2)));
      expect([for (final r in p.rows) r.state], [WidgetRowState.done, WidgetRowState.open, WidgetRowState.open]);
      expect(p.rows.first.text, ar.name('Call the bank'));
      expect(Uri.parse(p.rows.first.link!).path, '/planet/work');
      expect(Uri.parse(p.rows.first.link!).queryParameters, {'item': 'tasks:t1'});
      expect(Uri.parse(p.rows[1].link!).queryParameters, {'item': 'boards:b1'});
      for (final r in p.rows) {
        expect(WidgetLinks.isAllowed(r.link), isTrue, reason: r.link);
      }
    });

    test('counts only: no titles in the JSON', () {
      final s = TasksWidgetBuilder.build(now: now, items: items, texts: ar, details: false);
      expect(s.encode(), isNot(contains('bank')));
      expect(s.encode(), isNot(contains('التقرير')));
      expect(s.pages.first.note, '● ○ ○');
      expect(s.pages.first.rows, isEmpty);
    });

    test('midnight rollover: the next page asks for a new Top 3 and counts what is carried', () {
      final s = TasksWidgetBuilder.build(now: now, items: items, texts: en, details: true);
      final next = s.pageAt(DateTime(2026, 10, 1, 0, 1))!;
      expect(s.pages[1].from, DateTime(2026, 10, 1));
      expect(next.empty, en.l.widgetsTasksEmpty);
      expect(next.note, en.l.widgetsTasksCarried(2));
      expect(next.rows, isEmpty);
      expect(s.until, DateTime(2026, 10, 2));
    });

    test('nothing chosen yet (and yesterday\'s waiting to be carried over)', () {
      final s = TasksWidgetBuilder.build(now: now, items: const [], carriedOver: 1, texts: en, details: true);
      expect(s.pages.first.empty, en.l.widgetsTasksEmpty);
      expect(s.pages.first.note, en.l.widgetsTasksCarried(1));
      final none = TasksWidgetBuilder.build(now: now, items: const [], texts: en, details: false);
      expect(none.pages.first.note, isNull);
    });

    test('all done', () {
      final done = [for (final i in items) WidgetTask(title: i.title, done: true, link: i.link)];
      final s = TasksWidgetBuilder.build(now: now, items: done, texts: en, details: true);
      expect(s.pages.first.headline, '3/3');
      expect(s.pages.first.detail, en.l.widgetsTasksAllDone);
    });
  });

  group('Budget', () {
    final now = DateTime(2026, 9, 18, 9);
    WidgetBudget month({int planned = 450000, int spent = 267500}) => WidgetBudget(
      period: BudgetPeriod.monthly,
      start: DateTime(2026, 9),
      end: DateTime(2026, 10),
      plannedMilli: planned,
      spentMilli: spent,
    );
    String money(int milli) => 'JOD ${(milli / 1000).toStringAsFixed(3)}';

    test('details: the amount left, the plan, the days and a bar of what is left', () {
      final s = BudgetWidgetBuilder.build(now: now, budget: month(), money: money, texts: en, details: true);
      final p = s.pages.first;
      expect(s.kind, MadarWidgetKind.budget);
      expect(s.link, '/budget?tab=spending');
      expect(p.headline, 'JOD 182.500');
      expect(p.detail, en.l.widgetsBudgetOf('JOD 450.000'));
      expect(p.note, en.l.widgetsBudgetDaysLeft(12));
      expect(p.bar, 406);
      expect(p.warn, isFalse);
    });

    test('counts only: the percentage and the bar, no amount anywhere', () {
      final s = BudgetWidgetBuilder.build(now: now, budget: month(), money: money, texts: ar, details: false);
      expect(s.encode(), isNot(contains('JOD')));
      expect(s.encode(), isNot(contains('182')));
      final p = s.pages.first;
      expect(p.headline, '٤١٪');
      expect(p.detail, ar.l.widgetsBudgetLeftMonth);
      expect(p.bar, 406);
      expect(p.note, ar.digits(ar.l.widgetsBudgetDaysLeft(12)));
      expect(Digits.hasEasternDigits(p.note!), isTrue);
    });

    test('over budget warns: "over by" with details, 0% without', () {
      final over = month(spent: 500000);
      final shown = BudgetWidgetBuilder.build(now: now, budget: over, money: money, texts: en, details: true);
      expect(shown.pages.first.headline, en.l.widgetsBudgetOverBy('JOD 50.000'));
      expect(shown.pages.first.warn, isTrue);
      expect(shown.pages.first.bar, 0);
      final hidden = BudgetWidgetBuilder.build(now: now, budget: over, money: money, texts: en, details: false);
      expect(hidden.pages.first.headline, '0%');
      expect(hidden.pages.first.detail, en.l.widgetsBudgetOver);
      final near = BudgetWidgetBuilder.build(now: now, budget: month(spent: 400000), money: money, texts: en, details: true);
      expect(near.pages.first.warn, isTrue, reason: '≥ 85 % spent');
    });

    test('a page per day for a week (the days left turn at midnight)', () {
      final s = BudgetWidgetBuilder.build(now: now, budget: month(), money: money, texts: en, details: true);
      expect(s.pages, hasLength(BudgetWidgetBuilder.horizonDays));
      expect(s.pages[1].from, DateTime(2026, 9, 19));
      expect(s.pageAt(DateTime(2026, 9, 19, 0, 1))!.note, en.l.widgetsBudgetDaysLeft(11));
      expect(s.until, DateTime(2026, 9, 25));
    });

    test('month end: the next month starts with its whole plan, then the data runs out', () {
      final late = DateTime(2026, 9, 29, 20);
      final s = BudgetWidgetBuilder.build(now: late, budget: month(), money: money, texts: en, details: true);
      expect(s.pages.map((p) => p.from), [null, DateTime(2026, 9, 30), DateTime(2026, 10)]);
      final october = s.pageAt(DateTime(2026, 10, 1, 7))!;
      expect(october.headline, 'JOD 450.000');
      expect(october.bar, 1000);
      expect(october.note, en.l.widgetsBudgetDaysLeft(30));
      expect(s.pageAt(DateTime(2026, 9, 30, 12))!.note, en.l.widgetsBudgetDaysLeft(0));
      expect(s.until, DateTime(2026, 10, 2));
    });

    test('weekly period: its own "left this week"', () {
      final week = WidgetBudget(
        period: BudgetPeriod.weekly,
        start: DateTime(2026, 9, 12),
        end: DateTime(2026, 9, 19),
        plannedMilli: 100000,
        spentMilli: 25000,
      );
      final s = BudgetWidgetBuilder.build(now: now, budget: week, money: money, texts: en, details: false);
      expect(s.pages.first.headline, '75%');
      expect(s.pages.first.detail, en.l.widgetsBudgetLeftWeek);
      final next = s.pageAt(DateTime(2026, 9, 19, 8))!;
      expect(next.headline, '100%');
      expect(next.note, en.l.widgetsBudgetDaysLeft(6));
    });

    test('nothing planned: set up the budget', () {
      final s = BudgetWidgetBuilder.build(now: now, budget: month(planned: 0, spent: 3000), money: money, texts: ar, details: true);
      expect(s.pages.first.empty, ar.l.widgetsBudgetNone);
      expect(s.pages.first.bar, isNull);
    });
  });
}
