import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/interaction/sheets/reminder_sheet.dart';
import 'package:madar/core/sound/sound_api.dart';

import '../interaction_test_utils.dart';

final _now = DateTime(2026, 9, 27, 14, 20); // Sunday afternoon

class _Host extends StatefulWidget {
  const _Host({this.initial, this.dueDate, this.allowPrayerRelative = true, this.allowRemove = false});

  final Map<String, Object?>? initial;
  final DateTime? dueDate;
  final bool allowPrayerRelative;
  final bool allowRemove;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Map<String, Object?>? result;
  bool closed = false;

  @override
  Widget build(BuildContext context) => Center(
    child: ElevatedButton(
      onPressed: () async {
        final r = await showReminderSheet(
          context,
          initial: widget.initial,
          dueDate: widget.dueDate,
          allowPrayerRelative: widget.allowPrayerRelative,
          allowRemove: widget.allowRemove,
          now: _now,
        );
        setState(() {
          result = r;
          closed = true;
        });
      },
      child: const Text('open'),
    ),
  );
}

Future<_HostState> _open(
  WidgetTester tester, {
  Map<String, Object?>? initial,
  DateTime? dueDate,
  bool allowPrayerRelative = true,
  bool allowRemove = false,
  Locale locale = const Locale('ar'),
}) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(
    interactionApp(
      _Host(initial: initial, dueDate: dueDate, allowPrayerRelative: allowPrayerRelative, allowRemove: allowRemove),
      locale: locale,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return tester.state<_HostState>(find.byType(_Host));
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, {String label = 'حفظ'}) => _tap(tester, find.text(label));

void main() {
  late List<Sfx> played;
  setUp(() => played = installInteractionFx().sound.played);

  testWidgets('defaults to a one-off reminder at the next hour', (tester) async {
    final host = await _open(tester);
    expect(played, contains(Sfx.sheetOpen));
    expect(find.text('متى أذكّرك؟'), findsOneWidget);
    expect(find.textContaining('اليوم'), findsWidgets);
    await _save(tester);
    expect(host.result, {'kind': 'once', 'at': '2026-09-27T15:00:00'});
    expect(played, contains(Sfx.complete));
  });

  testWidgets('daily', (tester) async {
    final host = await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('kind-daily')));
    await _save(tester);
    expect(host.result, {'kind': 'daily', 'time': '15:00'});
  });

  testWidgets('weekly: workdays preset, and no days blocks saving', (tester) async {
    final host = await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('kind-weekly')));
    await _tap(tester, find.text('أيام الدوام'));
    await _save(tester);
    expect(host.result, {
      'kind': 'weekly',
      'time': '15:00',
      'weekdays': [1, 2, 3, 4, 7],
    });
  });

  testWidgets('weekly without days shows an error on save', (tester) async {
    final host = await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('kind-weekly')));
    // Today (Sunday) is preselected; deselect it.
    await _tap(tester, find.byKey(const ValueKey('day-7')));
    expect(find.text('اختر يومًا واحدًا على الأقل'), findsNothing);
    await _save(tester);
    expect(host.closed, isFalse);
    expect(played, contains(Sfx.error));
    expect(find.text('اختر يومًا واحدًا على الأقل'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('day-5')));
    await _save(tester);
    expect(host.result!['weekdays'], [5]);
  });

  testWidgets('prayer-relative: 15 minutes before Maghrib', (tester) async {
    final host = await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('kind-prayer')));
    await _tap(tester, find.text('المغرب'));
    await _tap(tester, find.byKey(const ValueKey('rel-before')));
    await _tap(tester, find.byKey(const ValueKey('offset-15')));
    expect(find.text('قبل المغرب بـ١٥ دقيقة'), findsOneWidget);
    expect(find.text('١٥ دقيقة'), findsOneWidget);
    await _save(tester);
    expect(host.result, {'kind': 'prayer', 'window': 'maghrib', 'offsetMin': -15});
  });

  testWidgets('prayer-relative "on time" hides the minutes', (tester) async {
    final host = await _open(tester);
    await _tap(tester, find.byKey(const ValueKey('kind-prayer')));
    await _tap(tester, find.byKey(const ValueKey('rel-at')));
    expect(find.byKey(const ValueKey('offset-15')), findsNothing);
    await _save(tester);
    expect(host.result, {'kind': 'prayer', 'window': 'asr', 'offsetMin': 0});
  });

  testWidgets('prayer option can be turned off', (tester) async {
    await _open(tester, allowPrayerRelative: false);
    expect(find.byKey(const ValueKey('kind-prayer')), findsNothing);
    expect(find.byKey(const ValueKey('kind-beforeDue')), findsNothing);
  });

  testWidgets('with a due date, "before due" is the default', (tester) async {
    final host = await _open(tester, dueDate: DateTime(2026, 10, 2));
    expect(find.byKey(const ValueKey('kind-beforeDue')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('lead-60')));
    expect(find.text('قبل ساعة'), findsOneWidget);
    await _save(tester);
    expect(host.result, {'kind': 'beforeDue', 'minutes': 60});
  });

  testWidgets('restores an initial rule', (tester) async {
    final semantics = tester.ensureSemantics();
    final host = await _open(
      tester,
      initial: {
        'kind': 'weekly',
        'time': '07:30',
        'weekdays': [5],
      },
    );
    expect(tester.getSemantics(find.bySemanticsLabel('جمعة')), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.bySemanticsLabel('سبت')), isSemantics(isSelected: false));
    semantics.dispose();
    await _save(tester);
    expect(host.result, {
      'kind': 'weekly',
      'time': '07:30',
      'weekdays': [5],
    });
  });

  testWidgets('a past one-off time is flagged and cannot be saved', (tester) async {
    final host = await _open(tester, initial: {'kind': 'once', 'at': '2026-09-27T10:00:00'});
    expect(find.text('هذا الوقت مضى، اختر وقتًا قادمًا'), findsOneWidget);
    await _save(tester);
    expect(host.closed, isFalse);
    expect(played, contains(Sfx.error));
    // Picking tomorrow fixes it.
    await _tap(tester, find.text('غدًا'));
    await _save(tester);
    expect(host.result, {'kind': 'once', 'at': '2026-09-28T10:00:00'});
  });

  testWidgets('remove resolves with an empty map', (tester) async {
    final host = await _open(tester, initial: {'kind': 'daily', 'time': '08:00'}, allowRemove: true);
    await _tap(tester, find.text('إزالة التذكير'));
    expect(host.closed, isTrue);
    expect(host.result, isEmpty);
    expect(identical(host.result, kReminderRemoved), isTrue);
  });

  testWidgets('English, left-to-right, week starts on Sunday', (tester) async {
    final host = await _open(tester, locale: const Locale('en'));
    expect(find.text('When should I remind you?'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('kind-weekly')));
    final sun = tester.getTopLeft(find.byKey(const ValueKey('day-7')));
    final mon = tester.getTopLeft(find.byKey(const ValueKey('day-1')));
    expect(sun.dx, lessThan(mon.dx));
    await _tap(tester, find.text('Every day'));
    await _save(tester, label: 'Save');
    expect(host.result!['weekdays'], [1, 2, 3, 4, 5, 6, 7]);
  });

  testWidgets('describeReminder renders every rule kind', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      interactionApp(
        Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
        locale: const Locale('en'),
      ),
    );
    String? d(Map<String, Object?> rule) => describeReminder(ctx, rule, now: _now);
    expect(d({'kind': 'once', 'at': '2026-09-28T09:00:00'}), 'Tomorrow at 9:00 AM');
    expect(d({'kind': 'daily', 'time': '08:30'}), 'Every day at 8:30 AM');
    expect(
      d({
        'kind': 'weekly',
        'time': '18:00',
        'weekdays': [1, 7],
      }),
      'Sun, Mon at 6:00 PM',
    );
    expect(d({'kind': 'prayer', 'window': 'asr', 'offsetMin': 10}), '10 minutes after Asr');
    expect(d({'kind': 'prayer', 'window': 'fajr', 'offsetMin': -60}), '1 hour before Fajr');
    expect(d({'kind': 'prayer', 'window': 'isha', 'offsetMin': 0}), 'At Isha');
    expect(d({'kind': 'beforeDue', 'minutes': 1440}), '1 day before');
    expect(d({'kind': 'nope'}), isNull);
  });
}
