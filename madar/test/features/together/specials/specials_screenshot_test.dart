@Tags(['screenshot'])
// Rendering glass + cosmos shaders can take minutes per shot on a loaded box.
@Timeout(Duration(minutes: 30))
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/together/together.dart';

import '../../../helpers/screenshot_harness.dart';
import '../together_test_utils.dart';

const _dir = 'together/specials';

/// Opens a sheet over an empty page once the first frame is up.
class _SheetHost extends StatefulWidget {
  const _SheetHost(this.open);

  final Future<void> Function(BuildContext context) open;

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(widget.open(context)));
  }

  @override
  Widget build(BuildContext context) => const MadarScaffold(title: '', body: SizedBox.shrink());
}

Future<void> _loadEmojiFont() async {
  for (final path in [
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
    '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter'}/engine/src/flutter/txt/third_party/fonts/NotoColorEmoji.ttf',
  ]) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final loader = FontLoader('NotoColorEmoji')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await loader.load();
    return;
  }
}

Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await _frames(tester, 4);
  await tester.tap(find.byKey(ValueKey(key)));
  await _frames(tester);
}

/// A round with both players' answers in (Arabic or English sample
/// answers – typed by the players in the shot, never app content).
KnowMeRound _answeredRound({required bool arabic, bool judged = false}) {
  final q = arabic
      ? const [
          RoundQuestion(id: 'fav.dish', text: 'ما طبقي المفضّل؟'),
          RoundQuestion(id: 'choose.seaMountain', text: 'أيّهما أختار: البحر أم الجبل؟'),
          RoundQuestion(id: 'me.laugh', text: 'ما الذي يُضحكني دائمًا؟'),
        ]
      : const [
          RoundQuestion(id: 'fav.dish', text: "What's my favourite dish?"),
          RoundQuestion(id: 'choose.seaMountain', text: 'Which would I pick: the sea or the mountains?'),
          RoundQuestion(id: 'me.laugh', text: 'What always makes me laugh?'),
        ];
  final r = KnowMeRound(id: 'shot1', questions: q, first: PlayerSlot.one, startedAt: togetherNow);
  r.submit(
    PlayerSlot.one,
    arabic
        ? const [
            KnowMeAnswer(own: 'المنسف', guess: 'المقلوبة'),
            KnowMeAnswer(own: 'البحر', guess: 'الجبل'),
            KnowMeAnswer(own: 'النكت القديمة', guess: 'القطط'),
          ]
        : const [
            KnowMeAnswer(own: 'Mansaf', guess: 'Maqluba'),
            KnowMeAnswer(own: 'The sea', guess: 'Mountains'),
            KnowMeAnswer(own: 'Old jokes', guess: 'Cat videos'),
          ],
  );
  r.submit(
    PlayerSlot.two,
    arabic
        ? const [
            KnowMeAnswer(own: 'مقلوبة', guess: 'منسف'),
            KnowMeAnswer(own: 'الجبل', guess: 'البحر'),
            KnowMeAnswer(own: 'مقاطع القطط', guess: 'النكت'),
          ]
        : const [
            KnowMeAnswer(own: 'Maqluba', guess: 'mansaf'),
            KnowMeAnswer(own: 'Mountains', guess: 'the sea'),
            KnowMeAnswer(own: 'Cat videos', guess: 'jokes'),
          ],
  );
  if (judged) {
    for (final item in r.pending) {
      r.judge(item, item.subject == PlayerSlot.one ? KnowMeVerdict.close : KnowMeVerdict.exact);
    }
    r.finish();
  }
  return r;
}

/// Specials in use: a bank with one question of the couple's own, three
/// weeks of challenges done together and this week half done, a points goal
/// under way and one reward already unlocked, a few rounds played.
Future<void> _seedSpecials(
  TogetherRepository repo, {
  bool arabic = false,
  bool thisWeekBoth = false,
  bool unlocked = false,
}) async {
  final sp = SpecialsRepository(repo.db);
  await seedTogetherHistory(repo);
  for (var k = 3; k >= 1; k--) {
    final at = togetherNow.subtract(Duration(days: 7 * k));
    await sp.markChallenge(PlayerSlot.one, done: true, now: at);
    await sp.markChallenge(PlayerSlot.two, done: true, now: at.add(const Duration(hours: 2)));
  }
  await sp.ensureWeek(togetherNow);
  await sp.markChallenge(PlayerSlot.two, done: true, now: togetherNow);
  if (thisWeekBoth) await sp.markChallenge(PlayerSlot.one, done: true, now: togetherNow);
  await sp.startGoal(
    reward: arabic ? 'نزهة في الغابة' : 'A picnic in the woods',
    target: 5,
    metric: GoalMetric.counter,
    now: togetherNow.subtract(const Duration(days: 40)),
  );
  await sp.bumpCounter(5);
  await sp.unlockIfReached(togetherNow.subtract(const Duration(days: 30)));
  await sp.startGoal(
    title: arabic ? 'رحلتنا' : 'Our trip',
    reward: arabic ? 'يوم على شاطئ البحر الميت' : 'A day by the Dead Sea',
    target: unlocked ? 12 : 40,
    now: togetherNow.subtract(const Duration(days: 20)),
  );
  for (var i = 0; i < 12; i++) {
    await repo.recordMatch(
      MatchRecord(
        id: 'goal-$i',
        gameId: i.isEven ? 'knowMe' : 'backgammon',
        endedAt: togetherNow.subtract(Duration(days: 10 - i % 9, hours: i)),
        outcome: i % 3 == 0 ? MatchOutcome.oneWon : MatchOutcome.twoWon,
        scoreOne: i.isEven ? 6 + i % 4 : null,
        scoreTwo: i.isEven ? 8 - i % 3 : null,
      ),
    );
  }
  if (unlocked) await sp.unlockIfReached(togetherNow);
}

void main() {
  setUpAll(_loadEmojiFont);

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    Future<void> Function(TogetherRepository repo)? seed,
    Future<void> Function(WidgetTester tester)? beforeCapture,
    double? textScale,
  }) async {
    if (textScale != null) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final (app, _) = await buildTogetherApp(tester, home: home, theme: theme, locale: locale, seed: seed);
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture);
  }

  Future<void> seeded(TogetherRepository repo) => _seedSpecials(repo, arabic: true);

  Future<void> scrollHome(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -330));
    await _frames(tester);
  }

  Future<void> revealFirst(WidgetTester tester) async {
    await _tap(tester, 'knowme-reveal-0-one');
    await _tap(tester, 'knowme-reveal-0-two');
    await _tap(tester, 'knowme-judge-0-two-close');
  }

  Future<void> privateView(WidgetTester tester, {required bool arabic}) async {
    await tester.pump(HandOffScreen.armDelay);
    await _frames(tester, 4);
    await tester.tap(find.byKey(const ValueKey('together-reveal')));
    await _frames(tester, 12);
    Finder field(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField));
    await tester.enterText(field('knowme-own-0'), arabic ? 'المنسف طبعًا' : 'Mansaf, of course');
    await tester.enterText(field('knowme-guess-0'), arabic ? 'المقلوبة' : 'Maqluba');
    FocusManager.instance.primaryFocus?.unfocus();
    await _frames(tester);
  }

  KnowMeRound fresh({required bool arabic}) => KnowMeRound(
    id: 'shot2',
    questions: [
      RoundQuestion(id: 'fav.dish', text: arabic ? 'ما طبقي المفضّل؟' : "What's my favourite dish?"),
      RoundQuestion(id: 'fav.drink', text: arabic ? 'ما مشروبي المفضّل؟' : "What's my favourite drink?"),
      RoundQuestion(id: 'me.calm', text: arabic ? 'ما الذي يُهدّئني حين أغضب؟' : "What calms me down when I'm upset?"),
    ],
    first: PlayerSlot.two,
    startedAt: togetherNow,
  );

  // ------------------------------------------------------------- home

  testWidgets('home section – Arabic, lapis', (tester) async {
    await shot(tester, 'home_specials_ar', const TogetherHomeScreen(), seed: seeded, beforeCapture: scrollHome);
  });

  testWidgets('home section – English, pearl', (tester) async {
    await shot(
      tester,
      'home_specials_en_pearl',
      const TogetherHomeScreen(),
      locale: const Locale('en'),
      theme: MadarThemeId.pearl,
      seed: _seedSpecials,
      beforeCapture: scrollHome,
    );
  });

  testWidgets('home section – empty, emerald', (tester) async {
    await shot(tester, 'home_specials_empty_ar', const TogetherHomeScreen(), theme: MadarThemeId.emerald, beforeCapture: scrollHome);
  });

  // ---------------------------------------------------------- know me

  testWidgets('know me set-up – Arabic, lapis', (tester) async {
    await shot(tester, 'knowme_setup_ar', const KnowMeScreen(), seed: seeded);
  });

  testWidgets('know me set-up – English, pearl', (tester) async {
    await shot(tester, 'knowme_setup_en_pearl', const KnowMeScreen(), locale: const Locale('en'), theme: MadarThemeId.pearl);
  });

  testWidgets('know me hand-off – Arabic, desert', (tester) async {
    await shot(tester, 'knowme_handoff_ar', KnowMeRoundScreen(round: fresh(arabic: true)), theme: MadarThemeId.desert);
  });

  testWidgets('know me private answers – Arabic, aurora', (tester) async {
    await shot(
      tester,
      'knowme_private_ar',
      KnowMeRoundScreen(round: fresh(arabic: true)),
      theme: MadarThemeId.aurora,
      beforeCapture: (t) => privateView(t, arabic: true),
    );
  });

  testWidgets('know me private answers – English, pearl', (tester) async {
    await shot(
      tester,
      'knowme_private_en_pearl',
      KnowMeRoundScreen(round: fresh(arabic: false)),
      locale: const Locale('en'),
      theme: MadarThemeId.pearl,
      beforeCapture: (t) => privateView(t, arabic: false),
    );
  });

  testWidgets('know me reveal – Arabic, lapis', (tester) async {
    await shot(tester, 'knowme_reveal_ar', KnowMeRoundScreen(round: _answeredRound(arabic: true)), beforeCapture: revealFirst);
  });

  testWidgets('know me reveal – English, pearl', (tester) async {
    await shot(
      tester,
      'knowme_reveal_en_pearl',
      KnowMeRoundScreen(round: _answeredRound(arabic: false)),
      locale: const Locale('en'),
      theme: MadarThemeId.pearl,
      beforeCapture: revealFirst,
    );
  });

  testWidgets('know me results – Arabic, emerald', (tester) async {
    await shot(
      tester,
      'knowme_results_ar',
      KnowMeRoundScreen(round: _answeredRound(arabic: true, judged: true)),
      theme: MadarThemeId.emerald,
    );
  });

  testWidgets('know me results – English, aurora', (tester) async {
    await shot(
      tester,
      'knowme_results_en_aurora',
      KnowMeRoundScreen(round: _answeredRound(arabic: false, judged: true)),
      locale: const Locale('en'),
      theme: MadarThemeId.aurora,
    );
  });

  testWidgets('question bank – Arabic, lapis', (tester) async {
    await shot(
      tester,
      'bank_ar',
      const QuestionBankScreen(),
      seed: (repo) => SpecialsRepository(repo.db).updateBank(
        (b) => b
            .addQuestion(id: 'qown', categoryId: 'fav', text: 'ما الأغنية التي أردّدها دائمًا؟')
            .editQuestion('fav.fruit', text: 'ما الفاكهة التي أحبّها في الصيف؟'),
      ),
    );
  });

  testWidgets('question bank – English, pearl', (tester) async {
    await shot(
      tester,
      'bank_en_pearl',
      const QuestionBankScreen(),
      locale: const Locale('en'),
      theme: MadarThemeId.pearl,
      seed: (repo) => SpecialsRepository(repo.db).updateBank((b) => b.addCategory(id: 'ctravel', name: 'Travel', icon: 'plane')),
    );
  });

  // ------------------------------------------------------------ weekly

  testWidgets('weekly – Arabic, lapis (half done, streak 3)', (tester) async {
    await shot(tester, 'weekly_ar', const WeeklyChallengeScreen(), seed: seeded);
  });

  testWidgets('weekly – English, pearl (done together)', (tester) async {
    await shot(
      tester,
      'weekly_en_pearl',
      const WeeklyChallengeScreen(),
      locale: const Locale('en'),
      theme: MadarThemeId.pearl,
      seed: (repo) => _seedSpecials(repo, thisWeekBoth: true),
      // English sample texts.
    );
  });

  testWidgets('weekly – Arabic, aurora (fresh), scrolled', (tester) async {
    await shot(
      tester,
      'weekly_ar_aurora',
      const WeeklyChallengeScreen(),
      theme: MadarThemeId.aurora,
      beforeCapture: (t) async {
        await t.drag(find.byType(Scrollable).first, const Offset(0, -300));
        await _frames(t);
      },
    );
  });

  testWidgets('challenge list – Arabic, desert', (tester) async {
    await shot(
      tester,
      'challenges_ar',
      const ChallengeListScreen(),
      theme: MadarThemeId.desert,
      seed: (repo) => SpecialsRepository(repo.db).updateChallenges(
        (c) => c.add(id: 'wown', text: 'نزور جدّتنا ونأخذ لها حلوى').setHidden('fast', true).edit('walk', 'نتمشّى معًا في الحديقة'),
      ),
    );
  });

  testWidgets('week start – Arabic sheet', (tester) async {
    await shot(tester, 'settings_ar', const _SheetHost(showSpecialsSettingsSheet));
  });

  // -------------------------------------------------------------- goal

  testWidgets('goal – Arabic, lapis (under way, one reward earned)', (tester) async {
    await shot(tester, 'goal_ar', const CoopGoalScreen(), seed: seeded);
  });

  testWidgets('goal – English, pearl (unlocked)', (tester) async {
    await shot(
      tester,
      'goal_en_pearl_unlocked',
      const CoopGoalScreen(),
      locale: const Locale('en'),
      theme: MadarThemeId.pearl,
      seed: (repo) => _seedSpecials(repo, unlocked: true),
    );
  });

  testWidgets('goal – empty, aurora', (tester) async {
    await shot(tester, 'goal_empty_ar', const CoopGoalScreen(), theme: MadarThemeId.aurora);
  });

  testWidgets('goal editor – Arabic sheet', (tester) async {
    await shot(tester, 'goal_editor_ar', const _SheetHost(showGoalEditorSheet));
  });

  testWidgets('reward unlocked – English, lapis', (tester) async {
    await shot(
      tester,
      'goal_unlock_en',
      const CoopGoalScreen(),
      locale: const Locale('en'),
      seed: (repo) async {
        final sp = SpecialsRepository(repo.db);
        await sp.startGoal(reward: 'Breakfast at the old café', target: 2, metric: GoalMetric.counter, now: togetherNow);
        await sp.bumpCounter(2);
      },
    );
  });

  // Review matrix: text scale 1.3 with a Latin name among Arabic text and an
  // Arabic name among English (bidi), Arabic / English × Lapis / Pearl /
  // Aurora.
  group('matrix – text scale 1.3', () {
    Future<void> Function(TogetherRepository) mixed({required bool arabic}) => (repo) async {
      await repo.saveProfile(TogetherProfile.defaults(PlayerSlot.one).copyWith(name: 'Nova', title: PlayerTitle.strategist));
      await repo.saveProfile(
        TogetherProfile.defaults(PlayerSlot.two).copyWith(name: 'نجمة الصباح', avatar: const TogetherAvatar.emoji('🌙')),
      );
      await _seedSpecials(repo, arabic: arabic);
    };

    final screens = <String, (Widget Function(bool arabic), Future<void> Function(WidgetTester)?)>{
      'home': ((_) => const TogetherHomeScreen(), scrollHome),
      'knowme': ((_) => const KnowMeScreen(), null),
      'reveal': ((arabic) => KnowMeRoundScreen(round: _answeredRound(arabic: arabic)), revealFirst),
      'results': ((arabic) => KnowMeRoundScreen(round: _answeredRound(arabic: arabic, judged: true)), null),
      'weekly': ((_) => const WeeklyChallengeScreen(), null),
      'goal': ((_) => const CoopGoalScreen(), null),
    };
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final theme in const [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora]) {
        for (final e in screens.entries) {
          final (build, before) = e.value;
          testWidgets('${e.key} – ${locale.languageCode}, ${theme.name}', (tester) async {
            await shot(
              tester,
              'matrix/${e.key}_${locale.languageCode}_${theme.name}',
              build(locale.languageCode == 'ar'),
              theme: theme,
              locale: locale,
              seed: mixed(arabic: locale.languageCode == 'ar'),
              beforeCapture: before,
              textScale: 1.3,
            );
          });
        }
      }
    }
  });
}
