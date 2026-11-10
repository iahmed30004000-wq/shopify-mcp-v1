import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/motion/motion.dart';
import '../../../core/sound/prayer_mute.dart';
import '../../../core/sound/sound_api.dart';
import '../data/game_platform.dart';
import '../data/saved_games_providers.dart';
import '../domain/game_url.dart';
import '../domain/saved_web_game.dart';
import '../player/game_player_controller.dart';
import 'game_art.dart';
import 'saved_games_ui.dart';

/// Plays a saved web game full screen from its ORIGINAL link: immersive
/// (system bars hidden), screen kept on, the game's orientation, a small
/// floating control, Android back asks before leaving, and the app's prayer
/// mute silences the game.
class SavedGamePlayerScreen extends ConsumerStatefulWidget {
  const SavedGamePlayerScreen({super.key, required this.game, this.createWebView});

  final SavedWebGame game;

  /// Tests inject a controller built on a fake platform.
  @visibleForTesting
  final WebViewController Function()? createWebView;

  /// The route (fade; no swipe or drag can dismiss it).
  static Route<void> route(SavedWebGame game) => PageRouteBuilder<void>(
    settings: RouteSettings(name: 'savedGame:${game.id}'),
    opaque: true,
    transitionDuration: MadarMotion.medium,
    reverseTransitionDuration: MadarMotion.short,
    pageBuilder: (context, animation, secondaryAnimation) => SavedGamePlayerScreen(game: game),
    transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: MadarMotion.standard),
      child: child,
    ),
  );

  @override
  ConsumerState<SavedGamePlayerScreen> createState() => _SavedGamePlayerScreenState();
}

class _SavedGamePlayerScreenState extends ConsumerState<SavedGamePlayerScreen>
    with WidgetsBindingObserver
    implements GamePageDialogs {
  late final GamePlayerController _game;
  late final GameSessionPlatform _platform = ref.read(gameSessionPlatformProvider);
  PrayerMuteController? _mute;
  bool _leaving = false;
  bool _sealedNoted = false;

  /// Something opaque covers the player: a page pushed over it, or the
  /// adhan (AdhanHost stops the tickers of the app beneath it). The phone
  /// then gets Madar's normal screen back and the game is hushed.
  bool _covered = false;
  bool _away = false;
  int _shownGeneration = 0;

  SavedWebGame get _record => widget.game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final store = ref.read(savedWebGamesStoreProvider);
    _game = GamePlayerController(
      game: _record,
      dialogs: this,
      platform: _platform,
      onExternalRequest: _askExternal,
      onCleared: () async {
        await store.setClearDataPending(_record.id, false);
        if (mounted) showGameNote(context, L10n.of(context).savedGamesClearDataDone);
      },
      createWebView: widget.createWebView,
    )..addListener(_onGameChanged);
    unawaited(_platform.enter(_record.orientation));
    unawaited(_game.start(clearFirst: _record.clearDataPending));
    unawaited(store.markPlayed(_record.id, ref.read(savedGamesClockProvider)()));
    try {
      final mute = ref.read(prayerMuteProvider)..addListener(_onPrayerMute);
      _mute = mute;
      if (mute.muted) unawaited(_game.setPrayerMuted(true));
    } on Object {
      _mute = null; // no sound service wired (previews)
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final covered = !TickerMode.valuesOf(context).enabled;
    if (covered == _covered) return;
    _covered = covered;
    if (covered) {
      unawaited(_platform.exit());
    } else {
      unawaited(_platform.enter(_record.orientation));
    }
    unawaited(_game.setBackground(_covered || _away));
  }

  @override
  void dispose() {
    // First, whatever else fails: give the phone its normal screen back.
    unawaited(_platform.exit());
    WidgetsBinding.instance.removeObserver(this);
    _mute?.removeListener(_onPrayerMute);
    _game
      ..removeListener(_onGameChanged)
      ..dispose();
    super.dispose();
  }

  void _onPrayerMute() => unawaited(_game.setPrayerMuted(_mute?.muted ?? false));

  void _onGameChanged() {
    if (!mounted) return;
    if (_game.webGeneration != _shownGeneration) setState(() => _shownGeneration = _game.webGeneration);
    if (_game.sealedAudio && _game.userMuted && !_sealedNoted) {
      _sealedNoted = true;
      showGameNote(context, L10n.of(context).savedGamesMuteSealed);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached:
        _away = true;
        unawaited(_game.setBackground(true));
      case AppLifecycleState.resumed:
        _away = false;
        unawaited(_game.setBackground(_covered));
        // Android shows the bars again after a trip away; not while
        // something else covers the game.
        if (!_covered) unawaited(_platform.reassert());
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _confirmExit() async {
    if (_leaving) return;
    final l = L10n.of(context);
    // Nothing to lose on an error / loading screen.
    final lose = _game.phase == GamePhase.ready;
    final ok =
        !lose ||
        await showGameConfirm(
          context,
          title: l.savedGamesExitTitle,
          body: l.savedGamesExitBody,
          confirmLabel: l.savedGamesExitLeave,
          cancelLabel: l.savedGamesExitStay,
          icon: Icons.logout_rounded,
        );
    if (!ok || !mounted) return;
    _leave();
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    Fx.fire(Sfx.back);
    Navigator.of(context).pop();
  }

  Future<void> _askExternal(Uri url) async {
    if (!mounted) return;
    final l = L10n.of(context);
    final ok = await showGameConfirm(
      context,
      title: l.savedGamesExternalTitle,
      body: l.savedGamesExternalBody(BidiIsolate.ltr(displayHost(url))),
      confirmLabel: l.savedGamesOpenExternal,
      cancelLabel: l.savedGamesCancel,
      icon: Icons.open_in_new_rounded,
    );
    if (!ok || !mounted) return;
    final opened = await ref.read(gameLinkOpenerProvider).openExternally(url);
    if (!opened && mounted) showGameNote(context, l.savedGamesExternalFailed);
  }

  Future<void> _openExternally() async {
    final opened = await ref.read(gameLinkOpenerProvider).openExternally(_record.url);
    if (!opened && mounted) showGameNote(context, L10n.of(context).savedGamesExternalFailed);
  }

  Future<void> _clearData() async {
    final l = L10n.of(context);
    final ok = await showGameConfirm(
      context,
      title: l.savedGamesClearDataTitle(BidiIsolate.isolate(_record.title)),
      body: l.savedGamesClearDataBody,
      confirmLabel: l.savedGamesConfirmClear,
      cancelLabel: l.savedGamesCancel,
      icon: Icons.cleaning_services_rounded,
      danger: true,
    );
    // "Cleared" is shown when the clear has finished (onCleared).
    if (ok && mounted) await _game.clearSiteData();
  }

  // ── GamePageDialogs ─────────────────────────────────────────────────────

  @override
  Future<void> alert(String host, String message) async {
    if (!mounted) return;
    final l = L10n.of(context);
    await showInteractionSheet<void>(
      context,
      builder: (context) => InteractionSheetFrame(
        title: l.savedGamesPageSays(BidiIsolate.ltr(host)),
        icon: Icons.chat_bubble_outline_rounded,
        body: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        footer: SheetButton(label: l.savedGamesOk, primary: true, onPressed: () => Navigator.of(context).pop()),
      ),
    );
  }

  @override
  Future<bool> confirm(String host, String message) async {
    if (!mounted) return false;
    final l = L10n.of(context);
    return showGameConfirm(
      context,
      title: l.savedGamesPageSays(BidiIsolate.ltr(host)),
      body: message,
      confirmLabel: l.savedGamesOk,
      cancelLabel: l.savedGamesCancel,
      icon: Icons.chat_bubble_outline_rounded,
    );
  }

  @override
  Future<String?> prompt(String host, String message, String? defaultText) async {
    if (!mounted) return null;
    final l = L10n.of(context);
    final controller = TextEditingController(text: defaultText ?? '');
    try {
      return await showInteractionSheet<String>(
        context,
        builder: (context) => InteractionSheetFrame(
          title: l.savedGamesPageSays(BidiIsolate.ltr(host)),
          icon: Icons.chat_bubble_outline_rounded,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: Space.m),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 200,
                decoration: kitInputDecoration(context),
              ),
            ],
          ),
          footer: Row(
            children: [
              Expanded(
                child: SheetButton(
                  label: l.savedGamesCancel,
                  sfx: Sfx.back,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: SheetButton(
                  label: l.savedGamesOk,
                  primary: true,
                  onPressed: () => Navigator.of(context).pop(controller.text),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              WebViewWidget(
                // A fresh WebView after a renderer crash is a new platform view.
                key: ValueKey('savedGames.webView.$_shownGeneration'),
                controller: _game.web,
                // The game gets every gesture: nothing Flutter-side can turn
                // a pull-down into leaving the game.
                gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
              ),
              ListenableBuilder(
                listenable: _game,
                builder: (context, _) => _Veils(
                  game: _record,
                  controller: _game,
                  onRetry: () => unawaited(_game.retry()),
                  onBack: _leave,
                  onOpenExternally: _openExternally,
                ),
              ),
              ListenableBuilder(
                listenable: _game,
                // Hidden under the prayer veil (it has its own way back;
                // nothing may reload a sounding page during prayer) and the
                // crash veil (its own Try again / Back; a dead page has no
                // data to clear).
                builder: (context, _) =>
                    _game.prayerHushed || _game.phase == GamePhase.resting || _game.phase == GamePhase.crashed
                    ? const SizedBox.shrink()
                    : _GameControl(
                        muted: _game.userMuted,
                        onBack: () => unawaited(_confirmExit()),
                        onReload: () => unawaited(_game.retry()),
                        onOpenExternally: () => unawaited(_openExternally()),
                        onMute: () => unawaited(_game.setUserMuted(!_game.userMuted)),
                        onClearData: () => unawaited(_clearData()),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading, error and prayer screens over the game.
class _Veils extends StatelessWidget {
  const _Veils({
    required this.game,
    required this.controller,
    required this.onRetry,
    required this.onBack,
    required this.onOpenExternally,
  });

  final SavedWebGame game;
  final GamePlayerController controller;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final VoidCallback onOpenExternally;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final phase = controller.phase;
    final Widget veil;
    if (controller.prayerHushed || phase == GamePhase.resting) {
      veil = _MessageVeil(
        key: const ValueKey('prayer'),
        game: game,
        icon: Icons.mosque_rounded,
        title: l.savedGamesPrayerTitle,
        body: phase == GamePhase.resting ? l.savedGamesPrayerUnloaded : l.savedGamesPrayerBody,
        actions: [
          MadarButton(label: l.savedGamesBackToMadar, icon: Icons.home_rounded, onPressed: onBack, sfx: Sfx.back),
        ],
        prayer: true,
      );
    } else {
      veil = switch (phase) {
        GamePhase.loading || GamePhase.clearing => _LoadingVeil(
          key: const ValueKey('loading'),
          game: game,
          progress: controller.progress,
          label: phase == GamePhase.clearing
              ? l.savedGamesClearing
              : l.savedGamesLoading(BidiIsolate.isolate(game.title)),
        ),
        GamePhase.offline => _MessageVeil(
          key: const ValueKey('offline'),
          game: game,
          icon: Icons.wifi_off_rounded,
          title: l.savedGamesOfflineTitle,
          body: l.savedGamesOfflineBody,
          actions: _errorActions(l),
        ),
        GamePhase.failed => _MessageVeil(
          key: const ValueKey('failed'),
          game: game,
          icon: Icons.cloud_off_rounded,
          title: l.savedGamesErrorTitle,
          body: l.savedGamesErrorBody,
          actions: [
            ..._errorActions(l),
            MadarButton(
              label: l.savedGamesOpenExternal,
              icon: Icons.open_in_new_rounded,
              variant: MadarButtonVariant.ghost,
              onPressed: onOpenExternally,
            ),
          ],
        ),
        GamePhase.crashed => _MessageVeil(
          key: const ValueKey('crashed'),
          game: game,
          icon: Icons.memory_rounded,
          title: l.savedGamesCrashedTitle,
          body: l.savedGamesCrashedBody,
          actions: _errorActions(l),
        ),
        GamePhase.insecure => _MessageVeil(
          key: const ValueKey('insecure'),
          game: game,
          icon: Icons.gpp_bad_outlined,
          title: l.savedGamesInsecureTitle,
          body: l.savedGamesInsecureBody,
          actions: [
            MadarButton(label: l.savedGamesBackToMadar, icon: Icons.home_rounded, onPressed: onBack, sfx: Sfx.back),
          ],
        ),
        GamePhase.ready || GamePhase.resting => const SizedBox.shrink(key: ValueKey('none')),
      };
    }
    return AnimatedSwitcher(
      duration: context.motion(MadarMotion.medium),
      switchInCurve: MadarMotion.decelerate,
      switchOutCurve: MadarMotion.accelerate,
      child: veil,
    );
  }

  List<Widget> _errorActions(L10n l) => [
    MadarButton(label: l.savedGamesRetry, icon: Icons.refresh_rounded, onPressed: onRetry),
    MadarButton(
      label: l.savedGamesBackToMadar,
      icon: Icons.home_rounded,
      variant: MadarButtonVariant.secondary,
      onPressed: onBack,
      sfx: Sfx.back,
    ),
  ];
}

/// The game's colours, full screen, behind veils.
class _VeilBackdrop extends StatelessWidget {
  const _VeilBackdrop({required this.game, required this.child});

  final SavedWebGame game;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = GameArtPalette.colors(game.art.hue);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.35),
          radius: 1.2,
          colors: [colors.base, colors.deep, Colors.black],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class _LoadingVeil extends StatelessWidget {
  const _LoadingVeil({super.key, required this.game, required this.progress, required this.label});

  final SavedWebGame game;
  final int progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final colors = GameArtPalette.colors(game.art.hue);
    return _VeilBackdrop(
      game: game,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 132,
                height: 184,
                child: GamePoster(art: game.art, seed: game.id),
              ),
              const SizedBox(height: Space.xl),
              OrbitLoader(size: 36, color: colors.glow, secondaryColor: Colors.white, semanticLabel: label),
              const SizedBox(height: Space.l),
              Text(
                label,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: Space.s),
              Text(
                BidiIsolate.ltr(game.host),
                style: text.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: Space.l),
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress <= 0 ? null : progress / 100,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(t.isDark ? t.gold : colors.glow),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageVeil extends StatelessWidget {
  const _MessageVeil({
    super.key,
    required this.game,
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    this.prayer = false,
  });

  final SavedWebGame game;
  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;
  final bool prayer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final content = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassPanel(
            shareBackdrop: false,
            padding: const EdgeInsetsDirectional.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [t.accentSoft, t.accent.withValues(alpha: 0.04)]),
                    border: Border.all(color: (prayer ? t.gold : t.accent).withValues(alpha: 0.6)),
                    boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 18)],
                  ),
                  child: Icon(icon, size: 30, color: prayer ? t.gold : t.accent),
                ),
                const SizedBox(height: Space.l),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(title, textAlign: TextAlign.center, style: text.headlineMedium),
                ),
                const SizedBox(height: Space.s),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: Space.xl),
                Wrap(alignment: WrapAlignment.center, spacing: Space.m, runSpacing: Space.m, children: actions),
              ],
            ),
          ),
        ),
      ),
    );
    if (prayer) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const CosmosBackdrop(intensity: 0.9),
          SafeArea(child: content),
        ],
      );
    }
    return _VeilBackdrop(game: game, child: content);
  }
}

/// The small floating control: a glass handle that opens Back / Reload /
/// Open in browser / Mute / Clear data. Drag it to another corner.
class _GameControl extends StatefulWidget {
  const _GameControl({
    required this.muted,
    required this.onBack,
    required this.onReload,
    required this.onOpenExternally,
    required this.onMute,
    required this.onClearData,
  });

  final bool muted;
  final VoidCallback onBack;
  final VoidCallback onReload;
  final VoidCallback onOpenExternally;
  final VoidCallback onMute;
  final VoidCallback onClearData;

  @override
  State<_GameControl> createState() => _GameControlState();
}

class _GameControlState extends State<_GameControl> {
  bool _open = false;
  bool _top = true;

  /// Physical side (set from the reading direction on first build: the
  /// handle starts at the reading start).
  bool? _left;
  Offset _drag = Offset.zero;
  Timer? _autoClose;

  static const double _handle = 44;
  static const double _margin = 12;

  @override
  void dispose() {
    _autoClose?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _autoClose?.cancel();
    // With TalkBack the tray stays until closed: exploring five buttons by
    // swiping takes longer than any timeout.
    if (_open && !MediaQuery.accessibleNavigationOf(context)) {
      _autoClose = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _open = false);
      });
    }
  }

  void _run(VoidCallback action) {
    _autoClose?.cancel();
    setState(() => _open = false);
    action();
  }

  void _dragEnd(Size size, EdgeInsets pad) {
    final left = _left ?? true;
    final x = (left ? pad.left + _margin : size.width - pad.right - _margin - _handle) + _drag.dx;
    final y = (_top ? pad.top + _margin : size.height - pad.bottom - _margin - _handle) + _drag.dy;
    setState(() {
      _left = x + _handle / 2 < size.width / 2;
      _top = y + _handle / 2 < size.height / 2;
      _drag = Offset.zero;
    });
    Fx.fire(Sfx.drop);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final dir = Directionality.of(context);
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.viewPaddingOf(context);
    final left = _left ??= dir == TextDirection.ltr;

    final handle = MadarPressable(
      key: const ValueKey('savedGames.control'),
      onTap: _toggle,
      semanticLabel: _open ? l.savedGamesCloseControls : l.savedGamesControls,
      focusRadius: BorderRadius.circular(99),
      child: _Bubble(
        size: _handle,
        child: Icon(_open ? Icons.close_rounded : Icons.more_horiz_rounded, color: t.textPrimary, size: 22),
      ),
    );

    // The tray always opens towards the middle of the screen; its buttons
    // keep the reading order.
    final tray = AnimatedSize(
      duration: context.motion(MadarMotion.short),
      curve: MadarMotion.emphasized,
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: !_open
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(left: left ? Space.s : 0, right: left ? 0 : Space.s),
              child: DecoratedBox(
                decoration: _glass(t, 99),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
                  child: Directionality(
                    textDirection: dir,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TrayButton(
                          icon: Icons.home_rounded,
                          label: l.savedGamesBackToMadar,
                          onTap: () => _run(widget.onBack),
                          sfx: null,
                        ),
                        _TrayButton(
                          icon: Icons.refresh_rounded,
                          label: l.savedGamesReload,
                          onTap: () => _run(widget.onReload),
                        ),
                        _TrayButton(
                          icon: widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          label: widget.muted ? l.savedGamesUnmute : l.savedGamesMute,
                          onTap: () => _run(widget.onMute),
                          sfx: widget.muted ? Sfx.toggleOn : Sfx.toggleOff,
                          active: widget.muted,
                        ),
                        _TrayButton(
                          icon: Icons.open_in_new_rounded,
                          label: l.savedGamesOpenExternal,
                          onTap: () => _run(widget.onOpenExternally),
                        ),
                        _TrayButton(
                          icon: Icons.cleaning_services_rounded,
                          label: l.savedGamesClearData,
                          onTap: () => _run(widget.onClearData),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );

    final row = Directionality(
      textDirection: left ? TextDirection.ltr : TextDirection.rtl,
      child: Row(mainAxisSize: MainAxisSize.min, children: [handle, tray]),
    );
    return Stack(
      children: [
        Positioned(
          top: _top ? pad.top + _margin + _drag.dy : null,
          bottom: _top ? null : pad.bottom + _margin - _drag.dy,
          left: left ? pad.left + _margin + _drag.dx : null,
          right: left ? null : pad.right + _margin - _drag.dx,
          child: GestureDetector(
            onPanStart: _open ? null : (_) => Fx.fire(Sfx.pickUp),
            onPanUpdate: _open ? null : (d) => setState(() => _drag += d.delta),
            onPanEnd: _open ? null : (_) => _dragEnd(size, pad),
            child: row,
          ),
        ),
      ],
    );
  }
}

BoxDecoration _glass(MadarTokens t, double radius) => BoxDecoration(
  color: t.space1.withValues(alpha: 0.78),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: t.gold.withValues(alpha: 0.45), width: 0.9),
  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))],
);

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: _glass(context.tokens, size / 2),
      child: child,
    );
  }
}

class _TrayButton extends StatelessWidget {
  const _TrayButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sfx = Sfx.tap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Sfx? sfx;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: label,
      // The button already says it; TalkBack would read it twice.
      excludeFromSemantics: true,
      child: MadarPressable(
        onTap: onTap,
        sfx: sfx,
        semanticLabel: label,
        toggled: active ? true : null,
        focusRadius: BorderRadius.circular(99),
        child: SizedBox.square(dimension: 44, child: Icon(icon, size: 21, color: active ? t.warning : t.textPrimary)),
      ),
    );
  }
}
