import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/painters/painters.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/together_providers.dart';
import '../../domain/play_modes.dart';
import '../../domain/player_profile.dart';
import '../together_texts.dart';
import '../widgets/together_visuals.dart';

/// What the pass-and-play gate is showing.
enum HandOffPhase {
  /// "Pass the phone to …": nothing private is built.
  handOff,

  /// The viewer's private view (cards, answers) is on screen.
  revealed,

  /// The app went to the background mid-turn: hidden again until the viewer
  /// confirms it is still them.
  shielded,
}

/// Who may see private information right now, on a shared phone.
///
/// Drive it from the game ([passTo] after each turn) or let it [follow] a
/// session's `activeParticipant`.
class HandOffController extends ChangeNotifier {
  HandOffController({int? viewer}) {
    _viewer = viewer;
  }

  int? _viewer;
  HandOffPhase _phase = HandOffPhase.handOff;
  int _reveals = 0;
  ValueListenable<int?>? _followed;

  /// The participant whose private view the gate builds once revealed.
  int? get viewer => _viewer;

  HandOffPhase get phase => _phase;

  /// Whether private content may be built.
  bool get isRevealed => _phase == HandOffPhase.revealed && _viewer != null;

  /// Increments at every reveal (keys the private view's entrance).
  int get reveals => _reveals;

  /// Hides everything and asks for the phone to be passed to [participant].
  /// Passing to the viewer who already sees their view changes nothing.
  void passTo(int participant) {
    if (_viewer == participant && _phase == HandOffPhase.revealed) return;
    _viewer = participant;
    _phase = HandOffPhase.handOff;
    notifyListeners();
  }

  /// The viewer tapped "reveal".
  void reveal() {
    if (_viewer == null || _phase == HandOffPhase.revealed) return;
    _phase = HandOffPhase.revealed;
    _reveals++;
    notifyListeners();
  }

  /// Hides the private view (the app left the foreground).
  void shield() {
    if (_phase != HandOffPhase.revealed) return;
    _phase = HandOffPhase.shielded;
    notifyListeners();
  }

  /// Hides everything with no one to pass to (between rounds, game over).
  void hideAll() {
    if (_phase == HandOffPhase.handOff && _viewer == null) return;
    _viewer = null;
    _phase = HandOffPhase.handOff;
    notifyListeners();
  }

  /// Follows [active] (a session's `activeParticipant`): every change of
  /// participant asks for a hand-off.
  void follow(ValueListenable<int?> active) {
    _followed?.removeListener(_onFollowed);
    _followed = active..addListener(_onFollowed);
    _onFollowed();
  }

  void _onFollowed() {
    final p = _followed?.value;
    if (p != null) passTo(p);
  }

  @override
  void dispose() {
    _followed?.removeListener(_onFollowed);
    super.dispose();
  }
}

/// Keeps the screen out of the Android recents thumbnail and screenshots
/// while [child] is mounted (FLAG_SECURE through
/// [togetherSecureScreenProvider]; reference-counted, and only when the
/// "hide from recent apps" setting is on).
class TogetherPrivateSurface extends ConsumerStatefulWidget {
  const TogetherPrivateSurface({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  ConsumerState<TogetherPrivateSurface> createState() => _TogetherPrivateSurfaceState();
}

class _TogetherPrivateSurfaceState extends ConsumerState<TogetherPrivateSurface> {
  static final Map<SecureScreenHook, int> _leases = {};
  SecureScreenHook? _held;

  static void _acquire(SecureScreenHook hook) {
    final n = (_leases[hook] ?? 0) + 1;
    _leases[hook] = n;
    if (n == 1) unawaited(hook.setSecure(true));
  }

  static void _release(SecureScreenHook hook) {
    final n = (_leases[hook] ?? 1) - 1;
    if (n <= 0) {
      _leases.remove(hook);
      unawaited(hook.setSecure(false));
    } else {
      _leases[hook] = n;
    }
  }

  void _sync(bool wanted) {
    final hook = ref.read(togetherSecureScreenProvider);
    if (_held != null && (!wanted || _held != hook)) {
      _release(_held!);
      _held = null;
    }
    if (wanted && _held == null) {
      _acquire(hook);
      _held = hook;
    }
  }

  bool get _wanted =>
      widget.enabled && (ref.read(togetherSettingsProvider).value ?? const TogetherSettings()).hideInRecents;

  @override
  void initState() {
    super.initState();
    _sync(_wanted);
  }

  @override
  void didUpdateWidget(TogetherPrivateSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _sync(_wanted);
  }

  @override
  void dispose() {
    final held = _held;
    if (held != null) _release(held);
    _held = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(togetherSettingsProvider, (_, _) => _sync(_wanted));
    return widget.child;
  }
}

/// Pass-and-play gate. Builds [privateBuilder] for the current viewer only
/// once they tapped "reveal"; until then – and whenever the app leaves the
/// foreground – only the hand-off screen exists: private widgets are not in
/// the tree at all (not merely covered). The whole gate keeps the window
/// out of the recents thumbnail.
class HandOffGate extends ConsumerStatefulWidget {
  const HandOffGate({
    super.key,
    required this.controller,
    required this.profileOf,
    required this.privateBuilder,
    this.publicSummary,
    this.secure = true,
  });

  final HandOffController controller;

  /// The profile of a participant (usually `profiles.of(session.slotOf(p))`).
  final TogetherProfile Function(int participant) profileOf;

  /// The viewer's private view.
  final Widget Function(BuildContext context, int participant) privateBuilder;

  /// Public information shown on the hand-off screen (e.g. the last move).
  final String? publicSummary;

  /// Hide from recents while the gate is up.
  final bool secure;

  @override
  ConsumerState<HandOffGate> createState() => _HandOffGateState();
}

class _HandOffGateState extends ConsumerState<HandOffGate> with WidgetsBindingObserver {
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(HandOffGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (!foreground) widget.controller.shield();
    if (foreground != _foreground) setState(() => _foreground = foreground);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final viewer = c.viewer;
    final Widget body;
    if (viewer != null && c.isRevealed && _foreground) {
      body = _RevealIn(key: ValueKey('reveal-${c.reveals}'), child: widget.privateBuilder(context, viewer));
    } else if (viewer == null || !_foreground) {
      body = const _BlankShield(key: ValueKey('together-shield'));
    } else {
      body = HandOffScreen(
        key: ValueKey('handoff-$viewer-${c.phase.name}'),
        profile: widget.profileOf(viewer),
        stillYou: c.phase == HandOffPhase.shielded,
        publicSummary: widget.publicSummary,
        onReveal: c.reveal,
      );
    }
    return TogetherPrivateSurface(enabled: widget.secure, child: body);
  }
}

/// Fades the private view in (a plain fade under reduced motion).
class _RevealIn extends StatelessWidget {
  const _RevealIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduced = context.reducedMotion;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.decelerate,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: reduced ? child : Transform.scale(scale: 0.97 + 0.03 * v, child: child),
      ),
      child: child,
    );
  }
}

/// What the gate shows while the app is not in the foreground.
class _BlankShield extends StatelessWidget {
  const _BlankShield({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.tokens.space0,
    child: const SizedBox.expand(),
  );
}

/// "Pass the phone to …" (مرّر الهاتف إلى …) in the next player's colour
/// with their avatar, and a big "I'm … — reveal" button. [stillYou] asks the
/// same player to confirm after the app was in the background.
class HandOffScreen extends StatefulWidget {
  const HandOffScreen({
    super.key,
    required this.profile,
    required this.onReveal,
    this.stillYou = false,
    this.publicSummary,
  });

  final TogetherProfile profile;
  final VoidCallback onReveal;
  final bool stillYou;
  final String? publicSummary;

  @override
  State<HandOffScreen> createState() => _HandOffScreenState();
}

class _HandOffScreenState extends State<HandOffScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 90));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Fx.fire(Sfx.swipe);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = AmbientMotion.enabled && !context.reducedMotion && TickerMode.valuesOf(context).enabled;
    if (animate && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!animate && _spin.isAnimating) {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final color = TogetherLook.colorOf(widget.profile);
    final name = tx.rawName(widget.profile);
    final title = tx.title(widget.profile);
    final size = MediaQuery.sizeOf(context);
    final rosette = math.min(size.width, size.height) * 1.15;
    final reduced = context.reducedMotion;

    Widget stagger(int i, Widget child) => reduced
        ? child
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MadarMotion.long + Duration(milliseconds: 70 * i),
            curve: Interval(math.min(0.5, i * 0.12), 1, curve: MadarMotion.decelerate),
            builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
            ),
            child: child,
          );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.space0,
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 1.05,
            colors: [
              Color.lerp(color, t.space0, t.isDark ? 0.45 : 0.25)!.withValues(alpha: t.isDark ? 1 : 0.55),
              Color.lerp(color, t.space0, 0.82)!,
              t.space0,
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Slowly turning rosette in the player's colour.
            Positioned(
              top: size.height * 0.34 - rosette / 2,
              left: (size.width - rosette) / 2,
              width: rosette,
              height: rosette,
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _spin,
                  builder: (context, _) => CustomPaint(
                    painter: GirihRosettePainter(
                      folds: 12,
                      strandColor: Color.lerp(color, Colors.white, 0.2)!.withValues(alpha: t.isDark ? 0.16 : 0.22),
                      ringColor: t.metalGold.withValues(alpha: 0.18),
                      rotation: _spin.value * math.pi * 2,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.xl, Space.xl, Space.l),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    stagger(
                      0,
                      Text(
                        widget.stillYou ? l.togetherShieldHint : l.togetherPassTo,
                        style: text.titleMedium?.copyWith(color: t.textSecondary, letterSpacing: tx.arabic ? 0 : 1.2),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    stagger(
                      1,
                      TogetherAvatarView(profile: widget.profile, displayName: name, size: 132, glow: true),
                    ),
                    const SizedBox(height: Space.l),
                    stagger(
                      2,
                      Semantics(
                        header: true,
                        child: Text(
                          widget.stillYou ? l.togetherStillYou(tx.name(widget.profile)) : name,
                          style: text.displaySmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (title != null && !widget.stillYou) ...[
                      const SizedBox(height: Space.xs),
                      stagger(
                        2,
                        Text(title, style: text.titleSmall?.copyWith(color: t.gold), textAlign: TextAlign.center),
                      ),
                    ],
                    const SizedBox(height: Space.l),
                    stagger(
                      3,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_off_rounded, size: 18, color: t.textTertiary),
                          const SizedBox(width: Space.s),
                          Flexible(
                            child: Text(
                              l.togetherNoPeeking,
                              style: text.bodyMedium?.copyWith(color: t.textTertiary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.publicSummary != null && !widget.stillYou) ...[
                      const SizedBox(height: Space.l),
                      stagger(
                        4,
                        GlassCard(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l, vertical: Space.m),
                          child: Text(
                            l.togetherLastMove(widget.publicSummary!),
                            style: text.bodyMedium?.copyWith(color: t.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(flex: 3),
                    stagger(
                      5,
                      Text(
                        l.togetherHandOffHint,
                        style: text.bodySmall?.copyWith(color: t.textTertiary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: Space.m),
                    stagger(
                      5,
                      MadarButton(
                        key: const ValueKey('together-reveal'),
                        label: widget.stillYou ? l.togetherContinue : l.togetherReveal(tx.name(widget.profile)),
                        icon: Icons.visibility_rounded,
                        size: MadarButtonSize.large,
                        expand: true,
                        sfx: Sfx.toggleOn,
                        onPressed: widget.onReveal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A convenience for pass-and-play games that follow a session: a gate with
/// its own controller following [activeParticipant].
class FollowingHandOffGate extends StatefulWidget {
  const FollowingHandOffGate({
    super.key,
    required this.activeParticipant,
    required this.profileOf,
    required this.privateBuilder,
    this.publicSummary,
  });

  final ValueListenable<int?> activeParticipant;
  final TogetherProfile Function(int participant) profileOf;
  final Widget Function(BuildContext context, int participant) privateBuilder;
  final String? publicSummary;

  @override
  State<FollowingHandOffGate> createState() => _FollowingHandOffGateState();
}

class _FollowingHandOffGateState extends State<FollowingHandOffGate> {
  final HandOffController _controller = HandOffController();

  @override
  void initState() {
    super.initState();
    _controller.follow(widget.activeParticipant);
  }

  @override
  void didUpdateWidget(FollowingHandOffGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeParticipant != widget.activeParticipant) _controller.follow(widget.activeParticipant);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HandOffGate(
    controller: _controller,
    profileOf: widget.profileOf,
    privateBuilder: widget.privateBuilder,
    publicSummary: widget.publicSummary,
  );
}

/// The mode a session would use for the gate's secure flag (exported for the
/// lead: pass-and-play needs it, split-screen doesn't).
bool togetherModeNeedsHandOff(PlayMode mode) => mode == PlayMode.passAndPlay;
