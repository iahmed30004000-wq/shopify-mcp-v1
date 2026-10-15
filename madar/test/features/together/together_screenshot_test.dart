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
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/together/together.dart';

import '../../helpers/screenshot_harness.dart';
import 'together_test_utils.dart';

const _dir = 'together';

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

/// A split-screen stand-in: each half a small rink with the player's paddle
/// and a HUD with their avatar, name and score.
class _SplitDemo extends StatelessWidget {
  const _SplitDemo();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final players = TogetherProfiles.defaults();
    final colors = [TogetherLook.colorOf(players.one), TogetherLook.colorOf(players.two)];
    return Scaffold(
      backgroundColor: t.space0,
      body: SplitScreenArena(
        colors: colors,
        center: MadarButton.icon(
          icon: Icons.pause_rounded,
          onPressed: () {},
          semanticLabel: tx.l.togetherPause,
          size: MadarButtonSize.small,
        ),
        halfBuilder: (context, half) {
          final c = colors[half.participant];
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.6),
                radius: 1.2,
                colors: [c.withValues(alpha: 0.28), t.space1, t.space0],
              ),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, 0.72),
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 3),
                      boxShadow: [BoxShadow(color: c.withValues(alpha: 0.7), blurRadius: 24)],
                    ),
                  ),
                ),
                if (half.participant == 1)
                  const Align(
                    alignment: Alignment(0.35, -0.45),
                    child: CircleAvatar(radius: 14, backgroundColor: Colors.white),
                  ),
              ],
            ),
          );
        },
        hudBuilder: (context, half) {
          final p = half.participant == 0 ? players.one : players.two;
          return Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Padding(
              padding: const EdgeInsets.all(Space.m),
              child: GlassCard(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.xs, Space.m, Space.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TogetherAvatarView(profile: p, displayName: tx.rawName(p), size: 32),
                    const SizedBox(width: Space.s),
                    Text(tx.rawName(p), style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(width: Space.m),
                    Text(
                      tx.n(half.participant == 0 ? 4 : 6),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: t.gold),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Colour emoji for avatars (the test engine has no system fallback).
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

void main() {
  setUpAll(_loadEmojiFont);

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    bool history = false,
    Future<void> Function(TogetherRepository repo)? seed,
    Future<void> Function(WidgetTester tester)? beforeCapture,
  }) async {
    final (app, _) = await buildTogetherApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      seed: (repo) async {
        if (history) await seedTogetherHistory(repo);
        if (seed != null) await seed(repo);
      },
    );
    await captureScreen(tester, app, '$_dir/$name', beforeCapture: beforeCapture);
  }

  Future<void> named(TogetherRepository repo) async {
    await repo.saveProfile(
      TogetherProfile.defaults(PlayerSlot.two).copyWith(
        avatar: const TogetherAvatar.emoji('🌙'),
        title: PlayerTitle.luckyStar,
      ),
    );
    await repo.saveProfile(TogetherProfile.defaults(PlayerSlot.one).copyWith(title: PlayerTitle.strategist));
  }

  testWidgets('home – Arabic, lapis', (tester) async {
    await shot(tester, 'home_ar', const TogetherHomeScreen(), history: true, seed: named);
  });

  testWidgets('home – Arabic, scrolled', (tester) async {
    await shot(
      tester,
      'home_ar_scrolled',
      const TogetherHomeScreen(),
      history: true,
      seed: named,
      beforeCapture: (tester) => tester.drag(find.byType(Scrollable).first, const Offset(0, -620)),
    );
  });

  testWidgets('home – English, pearl', (tester) async {
    await shot(tester, 'home_en_pearl', const TogetherHomeScreen(), locale: const Locale('en'), theme: MadarThemeId.pearl, history: true);
  });

  testWidgets('home – empty, emerald', (tester) async {
    await shot(tester, 'home_empty_ar', const TogetherHomeScreen(), theme: MadarThemeId.emerald);
  });

  testWidgets('hall of fame – Arabic, desert', (tester) async {
    await shot(tester, 'hall_ar', const HallOfFameScreen(), theme: MadarThemeId.desert, history: true, seed: named);
  });

  testWidgets('profile editor – Arabic, aurora', (tester) async {
    await shot(
      tester,
      'profile_ar',
      _SheetHost((c) => showTogetherProfileSheet(c, PlayerSlot.one)),
      theme: MadarThemeId.aurora,
    );
  });

  testWidgets('launch sheet – chess, Arabic', (tester) async {
    await shot(tester, 'launch_ar', _SheetHost((c) => showGameLaunchSheet(c, game: TogetherGames.chess)), seed: named);
  });

  testWidgets('launch sheet – air hockey, English, pearl', (tester) async {
    await shot(
      tester,
      'launch_en_pearl',
      _SheetHost((c) => showGameLaunchSheet(c, game: TogetherGames.airHockey)),
      locale: const Locale('en'),
      theme: MadarThemeId.pearl,
      seed: (repo) => repo.saveSettings(const TogetherSettings(defaultMode: PlayMode.splitScreen)),
    );
  });

  testWidgets('hand-off – Arabic, desert', (tester) async {
    final controller = HandOffController()..passTo(1);
    addTearDown(controller.dispose);
    await shot(
      tester,
      'handoff_ar',
      Scaffold(
        body: HandOffGate(
          controller: controller,
          profileOf: (p) => TogetherProfile.defaults(p == 0 ? PlayerSlot.one : PlayerSlot.two).copyWith(
            title: p == 1 ? PlayerTitle.cardShark : null,
          ),
          publicSummary: 'e4',
          privateBuilder: (context, p) => const SizedBox(),
        ),
      ),
      theme: MadarThemeId.desert,
    );
  });

  testWidgets('hand-off – English, lapis', (tester) async {
    final controller = HandOffController()..passTo(0);
    addTearDown(controller.dispose);
    await shot(
      tester,
      'handoff_en',
      Scaffold(
        body: HandOffGate(
          controller: controller,
          profileOf: (p) => TogetherProfile.defaults(p == 0 ? PlayerSlot.one : PlayerSlot.two),
          privateBuilder: (context, p) => const SizedBox(),
        ),
      ),
      locale: const Locale('en'),
    );
  });

  testWidgets('split screen – face to face', (tester) async {
    await shot(tester, 'split_ar', const _SplitDemo());
  });

  testWidgets('settings sheet – Arabic', (tester) async {
    await shot(tester, 'settings_ar', _SheetHost(showTogetherSettingsSheet));
  });

  // Review matrix: Arabic / English × Lapis / Pearl / Aurora at text scale
  // 1.3, with a Latin name among Arabic text and an Arabic name among English
  // (bidi), a custom title and a long history.
  group('matrix – text scale 1.3', () {
    Future<void> mixedNames(TogetherRepository repo) async {
      await repo.saveProfile(
        TogetherProfile.defaults(PlayerSlot.one).copyWith(name: 'Nova', title: PlayerTitle.strategist),
      );
      await repo.saveProfile(
        TogetherProfile.defaults(PlayerSlot.two).copyWith(
          name: 'نجمة الصباح',
          avatar: const TogetherAvatar.emoji('🌙'),
          customTitle: 'سيدة الباصرة',
        ),
      );
    }

    final screens = <String, (Widget Function(), bool history, Future<void> Function(WidgetTester)?)>{
      'home': (() => const TogetherHomeScreen(), true, null),
      'home_scrolled': (
        () => const TogetherHomeScreen(),
        true,
        (tester) => tester.drag(find.byType(Scrollable).first, const Offset(0, -700)),
      ),
      'hall': (() => const HallOfFameScreen(), true, null),
      'launch': (() => _SheetHost((c) => showGameLaunchSheet(c, game: TogetherGames.airHockey)), false, null),
      'handoff': (
        () => Scaffold(
          body: HandOffGate(
            controller: HandOffController()..passTo(1),
            profileOf: (p) => TogetherProfile.defaults(p == 0 ? PlayerSlot.one : PlayerSlot.two).copyWith(
              name: p == 0 ? 'Nova' : 'نجمة الصباح',
              customTitle: p == 1 ? 'سيدة الباصرة' : null,
            ),
            publicSummary: 'e4 → e5',
            privateBuilder: (context, p) => const SizedBox(),
          ),
        ),
        false,
        null,
      ),
      'split': (() => const _SplitDemo(), false, null),
      'settings': (() => const _SheetHost(showTogetherSettingsSheet), false, null),
      'profile': (() => _SheetHost((c) => showTogetherProfileSheet(c, PlayerSlot.two)), false, null),
    };
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final theme in const [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora]) {
        for (final e in screens.entries) {
          final (build, history, before) = e.value;
          testWidgets('${e.key} – ${locale.languageCode}, ${theme.name}', (tester) async {
            tester.platformDispatcher.textScaleFactorTestValue = 1.3;
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            await shot(
              tester,
              'matrix/${e.key}_${locale.languageCode}_${theme.name}',
              build(),
              theme: theme,
              locale: locale,
              history: history,
              seed: mixedNames,
              beforeCapture: before,
            );
          });
        }
      }
    }
  });
}
