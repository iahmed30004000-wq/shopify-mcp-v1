// The recitation end to end in the full app: the real RecitationPlayer (the
// app's QuranAudio) over the harness's scripted engine –
// * the reader's "play from here" queues the sura from that ayah, and the
//   ayah being recited is lit as the engine moves on;
// * a recitation started elsewhere is followed across mushaf pages;
// * Home docks the mini player just above its glass panel while something
//   plays, never over the panel's controls, and nothing when idle.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/widgets/task_panel.dart';
import 'package:madar/features/home/widgets/window_chips.dart';
import 'package:madar/features/quran/presentation/widgets/mushaf_page.dart' show MushafPage;
import 'package:madar/features/quran/presentation/widgets/verse_list.dart' show SurahVerseList, VerseCard;
import 'package:madar/features/quran/quran.dart';
import 'package:madar/features/recitation/recitation.dart';

import '../features/lock/lock_test_utils.dart';
import '../helpers/test_app.dart';

final _en = lookupL10n(const Locale('en'));

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _listMode(MadarDatabase db) =>
    QuranPrefsStore(Repositories(db).keyValues).updatePrefs((p) => p.copyWith(mode: QuranReaderMode.list));

void main() {
  testWidgets('play from here: the sura is queued from the ayah and the recited ayah is lit', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.quranReaderOf(ayah: const AyahRef(112, 2)),
      beforePump: _listMode,
      overrides: LockFixture.empty().overrides,
    );
    AyahRef? lit() => tester.widget<SurahVerseList>(find.byType(SurahVerseList)).marks.playing;
    expect(lit(), isNull);

    await tester.tap(find.byWidgetPredicate((w) => w is VerseCard && w.content.ref == const AyahRef(112, 2)));
    await settleApp(tester);
    await tester.tap(find.text(_en.quranActionPlay));
    await _frames(tester);
    final engine = app.faith.engine;
    // 112:2 to the end of al-Ikhlas (no basmala mid-sura), streamed from
    // everyayah after the user's tap.
    expect(engine.sources.map((s) => s.uri.toString().split('/').last), ['112002.mp3', '112003.mp3', '112004.mp3']);
    expect(engine.playing, isTrue);
    expect(app.container.read(quranAudioProvider).value.range, const AyahRange(AyahRef(112, 2), AyahRef(112, 4)));
    expect(lit(), const AyahRef(112, 2));
    // The mini player docks under the reader.
    expect(find.byKey(const ValueKey('now-playing-bar')), findsOneWidget);

    engine.finishCurrent();
    await _frames(tester);
    expect(lit(), const AyahRef(112, 3));
    engine.finishCurrent();
    await _frames(tester);
    expect(lit(), const AyahRef(112, 4));

    // The end: nothing lit, the mini player gone.
    engine.finishCurrent();
    await _frames(tester, 20);
    expect(lit(), isNull);
    expect(find.byKey(const ValueKey('now-playing-bar')), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the mushaf follows a recitation across its pages', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.quranReaderOf(ayah: const AyahRef(2, 255)),
      overrides: LockFixture.empty().overrides,
    );
    MushafPage page() => tester.widget<MushafPage>(find.byType(MushafPage));
    expect(page().page, 42);

    unawaited(app.container.read(quranAudioProvider).play(const AyahRange(AyahRef(2, 255), AyahRef(2, 257))));
    await _frames(tester);
    expect(page().marks.playing, const AyahRef(2, 255));
    final engine = app.faith.engine;
    engine.finishCurrent();
    await _frames(tester);
    expect(page().marks.playing, const AyahRef(2, 256));
    engine.finishCurrent();
    await _frames(tester, 20);
    // 2:257 opens page 43: the reader turned the page.
    expect(page().page, 43);
    expect(page().marks.playing, const AyahRef(2, 257));
    await app.container.read(quranAudioProvider).stop();
    await _frames(tester);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Home docks the mini player just above its panel while something plays', (tester) async {
    final app = await pumpMadarApp(tester, overrides: LockFixture.empty().overrides);
    final bar = find.byKey(const ValueKey('now-playing-bar'));
    expect(bar, findsNothing);

    unawaited(app.container.read(quranAudioProvider).play(const AyahRange(AyahRef(1, 1), AyahRef(1, 7))));
    await _frames(tester, 14);
    expect(bar, findsOneWidget);
    final rect = tester.getRect(bar);
    final panel = tester.getRect(find.byType(TaskPanel));
    // On the panel's edge, never over its controls (the prayer chips).
    expect(rect.bottom, lessThanOrEqualTo(panel.top + 0.5));
    expect(rect.bottom, greaterThan(panel.top - 24));
    expect(rect.overlaps(tester.getRect(find.byType(WindowChips))), isFalse);
    // Its controls answer: stop ends the recitation and the bar leaves.
    await tester.tap(find.descendant(of: bar, matching: find.byIcon(Icons.close_rounded)));
    await _frames(tester, 14);
    expect(app.container.read(recitationStateProvider).active, isFalse);
    expect(bar, findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });
}
