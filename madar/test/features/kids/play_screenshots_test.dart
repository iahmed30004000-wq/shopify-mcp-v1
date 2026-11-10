@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/games/domain/pairs_game.dart';
import 'package:madar/features/kids/games/presentation/games_screen.dart';
import 'package:madar/features/kids/games/presentation/pairs_play_screen.dart';
import 'package:madar/features/kids/rewards/presentation/rewards_screen.dart';
import 'package:madar/features/kids/stories/application/story_providers.dart';
import 'package:madar/features/kids/stories/application/voice_providers.dart';
import 'package:madar/features/kids/stories/domain/voice_story.dart';
import 'package:madar/features/kids/stories/presentation/interactive_story_screen.dart';
import 'package:madar/features/kids/stories/presentation/parent_corner_screen.dart';
import 'package:madar/features/kids/stories/presentation/voice_stories_screen.dart';

import 'stories/voice_fakes.dart';
import '../../helpers/screenshot_harness.dart';

const _dir = 'kids/play';

Widget _app(Widget home, {List<Override> overrides = const [], Locale locale = const Locale('ar'), double scale = 1}) =>
    ProviderScope(
      overrides: [kidsStarCountProvider.overrideWithValue(24), ...overrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );

Phone _phone() {
  final phone = Phone();
  phone.kv.data['kids.voice_stories'] = encodeVoiceStories([
    const VoiceStory(id: 'a', title: 'حكاية قبل النوم', narrator: 'بصوت بابا', fileName: 'a.m4a', durationMs: 200000),
    const VoiceStory(id: 'b', title: 'حكاية الفانوس', colorIndex: 1, fileName: 'b.m4a', durationMs: 300000),
    const VoiceStory(id: 'c', title: 'حكاية السفر', colorIndex: 2),
  ]);
  phone.files.files.addAll(['${MemoryVoiceFiles.root}/a.m4a', '${MemoryVoiceFiles.root}/b.m4a']);
  return phone;
}

void main() {
  const size = Size(360, 780);

  testWidgets('rewards', (tester) async {
    await captureScreen(tester, _app(const RewardsScreen()), '$_dir/rewards_ar', logicalSize: size, dpr: 2);
    await captureScreen(
      tester,
      _app(const RewardsScreen(), locale: const Locale('en'), scale: 1.3),
      '$_dir/rewards_en_13',
      logicalSize: const Size(320, 640),
      dpr: 2,
    );
  });

  testWidgets('voice stories: the child', (tester) async {
    final phone = _phone();
    await captureScreen(
      tester,
      _app(const VoiceStoriesScreen(), overrides: phone.overrides()),
      '$_dir/voice_child_ar',
      logicalSize: size,
      dpr: 2,
      beforeCapture: (t) async {
        await t.tap(find.text('حكاية قبل النوم').last);
        await t.pump();
        phone.player.pos.add(const Duration(seconds: 84));
        await t.pump();
      },
    );
    await captureScreen(
      tester,
      _app(const VoiceStoriesScreen(), overrides: _phoneNoStories()),
      '$_dir/voice_child_empty_ar',
      logicalSize: size,
      dpr: 2,
    );
  });

  testWidgets('voice stories: the parent corner', (tester) async {
    final phone = _phone();
    await captureScreen(
      tester,
      _app(const ParentCornerScreen(), overrides: phone.overrides()),
      '$_dir/voice_corner_ar',
      logicalSize: size,
      dpr: 2,
      beforeCapture: (t) async {
        await t.drag(find.byType(ListView), const Offset(0, -150));
        await t.pump();
        await t.tap(find.text('سجّل بصوتك'));
        await t.pump();
        for (var i = 0; i < 25; i++) {
          phone.recorder.level.add(0.15 + (i % 7) * 0.1);
        }
        phone.now = phone.now.add(const Duration(seconds: 48));
        await t.pump(const Duration(seconds: 1));
      },
    );
  });

  testWidgets('interactive story', (tester) async {
    final meter = FakeSoundMeter();
    final overrides = [
      soundMeterProvider.overrideWithValue(meter),
      kidsParentAskProvider.overrideWithValue(() async => true),
    ];
    await captureScreen(
      tester,
      _app(const InteractiveStoryScreen(), overrides: overrides),
      '$_dir/story_prompt_ar',
      logicalSize: size,
      dpr: 2,
      settle: const Duration(milliseconds: 300),
      beforeCapture: (t) async {
        for (var i = 0; i < 2; i++) {
          await t.pump(const Duration(seconds: 4));
          await t.tap(find.byKey(const ValueKey('story-next')));
          await t.pump();
        }
        await t.pump(const Duration(seconds: 4));
      },
    );
    await captureScreen(
      tester,
      _app(const InteractiveStoryScreen(), overrides: overrides, locale: const Locale('en'), scale: 1.3),
      '$_dir/story_prompt_en_13',
      logicalSize: const Size(320, 568),
      dpr: 2,
      settle: const Duration(milliseconds: 300),
      beforeCapture: (t) async {
        for (var i = 0; i < 2; i++) {
          await t.pump(const Duration(seconds: 4));
          await t.tap(find.byKey(const ValueKey('story-next')));
          await t.pump();
        }
        await t.pump(const Duration(seconds: 4));
      },
    );
    // Mid-movement of the last beat: the trail and the glow.
    await captureScreen(
      tester,
      _app(const InteractiveStoryScreen(), overrides: overrides),
      '$_dir/story_last_ar',
      logicalSize: size,
      dpr: 2,
      settle: const Duration(milliseconds: 300),
      beforeCapture: (t) async {
        for (var i = 0; i < 5; i++) {
          await t.pump(const Duration(seconds: 4));
          if (find.byKey(const ValueKey('story-skip')).evaluate().isNotEmpty) {
            await t.tap(find.byKey(const ValueKey('story-skip')));
          } else {
            await t.tap(find.byKey(const ValueKey('story-next')));
          }
          await t.pump();
        }
        await t.pump(const Duration(milliseconds: 1700));
      },
    );
  });

  testWidgets('games', (tester) async {
    await captureScreen(tester, _app(const GamesScreen()), '$_dir/games_ar', logicalSize: size, dpr: 2);
    await captureScreen(
      tester,
      _app(const PairsPlayScreen(size: PairsSize.medium, seed: 4)),
      '$_dir/pairs_8_ar',
      logicalSize: size,
      dpr: 2,
      beforeCapture: (t) async {
        final g = PairsGame(size: PairsSize.medium, seed: 4);
        final first = g.deck[0];
        final p = [
          for (var i = 0; i < g.deck.length; i++)
            if (g.deck[i] == first) i,
        ];
        await t.tap(find.byKey(ValueKey('pair-card-${p[0]}')));
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(find.byKey(ValueKey('pair-card-${p[1]}')));
        await t.pump(const Duration(milliseconds: 400));
        final q = [
          for (var i = 0; i < g.deck.length; i++)
            if (g.deck[i] != first) i,
        ];
        await t.tap(find.byKey(ValueKey('pair-card-${q[0]}')));
        await t.pump(const Duration(milliseconds: 400));
      },
    );
    await captureScreen(
      tester,
      _app(const PairsPlayScreen(size: PairsSize.large, seed: 4), locale: const Locale('en'), scale: 1.3),
      '$_dir/pairs_12_en_13',
      logicalSize: const Size(320, 640),
      dpr: 2,
    );
  });
}

List<Override> _phoneNoStories() => Phone().overrides();
