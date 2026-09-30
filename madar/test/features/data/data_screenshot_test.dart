@Tags(['screenshot'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/key_value_repository.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/features/data/data.dart';

import '../../helpers/screenshot_harness.dart';
import 'data_fixtures.dart';
import 'data_harness.dart';

const _dir = 'data';

final _header = BackupHeader(
  createdAt: DateTime.utc(2026, 9, 12, 18, 40),
  schemaVersion: 2,
  kdf: BackupKdfParams.recommended,
  salt: Uint8List(16),
  nonce: Uint8List(12),
  keyCheck: Uint8List(16),
  bodyLength: 0,
);

const _backupCounts = {
  'prayer_logs': 1240,
  'quran_sessions': 182,
  'hifz_items': 34,
  'medications': 6,
  'med_doses': 1890,
  'lab_readings': 86,
  'pain_entries': 142,
  'mood_entries': 301,
  'transactions': 2380,
  'wallets': 4,
  'budget_items': 18,
  'people': 23,
  'contact_logs': 310,
  'tasks': 412,
  'board_cards': 96,
  'learning_goals': 5,
  'goal_logs': 120,
  'workout_logs': 88,
  'water_logs': 640,
  'trips': 6,
  'travel_documents': 5,
  'custom_entries': 204,
  'key_values': 30,
  'activity_log': 3100,
};

const _currentCounts = {'tasks': 12, 'prayer_logs': 40, 'key_values': 8, 'planets': 8};

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    bool seed = true,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    Size size = const Size(412, 915),
    int trailingFrames = 30,
  }) async {
    final lang = locale.languageCode;
    final (app, _) = await buildDataApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      beforePump: seed
          ? (MadarDatabase db) async {
              await seedSummaryScenario(db, lang: lang);
              await KeyValueRepository(db).setJson(lastBackupKey, DateTime(2026, 9, 27, 21).toUtc().toIso8601String());
            }
          : null,
    );
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      logicalSize: size,
      trailingFrames: trailingFrames,
      beforeCapture: (tester) async {
        await settleAsync(tester, rounds: 8);
        if (beforeCapture != null) await beforeCapture(tester);
      },
    );
  }

  /// Opens a sheet over the data centre.
  Future<void> Function(WidgetTester) openSheet(WidgetBuilder builder, {Future<void> Function(WidgetTester)? then}) =>
      (tester) async {
        final context = tester.element(find.byType(DataCentreScreen));
        showInteractionSheet<Object?>(context, builder: builder);
        await settleAsync(tester, rounds: 10);
        await frames(tester, 16);
        if (then != null) await then(tester);
      };

  const combos = [
    ('ar', 'lapis', Locale('ar'), MadarThemeId.lapis),
    ('ar', 'pearl', Locale('ar'), MadarThemeId.pearl),
    ('en', 'lapis', Locale('en'), MadarThemeId.lapis),
    ('en', 'pearl', Locale('en'), MadarThemeId.pearl),
  ];
  const pair = [
    ('ar', 'lapis', Locale('ar'), MadarThemeId.lapis),
    ('en', 'pearl', Locale('en'), MadarThemeId.pearl),
  ];

  for (final (lang, themeName, locale, theme) in combos) {
    final tag = '${lang}_$themeName';

    testWidgets('data centre – $tag (full length)', (tester) async {
      await shot(tester, 'centre_$tag', const DataCentreScreen(), theme: theme, locale: locale, size: const Size(412, 1720));
    });

    testWidgets('backup sheet (passphrase + meter) – $tag', (tester) async {
      await shot(
        tester,
        'backup_form_$tag',
        const DataCentreScreen(),
        theme: theme,
        locale: locale,
        beforeCapture: openSheet((_) => BackupSheet(initialPassphrase: lang == 'ar' ? 'قمر فوق المدينة القديمة' : 'moon over the old city')),
      );
    });

    testWidgets('AI summary preview – $tag', (tester) async {
      await shot(
        tester,
        'summary_$tag',
        const DataCentreScreen(),
        theme: theme,
        locale: locale,
        beforeCapture: openSheet((_) => const ExportPreviewSheet()),
      );
    });

    testWidgets('restore preview – $tag', (tester) async {
      await shot(
        tester,
        'restore_preview_$tag',
        RestoreFlow(
          debugState: RestoreDebugState(
            stage: RestoreStage.preview,
            header: _header,
            fileName: 'madar-backup-2026-09-12-1840.madarbackup',
            counts: _backupCounts,
            currentCounts: _currentCounts,
          ),
        ),
        theme: theme,
        locale: locale,
        size: const Size(412, 1250),
      );
    });
  }

  for (final (lang, themeName, locale, theme) in pair) {
    final tag = '${lang}_$themeName';

    testWidgets('backup ready – $tag', (tester) async {
      await shot(
        tester,
        'backup_ready_$tag',
        const DataCentreScreen(),
        theme: theme,
        locale: locale,
        beforeCapture: openSheet(
          (_) => const BackupSheet(initialPassphrase: 'amber lanterns over quiet water'),
          then: (tester) async {
            await tester.tap(find.byType(SheetButton).last);
            await settleAsync(tester, rounds: 30);
            await frames(tester, 20);
          },
        ),
      );
    });

    testWidgets('AI summary preview scrolled to the text – $tag', (tester) async {
      await shot(
        tester,
        'summary_text_$tag',
        const DataCentreScreen(),
        theme: theme,
        locale: locale,
        beforeCapture: openSheet(
          (_) => const ExportPreviewSheet(),
          then: (tester) async {
            for (var i = 0; i < 3; i++) {
              await tester.dragFrom(const Offset(206, 700), const Offset(0, -420));
              await frames(tester, 6);
            }
            await frames(tester, 20);
          },
        ),
      );
    });

    testWidgets('CSV export – $tag', (tester) async {
      await shot(
        tester,
        'csv_$tag',
        const DataCentreScreen(),
        theme: theme,
        locale: locale,
        beforeCapture: openSheet((_) => const CsvExportSheet(initialKind: DataCsvKind.transactions)),
      );
    });

    testWidgets('restore – choose – $tag', (tester) async {
      await shot(tester, 'restore_choose_$tag', const RestoreFlow(), theme: theme, locale: locale);
    });

    testWidgets('restore – wrong passphrase – $tag', (tester) async {
      await shot(
        tester,
        'restore_unlock_$tag',
        RestoreFlow(
          debugState: RestoreDebugState(
            stage: RestoreStage.unlock,
            fileName: 'madar-backup-2026-09-12-1840.madarbackup',
            header: _header,
            passError: true,
          ),
        ),
        theme: theme,
        locale: locale,
      );
    });

    testWidgets('restore – done – $tag', (tester) async {
      await shot(
        tester,
        'restore_done_$tag',
        RestoreFlow(
          debugState: RestoreDebugState(
            stage: RestoreStage.done,
            result: RestoreResult(
              safetyCopy: SafetyCopy(file: File('/nonexistent/madar-safety.madarbackup'), createdAt: DateTime(2026, 9, 30, 10), size: 1),
              restoredRecords: 11_322,
              previousRecords: 68,
            ),
          ),
        ),
        theme: theme,
        locale: locale,
      );
    });

    testWidgets('restore – damaged file – $tag', (tester) async {
      await shot(
        tester,
        'restore_error_$tag',
        const RestoreFlow(debugState: RestoreDebugState(stage: RestoreStage.failed, failure: RestoreFailure.corrupted)),
        theme: theme,
        locale: locale,
      );
    });
  }
}
