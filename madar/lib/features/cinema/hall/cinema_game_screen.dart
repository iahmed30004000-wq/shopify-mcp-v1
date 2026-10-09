import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart' show MotionScope;
import '../../../core/sound/prayer_mute.dart';
import '../../saved_games/saved_games.dart' show GameOrientation, GameSessionPlatform, gameSessionPlatformProvider;
import '../engine/cinema_engine.dart';
import '../engine/stage/stage_kit.dart';
import '../games/catalog.dart';
import 'cinema_records.dart';

/// Plays one programme entry full screen.
///
/// * Immersive, portrait, screen kept on (the Saved Games session platform:
///   system bars hidden, `keepScreenOn` through the host channel) – restored
///   on leave.
/// * Scores and play statistics go to the hall's records
///   ([cinemaRecordsStoreProvider]); the HUD shows the best score.
/// * Leaving: the pause plate (top reading corner) opens the Intermission,
///   whose card offers "leave the game"; Android back opens the
///   Intermission too, and a second back leaves after a confirm. Every exit
///   path runs through [dispose], which gives the phone back its
///   orientation, its system bars and its screen timeout.
/// * Lifecycle: backgrounding pauses (CinemaGame); when something opaque
///   covers the game – a pushed page or the adhan (AdhanHost turns tickers
///   off beneath it) – the show pauses, its music stops and the engine
///   sleeps; uncovered, it waits in the intermission.
/// * Prayer mute (games auto-mute during the adhan and prayer) is wired by
///   CinemaGameView; this screen shows a small "sound paused for prayer"
///   badge while it lasts.
/// * An id that is unknown or not playable yet opens a "not open yet" stage
///   with the curtains drawn.
class CinemaGameScreen extends ConsumerStatefulWidget {
  const CinemaGameScreen({super.key, required this.gameId, this.entry, this.kit, this.skipOpening = false});

  /// Catalog id (`games/<id>/`).
  final String gameId;

  /// Overrides the catalog lookup (tests, previews).
  final GameCatalogEntry? entry;

  /// Overrides the engine kit (tests).
  final CinemaKit? kit;
  final bool skipOpening;

  /// Opens [gameId] through an iris.
  static Route<void> route(String gameId, {GameCatalogEntry? entry, Offset? origin}) => PageRouteBuilder<void>(
    settings: RouteSettings(name: '/cinema/$gameId'),
    opaque: true,
    transitionDuration: const Duration(milliseconds: 560),
    reverseTransitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, animation, secondary) => CinemaGameScreen(gameId: gameId, entry: entry),
    transitionsBuilder: (context, animation, secondary, child) =>
        IrisRouteTransition(animation: animation, origin: origin, child: child),
  );

  @override
  ConsumerState<CinemaGameScreen> createState() => _CinemaGameScreenState();
}

class _CinemaGameScreenState extends ConsumerState<CinemaGameScreen> {
  CinemaGame? _game;
  int? _best;
  ValueListenable<TickerModeData>? _tickers;
  bool _covered = false;
  PrayerMuteController? _mute;
  bool _muted = false;
  bool _muteExpanded = false;
  Timer? _muteTimer;
  GameSessionPlatform? _session;
  bool _entered = false;

  GameCatalogEntry? get _entry => widget.entry ?? CinemaCatalog.byId(widget.gameId);
  bool get _playable => _entry?.isPlayable ?? false;

  CinemaRecordsStore? get _store {
    try {
      return ref.read(cinemaRecordsStoreProvider);
    } catch (_) {
      return null; // no database (previews, tests without overrides)
    }
  }

  @override
  void initState() {
    super.initState();
    if (_playable) {
      _enterSession();
      final store = _store;
      if (store != null) {
        unawaited(
          store.best(widget.gameId).then((b) {
            _best = b;
            _game?.hud.best = b;
          }, onError: (Object _) {}),
        );
      }
    }
  }

  void _enterSession() {
    try {
      _session = ref.read(gameSessionPlatformProvider);
      _entered = true;
      unawaited(_session!.enter(GameOrientation.portrait).catchError((Object _) {}));
    } catch (_) {
      _session = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickers = TickerMode.getValuesNotifier(context);
    if (!identical(tickers, _tickers)) {
      _tickers?.removeListener(_onTickers);
      _tickers = tickers..addListener(_onTickers);
    }
    if (_mute == null) {
      try {
        final mute = ref.read(prayerMuteProvider);
        _mute = mute;
        mute.addListener(_onMute);
        _muted = mute.muted;
        _muteExpanded = _muted;
      } catch (_) {
        _mute = null;
      }
    }
  }

  void _onTickers() {
    if (_tickers?.value.enabled ?? true) {
      _uncover();
    } else {
      _cover();
    }
  }

  /// Something opaque covers the game (adhan, a pushed page).
  void _cover() {
    final game = _game;
    if (game == null || _covered || !game.isLoaded) return;
    _covered = true;
    game.pauseGame();
    game.music.pause();
    game.pauseEngine();
  }

  void _uncover() {
    final game = _game;
    if (game == null || !_covered) return;
    _covered = false;
    game.resumeEngine();
    game.music.resume();
    if (_entered) unawaited(_session?.reassert().catchError((Object _) {}));
  }

  void _onMute() {
    final muted = _mute?.muted ?? false;
    if (muted == _muted || !mounted) return;
    setState(() {
      _muted = muted;
      _muteExpanded = muted;
    });
    _muteTimer?.cancel();
    if (muted) {
      _muteTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _muteExpanded = false);
      });
    }
  }

  CinemaGame _build(CinemaGameBuilder builder, CinemaContext context) {
    final game = builder(context);
    game.hud.best = _best;
    _game = game;
    _covered = false;
    return game;
  }

  void _exit() {
    if (mounted) unawaited(Navigator.of(context).maybePop());
  }

  /// Android back from the Intermission: ask, so one stray back never
  /// throws a run away. The Intermission's own "leave the game" button is
  /// deliberate and leaves without asking.
  Future<bool> _confirmLeave() async {
    if (!mounted) return false;
    final l10n = L10n.of(context);
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cinemaExitConfirmTitle),
        content: Text(l10n.cinemaExitConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cinemaExitStay)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.cinemaExitGame)),
        ],
      ),
    );
    return answer ?? false;
  }

  @override
  void dispose() {
    _tickers?.removeListener(_onTickers);
    _mute?.removeListener(_onMute);
    _muteTimer?.cancel();
    if (_entered) unawaited(_session?.exit().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null || !entry.isPlayable) return NotOpenYetStage(entry: entry);
    final builder = entry.builder!;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CinemaGameView(
            builder: (ctx) => _build(builder, ctx),
            kit: widget.kit,
            scoreSink: _store,
            skipOpening: widget.skipOpening,
            onExit: _exit,
            confirmLeave: _confirmLeave,
          ),
          if (_muted)
            PositionedDirectional(
              start: 14,
              bottom: pad.bottom + 64,
              child: _PrayerBadge(expanded: _muteExpanded),
            ),
        ],
      ),
    );
  }
}

/// "Sound paused for prayer": a small plaque, collapsing to a moon.
class _PrayerBadge extends StatelessWidget {
  const _PrayerBadge({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    const gold = Color(0xFFE8C77A);
    return Semantics(
      liveRegion: true,
      label: l10n.cinemaHallPrayerMuted,
      child: ExcludeSemantics(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 8, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xE0140C08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gold.withValues(alpha: 0.8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nightlight_round, size: 16, color: gold),
                if (expanded) ...[
                  const SizedBox(width: 6),
                  Text(
                    l10n.cinemaHallPrayerMuted,
                    style: const TextStyle(fontFamily: 'PlexArabic', fontSize: 13, color: gold, height: 1.2),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The page shown for an id that is announced but not playable (or not in
/// the programme at all): the entry's era theatre with the curtains drawn,
/// its title card and a way back to the lobby.
class NotOpenYetStage extends StatefulWidget {
  const NotOpenYetStage({super.key, this.entry});

  final GameCatalogEntry? entry;

  @override
  State<NotOpenYetStage> createState() => _NotOpenYetStageState();
}

class _NotOpenYetStageState extends State<NotOpenYetStage> with SingleTickerProviderStateMixin {
  late final EraSkin _skin = EraSkins.of(widget.entry?.era ?? Era.rubberHose);
  late final ReelStage _stage = ReelStage(CinemaEnv(skin: _skin));
  late final FilmClock _clock = FilmClock(boilFps: _skin.ink.boilFps, projectionFps: _skin.grade.projectionFps);
  final _Repaint _repaint = _Repaint();
  Ticker? _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    unawaited(CinemaShaders.preload());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MotionScope.reducedOf(context);
    if (!reduced && _ticker == null) {
      _ticker = createTicker(_tick)..start();
    } else if (reduced && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  void _tick(Duration now) {
    final dt = math.min(1 / 20, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _clock.advance(dt);
    _stage.update(dt, _clock);
    _repaint.ping();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _stage.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final entry = widget.entry;
    final m = StageMaterials.of(_skin);
    final font = _skin.titles.fontFamily;
    final dark = _skin.titles.frame == TitleFrame.plain || _skin.titles.frame == TitleFrame.osd;
    final cardColor = dark ? const Color(0xF0141014) : m.paper;
    final ink = dark ? m.paper : m.ink;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _StagePainter(_stage, _clock, MediaQuery.paddingOf(context), _repaint)),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: dark ? m.gilt : m.ink, width: 3),
                    boxShadow: [BoxShadow(color: m.ink.withValues(alpha: 0.8), offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry != null) ...[
                        Text(
                          entry.title(l10n),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: font,
                            fontSize: 30,
                            fontWeight: _skin.titles.weight,
                            color: ink,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.era.label(l10n),
                          style: TextStyle(fontFamily: 'PlexArabic', fontSize: 13, color: ink.withValues(alpha: 0.65)),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Text(
                        entry == null ? l10n.cinemaHallNotFound : l10n.cinemaHallComingSoonTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: font, fontSize: 20, fontWeight: FontWeight.w700, color: ink),
                      ),
                      if (entry != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.cinemaHallComingSoonBody,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlexArabic',
                            fontSize: 15,
                            height: 1.45,
                            color: ink.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(l10n.cinemaHallBackToLobby),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ink,
                          side: BorderSide(color: ink, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          textStyle: TextStyle(fontFamily: font, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Repaint extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _StagePainter extends CustomPainter {
  _StagePainter(this.stage, this.clock, this.safe, Listenable repaint) : super(repaint: repaint);

  final ReelStage stage;
  final FilmClock clock;
  final EdgeInsets safe;
  Size _laidOut = Size.zero;

  @override
  void paint(Canvas canvas, Size size) {
    if (size != stage.measurements?.screen || size != _laidOut) {
      _laidOut = size;
      stage.layout(size, safe);
      if (clock.tick == 0) {
        clock.advance(1 / 60);
        stage.update(1 / 60, clock);
      }
    }
    stage
      ..paintBack(canvas)
      ..paintFront(canvas);
  }

  @override
  bool shouldRepaint(covariant _StagePainter old) => old.stage != stage || old.safe != safe;
}

/// Opens a page through an iris (a circle growing from [origin]); a plain
/// fade under reduced motion.
class IrisRouteTransition extends StatelessWidget {
  const IrisRouteTransition({super.key, required this.animation, required this.child, this.origin});

  final Animation<double> animation;
  final Widget child;
  final Offset? origin;

  @override
  Widget build(BuildContext context) {
    if (MotionScope.reducedOf(context)) return FadeTransition(opacity: animation, child: child);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = Curves.easeInOutCubic.transform(animation.value);
        if (t >= 1) return child!;
        return ColoredBox(
          color: Colors.black,
          child: ClipPath(clipper: _IrisClipper(t, origin), child: child),
        );
      },
    );
  }
}

class _IrisClipper extends CustomClipper<Path> {
  _IrisClipper(this.t, this.origin);

  final double t;
  final Offset? origin;

  @override
  Path getClip(Size size) {
    final c = origin ?? size.center(Offset.zero);
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((p) => (p - c).distance).reduce(math.max);
    return Path()..addOval(Rect.fromCircle(center: c, radius: far * t));
  }

  @override
  bool shouldReclip(covariant _IrisClipper old) => old.t != t || old.origin != origin;
}
