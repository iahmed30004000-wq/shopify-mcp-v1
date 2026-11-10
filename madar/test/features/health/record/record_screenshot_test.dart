@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/health/record/record.dart';

import '../../../helpers/screenshot_harness.dart';
import 'record_harness.dart';

const _dir = 'phase4/record';
final _ar = lookupL10n(const Locale('ar'));

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Opens the lab test called [name] once the tests have loaded.
class LabTestByName extends ConsumerWidget {
  const LabTestByName(this.name, {super.key});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tests = ref.watch(labTestsProvider).value ?? const <LabTestRow>[];
    final t = tests.where((t) => t.name == name).firstOrNull;
    if (t == null) return const SizedBox.shrink();
    return LabTestScreen(testId: t.id);
  }
}

/// The hub cards the Health hub will show.
class HubPreview extends StatelessWidget {
  const HubPreview({super.key});

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: _Title.of(context),
    body: ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xl),
      children: const [
        HealthAlertsBanner(maxVisible: 2, padding: EdgeInsets.only(bottom: Space.s)),
        NextAppointmentCard(),
        SizedBox(height: Space.m),
        LabFlagsCard(),
      ],
    ),
  );
}

abstract final class _Title {
  static String of(BuildContext context) => L10n.of(context).recordReminderGroup;
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    bool seed = true,
    Future<void> Function(MadarDatabase db)? beforePump,
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    final (app, _) = await buildRecordApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      seed: seed,
      beforePump: beforePump,
    );
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      beforeCapture: (tester) async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (beforeCapture != null) await beforeCapture(tester);
      },
    );
  }

  group('record screen', () {
    testWidgets('labs – Arabic, Lapis', (tester) async {
      await shot(tester, 'record_labs_ar_lapis', const RecordScreen());
    });
    testWidgets('labs – English, Pearl', (tester) async {
      await shot(
        tester,
        'record_labs_en_pearl',
        const RecordScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });
    testWidgets('labs scrolled – Arabic, Pearl', (tester) async {
      await shot(
        tester,
        'record_labs_scrolled_ar_pearl',
        const RecordScreen(),
        theme: MadarThemeId.pearl,
        beforeCapture: (tester) => tester.drag(find.byType(ListView).first, const Offset(0, -520)),
      );
    });
    testWidgets('appointments – Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'record_appointments_ar_emerald',
        const RecordScreen(initialTab: RecordTab.appointments),
        theme: MadarThemeId.emerald,
      );
    });
    testWidgets('appointments – English, Pearl', (tester) async {
      await shot(
        tester,
        'record_appointments_en_pearl',
        const RecordScreen(initialTab: RecordTab.appointments),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });
    testWidgets('questions – Arabic, Lapis', (tester) async {
      await shot(tester, 'record_questions_ar_lapis', const RecordScreen(initialTab: RecordTab.questions));
    });
    testWidgets('conditions – English, Aurora', (tester) async {
      await shot(
        tester,
        'record_conditions_en_aurora',
        const RecordScreen(initialTab: RecordTab.conditions),
        theme: MadarThemeId.aurora,
        locale: const Locale('en'),
      );
    });
    testWidgets('empty – Arabic, Lapis', (tester) async {
      await shot(tester, 'record_empty_ar_lapis', const RecordScreen(), seed: false);
    });
  });

  group('lab test', () {
    testWidgets('TSH chart – Arabic, Lapis', (tester) async {
      await shot(tester, 'lab_tsh_ar_lapis', const LabTestByName('TSH'));
    });
    testWidgets('TSH chart – English, Pearl', (tester) async {
      await shot(
        tester,
        'lab_tsh_en_pearl',
        const LabTestByName('TSH'),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });
    testWidgets('vitamin D, all – Arabic, Desert', (tester) async {
      await shot(
        tester,
        'lab_vitd_ar_desert',
        const LabTestByName('فيتامين د'),
        theme: MadarThemeId.desert,
        beforeCapture: (tester) async {
          await tester.tap(find.text(_ar.recordPeriodAll));
          await _frames(tester);
        },
      );
    });
  });

  group('sheets', () {
    testWidgets('lab visit – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'lab_visit_ar_lapis',
        const RecordScreen(),
        beforeCapture: (tester) async {
          await tester.tap(find.text(_ar.recordLabVisit).first);
          await _frames(tester, 20);
          final fields = find.byType(TextField);
          await tester.enterText(fields.at(0), '4.6');
          await tester.enterText(fields.at(1), '1.2');
          await tester.enterText(fields.at(2), '27');
          await _frames(tester, 10);
          FocusManager.instance.primaryFocus?.unfocus();
          await _frames(tester, 10);
        },
      );
    });
    testWidgets('doctor report – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'report_sheet_ar_lapis',
        const RecordScreen(),
        beforeCapture: (tester) async {
          await tester.tap(find.bySemanticsLabel(_ar.recordDoctorReport).first);
          await _frames(tester, 20);
        },
      );
    });
    testWidgets('doctor report – English, Pearl', (tester) async {
      await shot(
        tester,
        'report_sheet_en_pearl',
        const RecordScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforeCapture: (tester) async {
          await tester.tap(find.bySemanticsLabel(lookupL10n(const Locale('en')).recordDoctorReport).first);
          await _frames(tester, 20);
        },
      );
    });
  });

  group('alerts + settings', () {
    testWidgets('alerts manager – Arabic, Pearl', (tester) async {
      await shot(
        tester,
        'alerts_manager_ar_pearl',
        const RecordScreen(),
        theme: MadarThemeId.pearl,
        beforeCapture: (tester) async {
          await tester.tap(find.text(_ar.recordAlertsManage).first);
          await _frames(tester, 20);
        },
      );
    });
    testWidgets('record settings – Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'record_settings_ar_lapis',
        const RecordScreen(),
        beforeCapture: (tester) async {
          await tester.tap(find.bySemanticsLabel(_ar.recordSettingsTitle).first);
          await _frames(tester, 20);
        },
      );
    });
  });

  group('appointments + hub', () {
    testWidgets('appointments screen – Arabic, Lapis', (tester) async {
      await shot(tester, 'appointments_ar_lapis', const AppointmentsScreen());
    });
    testWidgets('hub cards – Arabic, Lapis', (tester) async {
      await shot(tester, 'hub_cards_ar_lapis', const HubPreview());
    });
    testWidgets('hub cards – English, Aurora', (tester) async {
      await shot(
        tester,
        'hub_cards_en_aurora',
        const HubPreview(),
        theme: MadarThemeId.aurora,
        locale: const Locale('en'),
      );
    });
    testWidgets('hub cards – English, Pearl', (tester) async {
      await shot(
        tester,
        'hub_cards_en_pearl',
        const HubPreview(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });
  });
}
