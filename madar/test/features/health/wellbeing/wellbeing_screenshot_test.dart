@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';

import '../../../helpers/screenshot_harness.dart';
import 'wellbeing_harness.dart';
import 'wellbeing_seed.dart';

const _dir = 'phase4/wellbeing';

/// Shows [behind] and opens a sheet over it on the first frame.
class OpenOnStart extends ConsumerStatefulWidget {
  const OpenOnStart({super.key, required this.behind, required this.open});

  final Widget behind;
  final Future<void> Function(BuildContext context, WidgetRef ref) open;

  @override
  ConsumerState<OpenOnStart> createState() => _OpenOnStartState();
}

class _OpenOnStartState extends ConsumerState<OpenOnStart> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    if (!_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.open(context, ref);
      });
    }
    return widget.behind;
  }
}

/// The Health hub's wellbeing card, as the hub would place it.
class HubPreview extends StatelessWidget {
  const HubPreview({super.key});

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: L10n.of(context).wbNotifyGroup,
    body: ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xl),
      children: const [WellbeingTodayCard()],
    ),
  );
}

Future<void> _painEntryWithPoints(MadarDatabase db) async {
  final service = WellbeingService(Repositories(db), clock: () => wellbeingTestNow);
  final triggers = await Repositories(db).tagOptions.getAll(where: (t) => t.kind.equalsValue(TagKind.painTrigger));
  final locations = await Repositories(db).tagOptions.getAll(where: (t) => t.kind.equalsValue(TagKind.painLocation));
  await service.logPain(
    PainDraft(
      at: wellbeingTestNow.subtract(const Duration(minutes: 20)),
      score: 6,
      locations: [locations[1].label, locations[3].label],
      triggers: [triggers[2].label],
      points: const [
        BodyPoint(0.5, 0.142, BodySide.back),
        BodyPoint(0.58, 0.2, BodySide.back),
        BodyPoint(0.4, 0.71, BodySide.front),
      ],
    ),
  );
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    WellbeingSeed? seed = WellbeingSeed.full,
    bool reducedMotion = false,
    Future<void> Function(MadarDatabase db)? beforePump,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    int trailingFrames = 12,
  }) async {
    final (app, _) = await buildWellbeingApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      seed: seed,
      reducedMotion: reducedMotion,
      beforePump: beforePump,
    );
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      trailingFrames: trailingFrames,
      beforeCapture: (tester) async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (beforeCapture != null) await beforeCapture(tester);
      },
    );
  }

  Future<void> scroll(WidgetTester tester, double dy) async {
    await tester.drag(find.byType(Scrollable).last, Offset(0, -dy));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('today', () {
    testWidgets('Arabic, Lapis', (t) => shot(t, 'today_ar_lapis', const WellbeingScreen()));
    testWidgets(
      'English, Pearl',
      (t) => shot(t, 'today_en_pearl', const WellbeingScreen(), theme: MadarThemeId.pearl, locale: const Locale('en')),
    );
    testWidgets(
      'Arabic, Emerald – support banner',
      (t) => shot(
        t,
        'today_support_ar_emerald',
        const WellbeingScreen(),
        theme: MadarThemeId.emerald,
        seed: WellbeingSeed.lowMoodWeek,
      ),
    );
    testWidgets(
      'Arabic, Pearl – support banner',
      (t) => shot(
        t,
        'today_support_ar_pearl',
        const WellbeingScreen(),
        theme: MadarThemeId.pearl,
        seed: WellbeingSeed.lowMoodWeek,
      ),
    );
    testWidgets(
      'mood charts – Arabic, Pearl',
      (t) => shot(
        t,
        'mood_charts_ar_pearl',
        const WellbeingScreen(),
        theme: MadarThemeId.pearl,
        beforeCapture: (t) => scroll(t, 420),
      ),
    );
    testWidgets(
      'mood charts – English, Lapis',
      (t) => shot(
        t,
        'mood_charts_en_lapis',
        const WellbeingScreen(),
        locale: const Locale('en'),
        beforeCapture: (t) => scroll(t, 420),
      ),
    );
    testWidgets(
      'fresh install – Arabic, Lapis',
      (t) => shot(t, 'today_empty_ar_lapis', const WellbeingScreen(), seed: null),
    );
  });

  group('check-in sheet', () {
    Widget sheet() => OpenOnStart(
      behind: const WellbeingScreen(),
      open: (context, ref) async {
        final entries = await ref.read(wellbeingServiceProvider).watchMood().first;
        if (context.mounted) await showMoodCheckInSheet(context, entry: entries.first);
      },
    );
    testWidgets('Arabic, Lapis', (t) => shot(t, 'checkin_sheet_ar_lapis', sheet()));
    testWidgets(
      'English, Pearl',
      (t) => shot(t, 'checkin_sheet_en_pearl', sheet(), theme: MadarThemeId.pearl, locale: const Locale('en')),
    );
    testWidgets(
      'Arabic, Aurora – new',
      (t) => shot(
        t,
        'checkin_sheet_new_ar_aurora',
        OpenOnStart(
          behind: const WellbeingScreen(),
          open: (context, ref) => showMoodCheckInSheet(context, initialMood: 4),
        ),
        theme: MadarThemeId.aurora,
        seed: WellbeingSeed.empty,
      ),
    );
  });

  group('pain', () {
    testWidgets('Arabic, Lapis', (t) => shot(t, 'pain_ar_lapis', const WellbeingScreen(initialTab: WellbeingTab.pain)));
    testWidgets(
      'English, Pearl',
      (t) => shot(
        t,
        'pain_en_pearl',
        const WellbeingScreen(initialTab: WellbeingTab.pain),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      ),
    );
    testWidgets(
      'body heat map – Arabic, Desert',
      (t) => shot(
        t,
        'pain_heat_ar_desert',
        const WellbeingScreen(initialTab: WellbeingTab.pain),
        theme: MadarThemeId.desert,
        beforeCapture: (t) => scroll(t, 560),
      ),
    );
    testWidgets(
      'body heat map – English, Pearl',
      (t) => shot(
        t,
        'pain_heat_en_pearl',
        const WellbeingScreen(initialTab: WellbeingTab.pain),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforeCapture: (t) => scroll(t, 560),
      ),
    );
    Widget logSheet() => OpenOnStart(
      behind: const WellbeingScreen(initialTab: WellbeingTab.pain),
      open: (context, ref) async {
        final entries = await ref.read(wellbeingServiceProvider).watchPain().first;
        if (context.mounted) await showPainLogSheet(context, entry: entries.first);
      },
    );
    testWidgets(
      'log sheet with body map – Arabic, Lapis',
      (t) => shot(
        t,
        'pain_sheet_ar_lapis',
        logSheet(),
        beforePump: _painEntryWithPoints,
        beforeCapture: (t) => scroll(t, 160),
      ),
    );
    testWidgets(
      'log sheet with body map – English, Pearl',
      (t) => shot(
        t,
        'pain_sheet_en_pearl',
        logSheet(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: _painEntryWithPoints,
        beforeCapture: (t) => scroll(t, 160),
      ),
    );
    testWidgets(
      'tag manager – Arabic, Pearl',
      (t) => shot(
        t,
        'tag_manager_ar_pearl',
        OpenOnStart(
          behind: const WellbeingScreen(initialTab: WellbeingTab.pain),
          open: (context, ref) => showTagManagerSheet(context, TagKind.painTrigger),
        ),
        theme: MadarThemeId.pearl,
      ),
    );
  });

  group('habits', () {
    testWidgets(
      'Arabic, Lapis',
      (t) => shot(t, 'habits_ar_lapis', const WellbeingScreen(initialTab: WellbeingTab.habits)),
    );
    testWidgets(
      'English, Pearl',
      (t) => shot(
        t,
        'habits_en_pearl',
        const WellbeingScreen(initialTab: WellbeingTab.habits),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      ),
    );
  });

  group('worries', () {
    testWidgets(
      'window open – Arabic, Lapis',
      (t) => shot(t, 'worries_ar_lapis', const WellbeingScreen(initialTab: WellbeingTab.worries)),
    );
    testWidgets(
      'English, Pearl',
      (t) => shot(
        t,
        'worries_en_pearl',
        const WellbeingScreen(initialTab: WellbeingTab.worries),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      ),
    );
    testWidgets(
      'review – Arabic, Emerald',
      (t) => shot(
        t,
        'worry_review_ar_emerald',
        OpenOnStart(
          behind: const WellbeingScreen(initialTab: WellbeingTab.worries),
          open: (context, ref) => showWorryReviewSheet(context),
        ),
        theme: MadarThemeId.emerald,
      ),
    );
    testWidgets(
      'window sheet – English, Lapis',
      (t) => shot(
        t,
        'worry_window_sheet_en_lapis',
        OpenOnStart(
          behind: const WellbeingScreen(initialTab: WellbeingTab.worries),
          open: (context, ref) => showWorryWindowSheet(context),
        ),
        locale: const Locale('en'),
      ),
    );
  });

  group('insights', () {
    testWidgets(
      'Arabic, Lapis',
      (t) => shot(t, 'insights_ar_lapis', const WellbeingScreen(initialTab: WellbeingTab.insights)),
    );
    testWidgets(
      'English, Pearl',
      (t) => shot(
        t,
        'insights_en_pearl',
        const WellbeingScreen(initialTab: WellbeingTab.insights),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      ),
    );
    testWidgets(
      'Arabic, Desert',
      (t) => shot(
        t,
        'insights_ar_desert',
        const WellbeingScreen(initialTab: WellbeingTab.insights),
        theme: MadarThemeId.desert,
      ),
    );
    testWidgets(
      'not enough data – Arabic, Pearl',
      (t) => shot(
        t,
        'insights_empty_ar_pearl',
        const WellbeingScreen(initialTab: WellbeingTab.insights),
        theme: MadarThemeId.pearl,
        seed: const WellbeingSeed(days: 4),
      ),
    );
  });

  group('breathing', () {
    Future<void> startAndBreathe(WidgetTester t, Duration d) async {
      await t.tap(find.byIcon(Icons.play_arrow_rounded));
      for (var e = Duration.zero; e < d; e += const Duration(milliseconds: 50)) {
        await t.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets(
      'mid-inhale – Arabic, Lapis',
      (t) => shot(
        t,
        'breathing_inhale_ar_lapis',
        const BreathingScreen(),
        beforeCapture: (t) => startAndBreathe(t, const Duration(milliseconds: 1400)),
      ),
    );
    testWidgets(
      'mid-inhale – English, Pearl',
      (t) => shot(
        t,
        'breathing_inhale_en_pearl',
        const BreathingScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforeCapture: (t) => startAndBreathe(t, const Duration(milliseconds: 1400)),
      ),
    );
    testWidgets(
      'hold – Arabic, Aurora (box)',
      (t) => shot(
        t,
        'breathing_box_hold_ar_aurora',
        const BreathingScreen(pattern: 'box'),
        theme: MadarThemeId.aurora,
        beforeCapture: (t) => startAndBreathe(t, const Duration(milliseconds: 5400)),
      ),
    );
    testWidgets(
      'ready – Arabic, Emerald',
      (t) => shot(t, 'breathing_ready_ar_emerald', const BreathingScreen(), theme: MadarThemeId.emerald),
    );
    testWidgets(
      'reduced motion – Arabic, Lapis',
      (t) => shot(
        t,
        'breathing_reduced_ar_lapis',
        const BreathingScreen(),
        reducedMotion: true,
        beforeCapture: (t) => startAndBreathe(t, const Duration(milliseconds: 1400)),
      ),
    );
  });

  group('hub card', () {
    testWidgets('Arabic, Lapis', (t) => shot(t, 'hub_card_ar_lapis', const HubPreview()));
    testWidgets(
      'English, Pearl – support',
      (t) => shot(
        t,
        'hub_card_support_en_pearl',
        const HubPreview(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        seed: WellbeingSeed.lowMoodWeek,
      ),
    );
    testWidgets(
      'Arabic, Desert – no check-in yet',
      (t) => shot(
        t,
        'hub_card_ar_desert',
        const HubPreview(),
        theme: MadarThemeId.desert,
        seed: const WellbeingSeed(checkInToday: false),
      ),
    );
  });

  group('settings', () {
    testWidgets(
      'English, Lapis',
      (t) => shot(
        t,
        'settings_sheet_en_lapis',
        OpenOnStart(behind: const WellbeingScreen(), open: (context, ref) => showWellbeingSettingsSheet(context)),
        locale: const Locale('en'),
      ),
    );
    testWidgets(
      'Arabic, Pearl',
      (t) => shot(
        t,
        'settings_sheet_ar_pearl',
        OpenOnStart(behind: const WellbeingScreen(), open: (context, ref) => showWellbeingSettingsSheet(context)),
        theme: MadarThemeId.pearl,
      ),
    );
  });
}
