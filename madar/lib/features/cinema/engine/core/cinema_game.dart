import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import 'audio.dart';
import 'cinema_context.dart';
import 'cinema_env.dart';
import 'cinema_kit.dart';
import 'cinema_shaders.dart';
import 'era.dart';
import 'era_skin.dart';
import 'film_clock.dart';
import 'film_fx.dart';
import 'rig.dart';
import 'score.dart';
import 'stage.dart';

/// Where a scene is in its life.
enum SceneState {
  /// onLoad running.
  loading,

  /// Opening intertitle + iris-in (world animates, gameplay input ignored).
  opening,

  /// Gameplay.
  playing,

  /// Intermission: world frozen, projector (grain, boil, curtains) rolling.
  paused,

  /// Closing iris + end card.
  ending,

  /// Results overlay showing.
  ended,
}

/// Base class of every Madar Cinema game: a Flame game wearing an era skin,
/// framed by a stage, with a HUD, transitions, a score, sound and one film
/// grade over the whole frame.
///
/// Layers (screen space unless noted), bottom → top:
///
/// | priority | layer                                                  |
/// |----------|--------------------------------------------------------|
/// | −1000    | input catcher (unhandled taps/drags → onScreen… hooks) |
/// | −100     | [StageFrame.paintBack]                                 |
/// | 0        | camera: the [world] (world units, clipped to playRect) |
/// | 100      | [StageFrame.paintFront] (curtains, footlights)         |
/// | 200      | HUD slots ([buildHud])                                 |
/// | 300      | [CinemaTransitions.paint] (iris, burn, intertitles)    |
/// | —        | [FilmFx.apply] grades the recorded frame (render())    |
///
/// Subclasses implement [gameId] and [onSceneLoad] (add components to
/// [world], laid out in [worldSize] units) and react through the hooks
/// ([onSceneStart], [onGameplayUpdate], [onScreenTapDown] …). They call
/// [addScore], [feedback], [kick], [endScene]; they never touch the
/// renderer, the audio backend or the lifecycle directly.
abstract class CinemaGame extends FlameGame<CinemaWorld> {
  CinemaGame({required this.context, required this.skin, CinemaWorld? world})
    : super(world: world ?? CinemaWorld(), camera: CameraComponent(viewport: FixedSizeViewport(1, 1)));

  final CinemaContext context;
  final EraSkin skin;

  Era get era => skin.era;
  L10n get l10n => context.l10n;

  /// Catalog id (the `games/<id>/` folder).
  String get gameId;

  /// Design resolution of the world in world units. The camera fits it into
  /// the stage's play area ("contain"): on other aspect ratios some world
  /// beyond these bounds is visible, so paint backgrounds generously.
  Vector2 get worldSize => Vector2(360, 640);

  // ---------------------------------------------------------------------------
  // Hooks for subclasses.

  /// Build the scene: add components to [world]. Engine pieces are ready.
  Future<void> onSceneLoad();

  /// Optional opening title card (localised via [l10n]).
  IntertitleCard? openingCard() => null;

  /// End card; defaults to "The End" / "Game Over".
  IntertitleCard endingCard(GameResult result) => IntertitleCard(
    text: result.won ? l10n.cinemaTheEnd : l10n.cinemaGameOver,
    kind: result.won ? IntertitleKind.theEnd : IntertitleKind.gameOver,
  );

  /// Score mood for the opening.
  MusicMood get openingMood => MusicMood.adventure;

  /// HUD layout; default: score at top-start, lives at top-center, pause at
  /// top-end. Called once after [onSceneLoad].
  List<(HudSlot, HudItem)> buildHud() => [
    (HudSlot.topStart, hudKit.score()),
    (HudSlot.topCenter, hudKit.lives()),
    (HudSlot.topEnd, hudKit.pauseButton(pauseGame)),
  ];

  /// Gameplay begins (after the opening transition).
  void onSceneStart() {}

  /// Called every tick while [isPlaying], after the component tree update.
  void onGameplayUpdate(double dt) {}

  /// Taps/drags nobody else handled (world components with TapCallbacks and
  /// interactive HUD items get theirs first). Positions in world units and
  /// screen px.
  void onScreenTapDown(Vector2 worldPoint, ui.Offset screenPoint) {}
  void onScreenTapUp(Vector2 worldPoint, ui.Offset screenPoint) {}
  void onScreenDrag(Vector2 worldDelta, ui.Offset screenPoint) {}
  void onScreenDragEnd() {}

  // ---------------------------------------------------------------------------
  // Engine state.

  late final CinemaEnv env = context.envFor(skin);
  late final FilmClock clock = FilmClock(
    boilFps: skin.ink.boilFps,
    projectionFps: skin.grade.projectionFps,
    seed: (env.seed % 997).toDouble(),
  );
  final FilmFrame film = FilmFrame();
  final HudModel hud = HudModel();
  late final HudContext hudContext;

  /// Shared paint context for [RigCharacter.paint] (pixelScale = camera zoom).
  late final RigPaintContext rigPaint = RigPaintContext(skin: skin, clock: clock);

  late final FilmFx filmFx;
  late final StageFrame stage;
  late final HudKit hudKit;
  late final CinemaTransitions transitions;
  late final MusicDirector music;
  late final SfxBank sfx;

  final ValueNotifier<SceneState> sceneState = ValueNotifier(SceneState.loading);
  SceneState get state => sceneState.value;
  bool get isPlaying => state == SceneState.playing;

  /// The world does not update while loading or paused.
  bool get isWorldFrozen => state == SceneState.loading || state == SceneState.paused;

  /// Set by the host view.
  double devicePixelRatio = 1;
  EdgeInsets safePadding = EdgeInsets.zero;
  VoidCallback? onExitRequested;
  VoidCallback? onRestartRequested;
  ValueChanged<GameResult>? onResult;

  /// Debug / perf switch: render without the film grade.
  bool filmEnabled = true;

  GameResult? get result => _result;
  GameResult? _result;
  bool _ready = false;
  bool _prayerMuted = false;
  bool _disposed = false;
  double _playTime = 0;
  late final HudLayer _hudLayer;

  /// The stage's play area in screen px.
  ui.Rect get playRect => stage.playRect;

  /// Screen px → world units.
  Vector2 screenToWorld(ui.Offset p) => camera.globalToLocal(Vector2(p.dx, p.dy));

  /// World units → screen px.
  ui.Offset worldToScreen(Vector2 p) {
    final v = camera.localToGlobal(p);
    return ui.Offset(v.x, v.y);
  }

  // ---------------------------------------------------------------------------
  // Gameplay API.

  void addScore(int points) => hud.score = math.max(0, hud.score + points);

  /// Sound + paired haptic.
  void feedback(CinemaSound sound, {double volume = 1, double pitch = 1, double pan = 0, Haptic? haptic}) {
    if (!_ready) return;
    sfx.play(sound, volume: volume, pitch: pitch, pan: pan);
    context.haptics?.fire(haptic ?? cinemaSoundHaptics[sound] ?? Haptic.none);
  }

  /// Film "kick": flash / shake / reel damage (decays by itself) and a
  /// footlight pulse.
  void kick({double flash = 0, double shake = 0, double damage = 0}) {
    film.kick(flash: flash, shake: shake, damage: damage);
    if (_ready && flash > 0) stage.pulse(flash);
  }

  /// Intermission (only from [SceneState.playing]).
  void pauseGame() {
    if (!isPlaying || _disposed) return;
    sceneState.value = SceneState.paused;
    music.setDucked(true);
    overlays.add(CinemaOverlays.pause);
  }

  void resumeGame() {
    if (state != SceneState.paused || _disposed) return;
    overlays.remove(CinemaOverlays.pause);
    music.setDucked(false);
    sceneState.value = SceneState.playing;
  }

  /// Ends the show: stinger, closing transition, end card, result reported
  /// to the score sink and [onResult], then the results overlay.
  Future<void> endScene({required bool won, Map<String, num> stats = const {}}) async {
    if (!_ready || state == SceneState.ending || state == SceneState.ended) return;
    overlays.remove(CinemaOverlays.pause);
    sceneState.value = SceneState.ending;
    final r = GameResult(
      gameId: gameId,
      score: hud.score,
      won: won,
      playTime: Duration(milliseconds: (_playTime * 1000).round()),
      stats: stats,
    );
    _result = r;
    music
      ..stinger(won ? Stinger.victory : Stinger.defeat)
      ..cue(won ? MusicMood.victory : MusicMood.defeat);
    await transitions.irisOut();
    if (_disposed) return;
    await transitions.intertitle(endingCard(r));
    if (_disposed) return;
    final sink = context.scoreSink;
    if (sink != null) unawaited(sink.submit(r).catchError((Object _) {}));
    onResult?.call(r);
    sceneState.value = SceneState.ended;
    overlays.add(CinemaOverlays.results);
  }

  void requestRestart() => onRestartRequested?.call();
  void requestExit() => onExitRequested?.call();

  /// Prayer mute from the host (PrayerMuteController).
  void setPrayerMuted(bool muted) {
    _prayerMuted = muted;
    if (!_ready) return;
    music.setPrayerMuted(muted);
    sfx.setPrayerMuted(muted);
  }

  // ---------------------------------------------------------------------------
  // Flame plumbing.

  @override
  Future<void> onLoad() async {
    await CinemaShaders.preload();
    final kit = context.kit;
    filmFx = kit.filmFx(env);
    stage = kit.stage(env);
    hudKit = kit.hud(env);
    transitions = kit.transitions(env);
    final audio = CinemaAudioContext(sound: context.sound, era: era, score: skin.score, seed: env.seed);
    music = kit.music(audio);
    sfx = kit.sfx(audio);
    hudContext = HudContext(skin: skin, clock: clock, model: hud, direction: env.direction);
    film.reduceFlicker = env.reducedMotion;
    await filmFx.load();
    unawaited(music.prepare().catchError((Object e) => _log('music.prepare', e)));
    unawaited(sfx.prepare().catchError((Object e) => _log('sfx.prepare', e)));
    _hudLayer = HudLayer(this)..priority = 200;
    // Not awaited: children of the root load when the game mounts, i.e.
    // after this onLoad returns (awaiting here would deadlock).
    addAll([
      _InputLayer()..priority = -1000,
      _PaintLayer((c) => stage.paintBack(c))..priority = -100,
      _PaintLayer((c) => stage.paintFront(c))..priority = 100,
      _hudLayer,
      _PaintLayer((c) => transitions.paint(c))..priority = 300,
    ]);
    // Flame gives the camera max priority; the stage front, HUD and
    // transitions must paint above the world.
    camera.priority = 0;
    camera.viewfinder.anchor = Anchor.center;
    _ready = true;
    if (_prayerMuted) setPrayerMuted(true);
    transitions.cover();
    _layout();
    await onSceneLoad();
    for (final (slot, item) in buildHud()) {
      _hudLayer.place(slot, item);
    }
    unawaited(_runOpening());
  }

  Future<void> _runOpening() async {
    sceneState.value = SceneState.opening;
    music.cue(openingMood);
    if (context.skipOpening) {
      transitions.clear();
      unawaited(stage.openCurtains(duration: Duration.zero));
    } else {
      final card = openingCard();
      if (card != null) await transitions.intertitle(card);
      if (_disposed) return;
      unawaited(stage.openCurtains());
      await transitions.irisIn();
    }
    if (_disposed || state != SceneState.opening) return;
    sceneState.value = SceneState.playing;
    music.stinger(Stinger.sceneStart);
    onSceneStart();
  }

  /// Re-applies the layout (host changed safe padding / pixel ratio).
  void relayout() => _layout();

  void _layout() {
    if (!_ready || !hasLayout) return;
    final s = canvasSize;
    if (s.x <= 0 || s.y <= 0) return;
    final screen = ui.Size(s.x, s.y);
    stage.layout(screen, safePadding);
    final r = stage.playRect;
    camera.viewport
      ..position = Vector2(r.left, r.top)
      ..size = Vector2(r.width, r.height);
    camera.viewfinder
      ..visibleGameSize = worldSize
      ..position = worldSize / 2;
    rigPaint.pixelScale = camera.viewfinder.zoom;
    transitions.layout(screen, r);
    hudContext.scale = (s.x / 412).clamp(0.8, 1.4);
    _hudLayer.relayout(stage.hudRect);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout();
  }

  @override
  void update(double dt) {
    final step = dt.isFinite ? dt.clamp(0.0, 1 / 20) : 0.0;
    clock.advance(step);
    film.decay(step);
    if (_ready) {
      filmFx.update(step, clock);
      stage.update(step, clock);
      transitions.update(step, clock);
      music.update(step);
      if (isPlaying) _playTime += step;
    }
    super.update(step);
    if (_ready && isPlaying) onGameplayUpdate(step);
  }

  @override
  void render(ui.Canvas canvas) {
    if (!_ready || !filmEnabled || !filmFx.isReady) {
      super.render(canvas);
      return;
    }
    final s = canvasSize;
    final scale = devicePixelRatio * filmFx.resolutionScale;
    final w = (s.x * scale).ceil();
    final h = (s.y * scale).ceil();
    if (w <= 0 || h <= 0) {
      super.render(canvas);
      return;
    }
    // One offscreen pass: record → rasterise → grade (works on Skia and
    // Impeller; ImageFilter.shader would be Impeller-only).
    final recorder = ui.PictureRecorder();
    final offscreen = ui.Canvas(recorder)..scale(scale);
    super.render(offscreen);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    filmFx.apply(canvas, image, ui.Rect.fromLTWH(0, 0, s.x, s.y), clock, film);
    image.dispose();
  }

  @override
  void lifecycleStateChange(ui.AppLifecycleState state) {
    super.lifecycleStateChange(state);
    if (!_ready || _disposed) return;
    switch (state) {
      case ui.AppLifecycleState.resumed:
        music.resume();
      case ui.AppLifecycleState.inactive:
        break;
      case ui.AppLifecycleState.hidden:
      case ui.AppLifecycleState.paused:
      case ui.AppLifecycleState.detached:
        pauseGame();
        music.pause();
    }
  }

  @override
  void onDispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ready) {
      transitions.clear();
      music.stop(fade: Duration.zero);
      unawaited(music.dispose());
      unawaited(sfx.dispose());
      filmFx.dispose();
      stage.dispose();
      transitions.dispose();
      _hudLayer.disposeItems();
    }
    sceneState.dispose();
    super.onDispose();
  }

  static void _log(String what, Object e) {
    if (kDebugMode) debugPrint('CinemaGame: $what failed: $e');
  }
}

/// The world of a [CinemaGame]: frozen while the game is loading or paused.
class CinemaWorld extends World with HasGameReference<CinemaGame> {
  CinemaWorld({super.children});

  @override
  void updateTree(double dt) {
    if (game.isWorldFrozen) return;
    super.updateTree(dt);
  }
}

/// Screen-space layer that delegates painting to an engine piece.
class _PaintLayer extends Component {
  _PaintLayer(this._paint);

  final void Function(ui.Canvas canvas) _paint;

  @override
  void render(ui.Canvas canvas) => _paint(canvas);
}

/// Full-screen catcher for taps and drags nobody else handled.
class _InputLayer extends PositionComponent with TapCallbacks, DragCallbacks, HasGameReference<CinemaGame> {
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.canvasPosition;
    game.onScreenTapDown(game.screenToWorld(ui.Offset(p.x, p.y)), ui.Offset(p.x, p.y));
  }

  @override
  void onTapUp(TapUpEvent event) {
    final p = event.canvasPosition;
    game.onScreenTapUp(game.screenToWorld(ui.Offset(p.x, p.y)), ui.Offset(p.x, p.y));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    final zoom = game.camera.viewfinder.zoom;
    final p = event.canvasEndPosition;
    game.onScreenDrag(event.canvasDelta / (zoom == 0 ? 1 : zoom), ui.Offset(p.x, p.y));
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.onScreenDragEnd();
  }
}

/// Lays out [HudItem]s in [HudSlot]s inside the stage's HUD rect and routes
/// taps to interactive items.
class HudLayer extends PositionComponent with TapCallbacks {
  HudLayer(this.game);

  final CinemaGame game;
  final List<_Placed> _items = [];
  ui.Rect _area = ui.Rect.zero;
  static const double _gap = 10;

  void place(HudSlot slot, HudItem item) {
    _items.add(_Placed(slot, item));
    relayout(_area);
  }

  void relayout(ui.Rect area) {
    _area = area;
    if (_items.isEmpty || area.isEmpty) return;
    final ctx = game.hudContext;
    final rtl = ctx.direction == ui.TextDirection.rtl;
    for (final slot in HudSlot.values) {
      var cursor = 0.0;
      var centreTotal = 0.0;
      if (slot == HudSlot.topCenter || slot == HudSlot.bottomCenter) {
        for (final p in _items) {
          if (p.slot == slot) centreTotal += p.item.layoutSize(ctx).width + _gap;
        }
        centreTotal -= _gap;
      }
      for (final p in _items) {
        if (p.slot != slot) continue;
        final size = p.item.layoutSize(ctx);
        p.size = size;
        final top = switch (slot) {
          HudSlot.topStart || HudSlot.topCenter || HudSlot.topEnd => area.top,
          _ => area.bottom - size.height,
        };
        final startSide = slot == HudSlot.topStart || slot == HudSlot.bottomStart;
        final endSide = slot == HudSlot.topEnd || slot == HudSlot.bottomEnd;
        double left;
        if (startSide || endSide) {
          final fromLeft = startSide != rtl;
          left = fromLeft ? area.left + cursor : area.right - cursor - size.width;
        } else {
          final origin = area.center.dx - centreTotal / 2;
          left = rtl ? origin + centreTotal - cursor - size.width : origin + cursor;
        }
        p.rect = ui.Rect.fromLTWH(left, top, size.width, size.height);
        cursor += size.width + _gap;
      }
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  void update(double dt) {
    final ctx = game.hudContext;
    var changed = false;
    for (final p in _items) {
      p.item.update(dt, ctx);
      if (p.item.layoutSize(ctx) != p.size) changed = true;
    }
    if (changed) relayout(_area);
  }

  @override
  void render(ui.Canvas canvas) {
    final ctx = game.hudContext;
    for (final p in _items) {
      p.item.paint(canvas, p.rect, ctx);
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    for (final p in _items) {
      if (p.item.interactive && p.rect.inflate(8).contains(ui.Offset(point.x, point.y))) return true;
    }
    return false;
  }

  @override
  void onTapDown(TapDownEvent event) {
    final o = ui.Offset(event.canvasPosition.x, event.canvasPosition.y);
    for (final p in _items.reversed) {
      if (p.item.interactive && p.rect.inflate(8).contains(o)) {
        if (p.item.onTap(o - p.rect.topLeft, game.hudContext)) return;
      }
    }
  }

  /// Rects of the placed items (tests, accessibility overlays).
  List<(HudSlot, ui.Rect)> get placements => [for (final p in _items) (p.slot, p.rect)];

  void disposeItems() {
    for (final p in _items) {
      p.item.dispose();
    }
    _items.clear();
  }
}

class _Placed {
  _Placed(this.slot, this.item);

  final HudSlot slot;
  final HudItem item;
  ui.Size size = ui.Size.zero;
  ui.Rect rect = ui.Rect.zero;
}
