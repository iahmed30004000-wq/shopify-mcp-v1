// Phase 2 theme × language matrix of the shared sheets and toasts, opened
// through the app's real glue (home's TaskActions) over the settings page:
// the edit sheet, the move sheet, the reminder sheet and the undo toast.
//
//   flutter test --tags screenshot test/core/design/theme_matrix_sheets_screenshot_test.dart
//
// Writes screenshots/phase2/themes/{edit_sheet,move_sheet,reminder_sheet,undo_toast}_<lang>_<theme>.png.
@Tags(['screenshot'])
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/widgets/task_actions.dart';
import 'package:madar/features/settings/settings_screen.dart';

import '../../helpers/screenshot_harness.dart';
import '../../helpers/test_app.dart';
import 'theme_matrix.dart';

Future<void> _seed(MadarDatabase db, String lang) async {
  await db
      .into(db.tasks)
      .insert(
        TasksCompanion.insert(
          title: lang == 'ar' ? 'الاتصال بالوالدة بعد العصر' : 'Call Mum after Asr',
          window: const Value(PrayerWindow.asr),
          date: Value(DateTime(testNow.year, testNow.month, testNow.day)),
          planetKey: const Value('family'),
          notes: Value(lang == 'ar' ? 'اسألها عن موعد الطبيب يوم ١٢' : 'Ask about the doctor on the 12th'),
        ),
      );
}

typedef _Open = void Function(TaskActions actions, TaskRow task, BuildContext context, L10n l);

void main() {
  final sheets = <(String, _Open)>[
    ('edit_sheet', (a, task, _, _) => unawaited(a.edit(task))),
    ('move_sheet', (a, task, _, _) => unawaited(a.move(task))),
    ('reminder_sheet', (a, task, _, _) => unawaited(a.setReminder(task))),
    (
      'undo_toast',
      (_, _, context, l) => unawaited(showUndoToast(context, UndoableAction(label: l.itemDeleted, undo: () async {}))),
    ),
  ];

  for (final lang in matrixLanguages) {
    for (final theme in matrixThemes) {
      group('${lang}_${theme.name} –', () {
        for (final (name, open) in sheets) {
          testWidgets(name, (tester) async {
            late MadarDatabase db;
            final setup = await buildMadarTestApp(
              tester,
              settings: AppSettings(onboarded: true, themeId: theme, languageCode: lang),
              initialLocation: '/settings',
              beforePump: (d) async {
                db = d;
                await _seed(d, lang);
              },
            );
            final task = (await tester.runAsync(() => db.select(db.tasks).getSingle()))!;
            await captureScreen(
              tester,
              setup.app,
              matrixShot(name, lang, theme),
              beforeCapture: (tester) async {
                final element = tester.element(find.byType(SettingsScreen));
                final ref = element as WidgetRef;
                open(TaskActions(ref, element), task, element, L10n.of(element));
                for (var i = 0; i < 24; i++) {
                  await tester.pump(const Duration(milliseconds: 50));
                }
              },
            );
          });
        }
      });
    }
  }
}
