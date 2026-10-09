import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart' show MotionScope;
import '../../../core/providers.dart';
import '../../../core/sound/prayer_mute.dart';
import '../../../core/sound/sound_api.dart';
import 'cinema_engine.dart';
import 'stage/stage_materials.dart';

/// Hosts one [CinemaGame] full-bleed: builds it with the app's services
/// (sound, haptics, score sink, locale, direction, reduced motion), wires the
/// prayer mute, rebuilds the game on restart and disposes everything with the
/// widget.
///
/// Leaving a show (APK #15: "you cannot leave a game"):
/// * a pause plate sits in the top reading corner of every running show, so
///   there is always something visible to tap;
/// * Android back opens the Intermission, which offers "leave the game";
/// * Android back again leaves, after [confirmLeave] (so a stray back never
///   throws a run away).
class CinemaGameView extends ConsumerStatefulWidget {
  const CinemaGameView({
    super.key,
    required this.builder,
    this.kit,
    this.scoreSink,
    this.onResult,
    this.onExit,
    this.confirmLeave,
    this.skipOpening = false,
    this.seed = 0,
  });

  final CinemaGameBuilder builder;

  /// Defaults to [cinemaKitProvider].
  final CinemaKit? kit;

  /// Defaults to [cinemaScoreSinkProvider].
  final ScoreSink? scoreSink;
  final ValueChanged<GameResult>? onResult;

  /// Defaults to popping the route.
  final VoidCallback? onExit;

  /// Asked before the second Android back leaves a paused show; `true`
  /// leaves. Without it, back from the Intermission leaves straight away.
  final Future<bool> Function()? confirmLeave;

  /// Straight into gameplay (attract mode, screenshots).
  final bool skipOpening;
  final int seed;

  @override
  ConsumerState<CinemaGameView> createState() => _CinemaGameViewState();
}

class _CinemaGameViewState extends ConsumerState<CinemaGameView> {
  CinemaGame? _game;
  PrayerMuteController? _mute;
  int _generation = 0;

  CinemaKit get _kit => widget.kit ?? ref.read(cinemaKitProvider);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mute == null) {
      _mute = ref.read(prayerMuteProvider);
      _mute!.addListener(_onMute);
    }
    final game = _game ??= _create();
    game
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context)
      ..safePadding = MediaQuery.paddingOf(context)
      ..relayout();
  }

  CinemaGame _create() {
    HapticsService? haptics;
    try {
      haptics = ref.read(hapticsServiceProvider);
    } catch (_) {
      haptics = null; // not wired (tests, previews)
    }
    final context = CinemaContext(
      kit: _kit,
      l10n: L10n.of(this.context),
      sound: ref.read(soundServiceProvider),
      haptics: haptics,
      scoreSink: widget.scoreSink ?? ref.read(cinemaScoreSinkProvider),
      direction: Directionality.of(this.context),
      reducedMotion: MotionScope.reducedOf(this.context),
      skipOpening: widget.skipOpening,
      seed: widget.seed + _generation,
    );
    final game = widget.builder(context)
      ..onExitRequested = _exit
      ..onRestartRequested = _restart
      ..onResult = widget.onResult
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(this.context)
      ..safePadding = MediaQuery.paddingOf(this.context);
    game.setPrayerMuted(_mute?.muted ?? false);
    return game;
  }

  void _onMute() => _game?.setPrayerMuted(_mute?.muted ?? false);

  void _restart() {
    if (!mounted) return;
    setState(() {
      _generation++;
      _game = _create();
    });
  }

  void _exit() {
    if (!mounted) return;
    final onExit = widget.onExit;
    if (onExit != null) {
      onExit();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// Back: play → Intermission → leave (asking first). It never resumes:
  /// pressing back twice has to get the player out, not back into the show.
  void _onBack() {
    final game = _game;
    if (game == null) {
      _exit();
      return;
    }
    switch (game.state) {
      case SceneState.playing:
        game.pauseGame();
      case SceneState.paused:
        unawaited(_leaveFromBack());
      case SceneState.loading || SceneState.opening || SceneState.ending || SceneState.ended:
        _exit();
    }
  }

  Future<void> _leaveFromBack() async {
    final ask = widget.confirmLeave;
    if (ask == null) {
      _exit();
      return;
    }
    final leave = await ask();
    if (!mounted) return;
    if (leave) _exit();
  }

  @override
  void dispose() {
    _mute?.removeListener(_onMute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = _game!;
    final overlays = _kit.overlays;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Semantics(
        container: true,
        label: L10n.of(context).cinemaGameViewLabel,
        customSemanticsActions: {
          CustomSemanticsAction(label: L10n.of(context).cinemaPause): () => game.pauseGame(),
        },
        child: ColoredBox(
          color: const Color(0xFF000000),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GameWidget<CinemaGame>(
                key: ValueKey(_generation),
                game: game,
                overlayBuilderMap: {
                  for (final e in overlays.entries)
                    e.key: (BuildContext context, CinemaGame game) => e.value(context, game),
                },
                loadingBuilder: (_) => const SizedBox.expand(),
              ),
              // The one thing always on screen while the show runs: the way
              // to the Intermission (and from there out of the game).
              ValueListenableBuilder<SceneState>(
                valueListenable: game.sceneState,
                builder: (context, state, _) => state == SceneState.playing
                    ? SafeArea(
                        child: Align(
                          alignment: AlignmentDirectional.topStart,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: PausePlate(game: game),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pause plate: a small brass plaque in the show's own era colours, in
/// the top reading corner of every running show. Tapping it opens the
/// Intermission, whose card offers resume, restart and "leave the game".
class PausePlate extends StatelessWidget {
  const PausePlate({super.key, required this.game});

  final CinemaGame game;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final m = StageMaterials.of(game.skin);
    return Semantics(
      button: true,
      label: l10n.cinemaPause,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: game.pauseGame,
        // 48 dp of touch around a 40 dp plaque.
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: m.plaque.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(color: m.gilt, width: 2),
              ),
              child: Center(child: Icon(Icons.pause_rounded, size: 22, color: m.plaqueText)),
            ),
          ),
        ),
      ),
    );
  }
}
