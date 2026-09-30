import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/audio/runtime/music_director.dart';
import 'package:madar/features/cinema/engine/audio/runtime/sfx_bank.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';

import '../cinema_fakes.dart';
import 'fake_mixer.dart';

class _Game extends CinemaGame {
  _Game({required super.context}) : super(skin: EraSkins.of(Era.rubberHose));

  @override
  String get gameId => 'audio_test';

  @override
  IntertitleCard? openingCard() => const IntertitleCard(text: 'Test');

  @override
  Future<void> onSceneLoad() async {}
}

void main() {
  setUpAll(() async => CinemaShaders.preload());

  testWidgets('the real director and bank follow a scene from opening to curtain', (tester) async {
    final mixer = FakeCinemaMixer();
    final source = FakeCueSource();
    ProceduralMusicDirector? music;
    ProceduralSfxBank? sfx;
    final kit = TestKit().kit.copyWith(
      music: (c) => music = ProceduralMusicDirector(c, mixer: mixer, source: source, prefetch: false),
      sfx: (c) => sfx = ProceduralSfxBank(c, mixer: mixer, source: source),
    );
    final mute = PrayerMuteController(SilentSoundService());
    late _Game game;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hapticsServiceProvider.overrideWithValue(RecordingHaptics()),
          prayerMuteProvider.overrideWithValue(mute),
          cinemaScoreSinkProvider.overrideWithValue(MemoryScoreSink()),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          home: CinemaGameView(kit: kit, builder: (ctx) => game = _Game(context: ctx)),
        ),
      ),
    );
    for (var i = 0; i < 400 && game.state != SceneState.playing; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(game.state, SceneState.playing);
    await tester.pump(const Duration(milliseconds: 16)); // the stinger lands on the next tick
    expect(music!.isReady, isTrue);
    expect(sfx!.isReady, isTrue);
    expect(music!.playingMood, game.openingMood);
    expect(music!.log, contains(startsWith('stinger sceneStart')));
    expect(mixer.active('stinger-sceneStart'), isNotEmpty);

    // Effects go through the bank.
    game.feedback(CinemaSound.coin);
    expect(mixer.active('sound:coin'), hasLength(1));

    // Intermission ducks the score.
    final bed = mixer.active('${game.openingMood.name}-bed').last;
    final full = bed.target;
    game.pauseGame();
    expect(bed.target, closeTo(full * ProceduralMusicDirector.duckGain, 1e-9));
    game.resumeGame();
    expect(bed.target, closeTo(full, 1e-9));

    // Prayer mute silences both.
    final lease = mute.acquire('adhan');
    await tester.pump();
    expect(bed.target, 0);
    game.feedback(CinemaSound.coin);
    expect(mixer.calls.where((c) => c.startsWith('play') && c.contains('sound:coin')), hasLength(1), reason: 'no new effects during prayer');
    expect(mixer.active('sound:coin'), isEmpty, reason: 'ringing effects are cut');
    lease.release();
    await tester.pump();
    expect(bed.target, closeTo(full, 1e-9));

    // The ending plays the victory jingle (its own hit, no doubled stinger).
    game.endScene(won: true);
    for (var i = 0; i < 300 && game.state != SceneState.ended; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(music!.playingMood, MusicMood.victory);
    expect(mixer.active('stinger-victory'), isEmpty);

    // Leaving releases every loaded source.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(mixer.sources, isEmpty);
  });
}
