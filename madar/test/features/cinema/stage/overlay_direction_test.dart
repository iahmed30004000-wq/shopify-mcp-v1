import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/stage/stage_kit.dart';

import '../cinema_fakes.dart';

class _Game extends CinemaGame {
  _Game({required super.context}) : super(skin: EraSkins.of(Era.silent));

  @override
  String get gameId => 'overlay_direction_test';

  @override
  Future<void> onSceneLoad() async {}
}

// Flame's GameWidget lays its overlays out left-to-right whatever the app's
// language, so the Arabic booth note read ".البكرة تستريح… والعرض بانتظارك"
// and the record stamp "!رقم قياسي جديد" (punctuation at the start). Every
// line on the stage's Flutter cards must follow the game's reading
// direction: right-to-left in Arabic, left-to-right in English.
void main() {
  setUpAll(() async => CinemaShaders.preload());

  Future<_Game> pumpGame(WidgetTester tester, Locale locale) async {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late _Game game;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prayerMuteProvider.overrideWithValue(PrayerMuteController(SilentSoundService()))],
        child: MaterialApp(
          locale: locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          home: CinemaGameView(
            kit: TestKit().kit,
            skipOpening: true,
            scoreSink: MemoryScoreSink(),
            builder: (ctx) => game = _Game(context: ctx),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return game;
  }

  Future<void> pumpSeconds(WidgetTester tester, double seconds) async {
    for (var t = 0.0; t < seconds; t += 0.05) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Every text line (labels and icons) drawn by [overlay].
  void expectLinesRead(WidgetTester tester, Finder overlay, TextDirection direction) {
    final lines = find.descendant(of: overlay, matching: find.byType(RichText));
    expect(lines, findsWidgets);
    for (final e in lines.evaluate()) {
      final p = e.renderObject! as RenderParagraph;
      expect(p.textDirection, direction, reason: '"${p.text.toPlainText()}" must be laid out $direction');
    }
  }

  for (final (locale, direction) in const [(Locale('ar'), TextDirection.rtl), (Locale('en'), TextDirection.ltr)]) {
    final l10n = lookupL10n(locale);

    testWidgets('the intermission booth reads ${direction.name} – ${locale.languageCode}', (tester) async {
      final g = await pumpGame(tester, locale);
      g.pauseGame();
      await pumpSeconds(tester, 0.8);
      final booth = find.byType(ProjectorBoothOverlay);
      expect(booth, findsOneWidget);
      final note = tester.renderObject<RenderParagraph>(find.text(l10n.cinemaStageBoothNote));
      expect(note.textDirection, direction, reason: 'the full stop belongs at the end of the sentence');
      expectLinesRead(tester, booth, direction);
    });

    testWidgets('the results marquee and its record stamp read ${direction.name} – ${locale.languageCode}', (
      tester,
    ) async {
      final g = await pumpGame(tester, locale);
      g.hud.best = 10;
      g.addScore(40);
      g.endScene(won: true);
      for (var i = 0; i < 300 && g.state != SceneState.ended; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await pumpSeconds(tester, 2.6);
      final marquee = find.byType(ResultsMarqueeOverlay);
      expect(marquee, findsOneWidget);
      final stamp = tester.renderObject<RenderParagraph>(find.text(l10n.cinemaStageNewRecord));
      expect(stamp.textDirection, direction, reason: 'the "!" belongs at the end of the stamp');
      expectLinesRead(tester, marquee, direction);
    });
  }
}
