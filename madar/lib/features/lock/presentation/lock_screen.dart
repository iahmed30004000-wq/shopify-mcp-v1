import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../application/lock_controller.dart';
import '../data/biometric_auth.dart';
import '../domain/pin_hash.dart';
import '../render/assembly.dart';
import '../render/lock_astrolabe.dart';
import '../render/lock_astrolabe_painter.dart';
import 'lock_door.dart';
import 'lock_texts.dart';
import 'pin_pad.dart';

/// What the lock screen is showing.
enum LockScreenMode {
  /// The fingerprint face: the system prompt opens by itself as soon as the
  /// screen shows (and again on every return to the app) while the
  /// astrolabe assembles; after a cancel or an error a large "Use
  /// fingerprint" button asks again – so does holding the astrolabe.
  hold,

  /// The PIN keypad.
  pin,

  /// "Forgot PIN?": no remote reset; fingerprint → new PIN when possible.
  forgot,

  /// Choosing a new PIN after the fingerprint confirmed the owner.
  newPin,
}

/// Lets the gate route the system back button to the lock screen first.
class LockBackHandler {
  /// Returns true when the lock screen handled back (e.g. left the PIN pad).
  bool Function()? onBack;

  bool handle() => onBack?.call() ?? false;
}

/// The lock screen: the brass astrolabe assembles itself as the fingerprint
/// is read (or digit by digit as the PIN is typed), locks together with a
/// chime and golden sparks, and then opens like a double door into the app.
///
/// With fingerprint unlock on, the system prompt is requested by itself
/// right after the first frame – on a cold start and whenever the app
/// returns to the foreground to this screen – but only while the app is
/// really in the foreground (`resumed`), never twice at once, and never
/// again by itself after the owner cancelled it or it failed (no prompt
/// loop): then a large "Use fingerprint" button (or holding the astrolabe)
/// asks again and the PIN is one tap away. A locked-out sensor goes
/// straight to the PIN; PIN-only owners get the keypad at once.
///
/// Reads and drives [lockControllerProvider]; [reveal] reports the door's
/// progress (0 → 1) so the gate can zoom the app in behind it.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, this.reveal, this.backHandler, this.initialProgress});

  final ValueNotifier<double>? reveal;
  final LockBackHandler? backHandler;

  /// Starting assembly (screenshots / previews).
  @visibleForTesting
  final double? initialProgress;

  /// How long the owner holds the astrolabe before the fingerprint prompt
  /// opens (the optional gesture; the prompt also opens by itself).
  static const Duration holdDuration = Duration(milliseconds: 850);

  @override
  ConsumerState<LockScreen> createState() => LockScreenState();
}

enum _Stage { idle, holding, reading, done }

class LockScreenState extends ConsumerState<LockScreen> with TickerProviderStateMixin {
  late final AnimationController _assembly = AnimationController(vsync: this, value: widget.initialProgress ?? 0);
  late final AnimationController _ignite = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _scan = AnimationController(vsync: this, duration: MadarMotion.medium);
  late final AnimationController _error = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _door = AnimationController(vsync: this, duration: const Duration(milliseconds: 820));

  final GlobalKey _dialKey = GlobalKey();
  final GlobalKey _captureKey = GlobalKey();

  late LockScreenMode _mode;
  _Stage _stage = _Stage.idle;
  String _pin = '';
  String? _firstPin;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  bool _opening = false;
  ui.Image? _snapshot;
  Timer? _countdown;
  double _lastAssembly = 0;
  late final double _ruleAngle;
  late final AppLifecycleListener _lifecycle;

  /// A fingerprint prompt is owed: it opens by itself as soon as the app is
  /// in the foreground and the fingerprint face is idle. Owed when the
  /// screen appears and after the app was really left (stopped); cleared
  /// the moment any prompt starts – a cancelled or failed prompt never
  /// comes back by itself.
  bool _autoPrompt = false;

  /// The app was left (stopped) while a prompt was up.
  bool _leftWhilePrompting = false;

  LockScreenMode get mode => _mode;

  @override
  void initState() {
    super.initState();
    final lock = ref.read(lockControllerProvider);
    _mode = lock.biometrics ? LockScreenMode.hold : LockScreenMode.pin;
    if (_mode == LockScreenMode.pin && widget.initialProgress == null) _assembly.value = AssemblyTimeline.pinBase;
    _lastAssembly = _assembly.value;
    _assembly.addListener(_onAssembly);
    widget.reveal?.value = 0;
    _door.addListener(() => widget.reveal?.value = _door.value);
    _ruleAngle = LockAstrolabe.ruleAngleFor(ref.read(lockClockProvider)());
    widget.backHandler?.onBack = _handleBack;
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    // Previews (a fixed assembly) never prompt.
    _autoPrompt = _mode == LockScreenMode.hold && widget.initialProgress == null;
    _scheduleAutoPrompt();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.backHandler?.onBack = null;
    _countdown?.cancel();
    _assembly.dispose();
    _ignite.dispose();
    _scan.dispose();
    _error.dispose();
    _shake.dispose();
    _door.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  LockController get _lock => ref.read(lockControllerProvider.notifier);
  bool get _reduced => context.reducedMotion;
  Duration _d(Duration d) => _reduced ? MadarMotion.reduced : d;

  // ------------------------------------------------------------ assembly

  void _onAssembly() {
    final v = _assembly.value;
    if (_stage != _Stage.done) {
      for (final part in AssemblyTimeline.lockedBetween(_lastAssembly, v)) {
        if (part == AstrolabePart.hub) continue;
        Fx.fire(Sfx.countTick);
        if (part == AstrolabePart.limb || part == AstrolabePart.rete) _sparks(0.35);
      }
    }
    _lastAssembly = v;
  }

  TickerFuture _assembleTo(double target, {Duration? duration, Curve curve = Curves.easeOutCubic}) {
    final d = duration ?? Duration(milliseconds: (160 + 600 * (target - _assembly.value).abs()).round());
    return _assembly.animateTo(target, duration: _d(d), curve: curve);
  }

  void _sparks(double intensity, {CelebrationKind kind = CelebrationKind.lanternSparks}) {
    final box = _dialKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    Celebrate.burst(
      context,
      center,
      kind: kind,
      intensity: intensity,
      radius: box.size.shortestSide / 2 / LockAstrolabePainter.boxFactor,
    );
  }

  // ---------------------------------------------------------- auto prompt

  static bool get _foreground => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  /// The owed prompt is about to open: the screen already shows the
  /// "being read" state instead of flashing the button for a frame.
  bool get _awaitingPrompt =>
      _autoPrompt && _foreground && _bioUsable && _mode == LockScreenMode.hold && _stage == _Stage.idle;

  void _onLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Really left – not merely covered by the prompt, which only makes
        // the app inactive. Coming back is a new look at the lock screen.
        if (_stage == _Stage.reading) {
          _leftWhilePrompting = true;
        } else if (_mode == LockScreenMode.hold && _stage != _Stage.done) {
          _autoPrompt = true;
        }
      case AppLifecycleState.resumed:
        _scheduleAutoPrompt();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
    if (mounted) setState(() {});
  }

  /// Checks the owed prompt after the next frame (the first frame of the
  /// screen, or the one after a lifecycle / availability change).
  void _scheduleAutoPrompt() {
    if (!_autoPrompt) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPrompt());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _maybeAutoPrompt() {
    if (!mounted || !_autoPrompt) return;
    // Paused / inactive (a system dialog, the shade) / not yet known: stay
    // owed until `resumed`.
    if (!_foreground) return;
    if (_mode != LockScreenMode.hold || _stage != _Stage.idle || _busy || _opening) {
      // The owner already chose (the PIN, a hold in progress …).
      _autoPrompt = false;
      return;
    }
    // Wait for the availability check (its listener asks again), so a phone
    // without an enrolled finger goes straight to the PIN without a
    // pointless prompt.
    final availability = ref.read(biometricAvailabilityProvider);
    if (availability.isLoading && !availability.hasValue) return;
    _autoPrompt = false;
    if (!_bioUsable) return;
    unawaited(_startReading(feedback: false));
  }

  // ----------------------------------------------------------------- hold

  void _onHoldStart() {
    if (_mode != LockScreenMode.hold || _busy) return;
    if (_stage != _Stage.idle) return;
    setState(() {
      _stage = _Stage.holding;
      _message = null;
      _messageIsError = false;
    });
    Fx.fire(Sfx.pickUp, haptic: Haptic.light);
    final remaining = (AssemblyTimeline.holdTarget - _assembly.value).clamp(0.0, 1.0) / AssemblyTimeline.holdTarget;
    _assembly
        .animateTo(
          AssemblyTimeline.holdTarget,
          duration: _d(LockScreen.holdDuration * remaining),
          curve: Curves.easeInOutSine,
        )
        .then((_) {
          if (mounted && _stage == _Stage.holding) unawaited(_startReading());
        });
  }

  void _onHoldEnd() {
    if (_stage != _Stage.holding) return;
    setState(() {
      _stage = _Stage.idle;
      _message = L10n.of(context).lockReleasedEarly;
      _messageIsError = false;
    });
    Fx.fire(Sfx.drop);
    unawaited(_assembleTo(0, duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic));
  }

  /// Opens the system prompt while the astrolabe assembles ("being read").
  /// [feedback] marks the moment with a sound when nothing else did (the
  /// hold reaching half the dial); a button already sounded, and the
  /// automatic prompt stays quiet.
  Future<void> _startReading({bool feedback = true}) async {
    if (_stage == _Stage.reading || _stage == _Stage.done) return;
    _autoPrompt = false;
    _leftWhilePrompting = false;
    final l = L10n.of(context);
    final hasPin = ref.read(lockControllerProvider).hasPin;
    setState(() {
      _mode = LockScreenMode.hold;
      _stage = _Stage.reading;
      _message = l.lockReadingHint;
      _messageIsError = false;
    });
    if (feedback) Fx.fire(Sfx.navigate, haptic: Haptic.medium);
    unawaited(_scan.forward());
    unawaited(
      _assembleTo(
        AssemblyTimeline.readingTarget,
        duration: const Duration(milliseconds: 3200),
        curve: Curves.easeOutQuart,
      ),
    );
    final outcome = await _lock.authenticateWithBiometrics(LockTexts.unlockPrompt(l));
    if (!mounted) return;
    if (outcome == BiometricOutcome.success) {
      unawaited(_succeed());
      return;
    }
    unawaited(_scan.reverse());
    _stage = _Stage.idle;
    final message = LockTexts.biometricMessage(l, outcome);
    if (outcome == BiometricOutcome.notEnrolled || outcome == BiometricOutcome.noHardware) {
      ref.invalidate(biometricAvailabilityProvider);
    }
    // Locked out / no usable sensor: the PIN at once.
    if (hasPin && LockTexts.biometricBlocked(outcome)) {
      _enterPin(message: message, error: message != null);
      return;
    }
    // Cancelled or failed: stay on the fingerprint face; the big button
    // asks again – never the screen by itself (no prompt loop). Only when
    // the system dropped the prompt because the owner left the app does the
    // return ask again.
    if (_leftWhilePrompting && !_foreground) _autoPrompt = true;
    _leftWhilePrompting = false;
    if (message != null) Fx.fire(Sfx.error);
    setState(() {
      _message = message;
      _messageIsError = message != null;
    });
    unawaited(_assembleTo(0, duration: const Duration(milliseconds: 600)));
  }

  // ------------------------------------------------------------------ pin

  void _enterPin({String? message, bool error = false}) {
    _autoPrompt = false;
    setState(() {
      _mode = LockScreenMode.pin;
      _pin = '';
      _message = message;
      _messageIsError = error;
    });
    unawaited(_assembleTo(AssemblyTimeline.pinBase));
  }

  /// The keypad's fingerprint key or the big "Use fingerprint" button (they
  /// sound themselves).
  void _useFingerprint() {
    if (_stage == _Stage.reading || _stage == _Stage.done) return;
    setState(() {
      _mode = LockScreenMode.hold;
      _pin = '';
      _message = null;
    });
    unawaited(_startReading(feedback: false));
  }

  bool _lockedOut(AppLockState lock) {
    final until = lock.lockedUntil;
    return until != null && ref.read(lockClockProvider)().isBefore(until);
  }

  void _onDigit(int d) {
    final lock = ref.read(lockControllerProvider);
    if (_busy || _stage == _Stage.done || _lockedOut(lock)) return;
    switch (_mode) {
      case LockScreenMode.pin:
        if (_pin.length >= lock.pinLength) return;
        setState(() {
          _pin += '$d';
          _message = null;
          _messageIsError = false;
        });
        unawaited(
          _assembleTo(
            AssemblyTimeline.pinTarget(_pin.length, lock.pinLength),
            duration: const Duration(milliseconds: 300),
          ),
        );
        if (_pin.length == lock.pinLength) unawaited(_submitPin());
      case LockScreenMode.newPin:
        final target = _firstPin?.length ?? PinRules.maxLength;
        if (_pin.length >= target) return;
        setState(() {
          _pin += '$d';
          if (_firstPin == null) {
            _message = null;
            _messageIsError = false;
          }
        });
        unawaited(
          _assembleTo(AssemblyTimeline.pinTarget(_pin.length, target), duration: const Duration(milliseconds: 300)),
        );
        if (_firstPin != null && _pin.length == target) unawaited(_confirmNewPin());
      case LockScreenMode.hold:
      case LockScreenMode.forgot:
        break;
    }
  }

  void _onDelete() {
    if (_busy || _pin.isEmpty) return;
    final lock = ref.read(lockControllerProvider);
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
    final length = _mode == LockScreenMode.pin ? lock.pinLength : (_firstPin?.length ?? PinRules.maxLength);
    unawaited(
      _assembleTo(AssemblyTimeline.pinTarget(_pin.length, length), duration: const Duration(milliseconds: 260)),
    );
  }

  void _onClear() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = '');
    unawaited(_assembleTo(AssemblyTimeline.pinBase));
  }

  Future<void> _submitPin() async {
    final l = L10n.of(context);
    final fmt = context.formatter;
    setState(() {
      _busy = true;
      _message = l.lockPinChecking;
      _messageIsError = false;
    });
    final result = await _lock.checkPin(_pin);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.accepted) {
      unawaited(_succeed());
      return;
    }
    if (result.check == PinCheck.busy) return;
    _fail(LockTexts.pinMessage(l, fmt, result));
    if (result.check == PinCheck.lockedOut) _ensureCountdown();
  }

  void _fail(String? message) {
    Fx.fire(Sfx.error);
    unawaited(_shake.forward(from: 0));
    unawaited(_error.forward(from: 0).then((_) => _error.reverse()));
    setState(() {
      _pin = '';
      _message = message;
      _messageIsError = true;
    });
    // The parts scatter back to their places in space.
    unawaited(
      _assembleTo(AssemblyTimeline.pinBase, duration: const Duration(milliseconds: 700), curve: Curves.easeInOutCubic),
    );
  }

  void _ensureCountdown() {
    if (_countdown?.isActive ?? false) return;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      _lock.refreshLockout();
      final lock = ref.read(lockControllerProvider);
      if (!_lockedOut(lock)) {
        timer.cancel();
        setState(() {
          _message = null;
          _messageIsError = false;
        });
        return;
      }
      setState(() {});
    });
  }

  // --------------------------------------------------------------- forgot

  void _forgot() {
    setState(() {
      _mode = LockScreenMode.forgot;
      _message = null;
      _pin = '';
    });
  }

  Future<void> _resetWithFingerprint() async {
    final l = L10n.of(context);
    setState(() => _busy = true);
    final outcome = await _lock.authenticateWithBiometrics(LockTexts.unlockPrompt(l), unlock: false);
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome != BiometricOutcome.success) {
      final message = LockTexts.biometricMessage(l, outcome);
      if (message != null) Fx.fire(Sfx.error);
      setState(() {
        _message = message;
        _messageIsError = message != null;
      });
      return;
    }
    Fx.fire(Sfx.toggleOn);
    setState(() {
      _mode = LockScreenMode.newPin;
      _firstPin = null;
      _pin = '';
      _message = null;
    });
    unawaited(_assembleTo(AssemblyTimeline.pinBase));
  }

  void _newPinDone() {
    if (_firstPin != null || !PinRules.isValid(_pin)) return;
    final l = L10n.of(context);
    final weak = PinRules.isWeak(_pin);
    setState(() {
      _firstPin = _pin;
      _pin = '';
      _message = weak ? l.lockPinWeak : l.lockPinConfirmBody;
      _messageIsError = false;
    });
    unawaited(_assembleTo(AssemblyTimeline.pinBase));
  }

  Future<void> _confirmNewPin() async {
    final l = L10n.of(context);
    if (_pin != _firstPin) {
      _firstPin = null;
      _fail(l.lockPinMismatch);
      return;
    }
    setState(() => _busy = true);
    try {
      await _lock.setPin(_pin);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _fail(l.lockSettingsSaveFailed);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _lock.unlockVerified();
    unawaited(_succeed());
  }

  // -------------------------------------------------------------- success

  Future<void> _succeed() async {
    if (_stage == _Stage.done) return;
    final l = L10n.of(context);
    _countdown?.cancel();
    setState(() {
      _stage = _Stage.done;
      _message = l.lockWelcome;
      _messageIsError = false;
    });
    unawaited(_scan.reverse());
    if (_reduced) {
      _assembly.value = 1;
      _ignite.value = 1;
      Fx.fire(Sfx.complete);
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (mounted) await _openDoor();
      return;
    }
    final rest = 1 - _assembly.value;
    await _assembly.animateTo(
      1,
      duration: Duration(milliseconds: (260 + 520 * rest).round()),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    // The astrolabe locks: a soft chime, the core star ignites, sparks fly.
    Fx.fire(Sfx.complete);
    _sparks(1);
    _sparks(0.8, kind: CelebrationKind.orbitalRing);
    unawaited(_ignite.forward(from: 0));
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (mounted) await _openDoor();
  }

  Future<void> _openDoor() async {
    if (_opening) return;
    ui.Image? still;
    if (!_reduced) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary = _captureKey.currentContext?.findRenderObject();
      if (boundary is RenderRepaintBoundary && !(kDebugMode && boundary.debugNeedsPaint)) {
        try {
          still = boundary.toImageSync(pixelRatio: MediaQuery.devicePixelRatioOf(context));
        } catch (_) {
          still = null;
        }
      }
    }
    if (!mounted) {
      still?.dispose();
      return;
    }
    setState(() {
      _opening = true;
      _snapshot = still;
    });
    Fx.fire(Sfx.sheetOpen, haptic: Haptic.light);
    _door.duration = _reduced ? const Duration(milliseconds: 220) : const Duration(milliseconds: 820);
    await _door.forward();
    if (mounted) _lock.revealed();
  }

  // ----------------------------------------------------------------- back

  bool _handleBack() {
    if (_stage == _Stage.done) return true;
    switch (_mode) {
      case LockScreenMode.forgot:
      case LockScreenMode.newPin:
        Fx.fire(Sfx.back);
        _enterPin();
        return true;
      case LockScreenMode.pin:
        if (_bioUsable) {
          Fx.fire(Sfx.back);
          setState(() {
            _mode = LockScreenMode.hold;
            _pin = '';
            _message = null;
          });
          unawaited(_assembleTo(0));
          return true;
        }
        return false;
      case LockScreenMode.hold:
        return false;
    }
  }

  // ---------------------------------------------------------------- build

  bool _bioUsable = false;

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(lockControllerProvider);
    final availability = ref.watch(biometricAvailabilityProvider);
    // While the check runs, trust the owner's setting.
    _bioUsable =
        lock.biometrics && (availability.value ?? BiometricAvailability.available) == BiometricAvailability.available;
    ref.listen(biometricAvailabilityProvider, (_, next) {
      final a = next.value;
      if (a == null || a == BiometricAvailability.available) {
        // The check the owed prompt was waiting for.
        _scheduleAutoPrompt();
        return;
      }
      if (_mode == LockScreenMode.hold && _stage == _Stage.idle && lock.hasPin) {
        _enterPin(message: lock.biometrics ? L10n.of(context).lockSettingsBiometricNotEnrolled : null);
      }
    });
    if (_mode == LockScreenMode.hold && !_bioUsable && lock.hasPin && _stage == _Stage.idle) {
      _mode = LockScreenMode.pin;
      if (_assembly.value < AssemblyTimeline.pinBase) _assembly.value = AssemblyTimeline.pinBase;
    }
    if (_lockedOut(lock)) _ensureCountdown();

    final live = RepaintBoundary(key: _captureKey, child: _live(context, lock));
    if (!_opening) return live;
    return LockDoor(progress: _door, snapshot: _snapshot, reduced: _reduced, fallback: live);
  }

  Widget _live(BuildContext context, AppLockState lock) {
    final t = context.tokens;
    final settings = ref.watch(appSettingsProvider.select((s) => s.powerMode));
    final animate = settings != PowerMode.batterySaver;
    // The lock screen sits above the app's navigator: give it its own
    // Material so text gets the theme's default style.
    return Material(
      color: t.space0,
      child: CosmosBackdrop(
        animate: animate,
        seed: 0.61,
        child: SafeArea(child: LayoutBuilder(builder: (context, box) => _layout(context, lock, box, animate))),
      ),
    );
  }

  Widget _layout(BuildContext context, AppLockState lock, BoxConstraints box, bool animate) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final h = box.maxHeight, w = box.maxWidth;
    final keypad = _mode == LockScreenMode.pin || _mode == LockScreenMode.newPin;
    final tall = h >= 700;
    final keySize = math.min(76.0, math.max(50.0, (h - 380) / 4.7));
    final headerH = keypad && !tall ? 56.0 : (tall ? 118.0 : 92.0);
    final bottomH = switch (_mode) {
      LockScreenMode.hold => 44 + _holdControlsHeight + 14,
      LockScreenMode.pin || LockScreenMode.newPin => keySize * 4 + keySize * 0.3 * 0.55 * 4 + 22 + 16 + 48 + 58,
      LockScreenMode.forgot => math.min(h * 0.5, 380.0),
    };
    final maxDial = _mode == LockScreenMode.forgot ? w * 0.62 : w * 0.94;
    final dialBox = math.max(96.0, math.min(maxDial, h - headerH - bottomH - 12));
    final lockedOut = _lockedOut(lock);
    final message = lockedOut
        ? LockTexts.lockedOut(l, context.formatter, lock.lockedUntil!.difference(ref.read(lockClockProvider)()))
        : (_message ?? _defaultMessage(l, lock));
    final isError = lockedOut || _messageIsError;

    final header = SizedBox(
      height: headerH,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _mode == LockScreenMode.newPin
                ? (_firstPin == null ? l.lockNewPinTitle : l.lockPinConfirmTitle)
                : l.appName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _headerStyle(context, tall ? text.displaySmall! : text.headlineMedium!).copyWith(
              color: t.gold,
              shadows: t.isDark ? [Shadow(color: t.accentGlow, blurRadius: 22)] : null,
            ),
          ),
          if (headerH > 60) ...[
            const SizedBox(height: Space.xs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 14, color: t.textTertiary),
                const SizedBox(width: Space.xs),
                Flexible(
                  child: Text(
                    l.lockScreenSubtitle,
                    textAlign: TextAlign.center,
                    style: text.bodySmall!.copyWith(color: t.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    final dial = _Dial(
      key: _dialKey,
      size: dialBox,
      assembly: _assembly,
      ignite: _ignite,
      scan: _scan,
      error: _error,
      shake: _shake,
      ruleAngle: _ruleAngle,
      animate: animate,
      fingerprint: _mode == LockScreenMode.hold,
      semanticsLabel: _mode == LockScreenMode.hold ? l.lockAstrolabeSemantics : null,
      semanticsHint: l.lockAstrolabeAction,
      onHoldStart: _mode == LockScreenMode.hold ? _onHoldStart : null,
      onHoldEnd: _mode == LockScreenMode.hold ? _onHoldEnd : null,
      onActivate: _mode == LockScreenMode.hold && _stage == _Stage.idle ? () => unawaited(_startReading()) : null,
    );

    final status = Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.xl),
      child: SizedBox(
        height: 44,
        child: Center(
          child: AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            child: Text(
              message ?? '',
              key: ValueKey('$message$isError'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium!.copyWith(color: isError ? t.danger : t.textSecondary, height: 1.35),
            ),
          ),
        ),
      ),
    );

    final Widget bottom = switch (_mode) {
      LockScreenMode.hold => _holdControls(context, lock, w),
      LockScreenMode.pin => _pinControls(context, lock, keySize, lockedOut),
      LockScreenMode.newPin => _newPinControls(context, keySize),
      LockScreenMode.forgot => _forgotPanel(context),
    };

    final switcher = AnimatedSwitcher(
      duration: context.motion(MadarMotion.medium),
      switchInCurve: MadarMotion.decelerate,
      switchOutCurve: MadarMotion.accelerate,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_mode), child: bottom),
    );
    if (_mode == LockScreenMode.hold) {
      // The dial, its hint and the PIN switch as one group, a little above
      // the centre.
      return Column(children: [header, const Spacer(), dial, status, switcher, const Spacer()]);
    }
    return Column(
      children: [
        header,
        Expanded(child: Center(child: dial)),
        if (_mode != LockScreenMode.forgot) status,
        switcher,
        const SizedBox(height: Space.m),
      ],
    );
  }

  /// Reem Kufi's word space is only ~0.13 em, which runs Arabic words
  /// together in a heading ("اختر رمزًا جديدًا"): open it up to ~0.3 em.
  static TextStyle _headerStyle(BuildContext context, TextStyle base) {
    if (Localizations.localeOf(context).languageCode != 'ar') return base;
    return base.copyWith(wordSpacing: (base.fontSize ?? 24) * 0.17);
  }

  String? _defaultMessage(L10n l, AppLockState lock) {
    if (lock.storageError && !lock.loaded) return l.lockStorageError;
    return switch (_mode) {
      LockScreenMode.hold => switch (_stage) {
        _Stage.holding => l.lockHoldingHint,
        _Stage.reading => l.lockReadingHint,
        _Stage.done => l.lockWelcome,
        _Stage.idle => _awaitingPrompt ? l.lockReadingHint : l.lockHoldHint,
      },
      LockScreenMode.pin => _stage == _Stage.done ? l.lockWelcome : l.lockPinHint,
      LockScreenMode.newPin =>
        _firstPin == null ? l.lockPinCreateBody(_fmt(PinRules.minLength), _fmt(PinRules.maxLength)) : null,
      LockScreenMode.forgot => null,
    };
  }

  String _fmt(int n) => context.formatter.formatInt(n);

  /// Height of the fingerprint face's controls: the large "Use fingerprint"
  /// button over the "Use PIN" link.
  static const double _holdControlsHeight = 118;

  Widget _holdControls(BuildContext context, AppLockState lock, double width) {
    final l = L10n.of(context);
    final busy = _stage == _Stage.reading || _stage == _Stage.done;
    // While the prompt is up (or about to open) the astrolabe is the whole
    // story; the button steps aside and comes back after a cancel.
    final asking = busy || _stage == _Stage.holding || _awaitingPrompt;
    return SizedBox(
      height: _holdControlsHeight,
      child: Column(
        children: [
          AnimatedOpacity(
            opacity: asking ? 0 : 1,
            duration: context.motion(MadarMotion.short),
            child: IgnorePointer(
              ignoring: asking,
              child: ExcludeSemantics(
                excluding: asking,
                child: SizedBox(
                  width: math.min(width - 2 * Space.gutter, 320),
                  child: MadarButton(
                    label: l.lockUseFingerprint,
                    icon: Icons.fingerprint_rounded,
                    size: MadarButtonSize.large,
                    expand: true,
                    sfx: Sfx.navigate,
                    onPressed: _useFingerprint,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s),
          if (lock.hasPin)
            MadarButton(
              label: l.lockUsePin,
              icon: Icons.dialpad_rounded,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.navigate,
              onPressed: busy ? null : () => _enterPin(),
            ),
        ],
      ),
    );
  }

  Widget _pinControls(BuildContext context, AppLockState lock, double keySize, bool lockedOut) {
    final l = L10n.of(context);
    final storageError = lock.storageError && !_busy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PinDots(
          filled: _pin.length,
          length: lock.pinLength,
          error: _messageIsError && _pin.isEmpty,
          shake: _shake,
          busy: _busy,
        ),
        const SizedBox(height: Space.l),
        PinKeypad(
          keySize: keySize,
          enabled: !_busy && !lockedOut && _stage != _Stage.done,
          onDigit: _onDigit,
          onDelete: _onDelete,
          onClear: _onClear,
          onBiometric: _bioUsable && _stage != _Stage.done ? _useFingerprint : null,
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: storageError
                ? MadarButton(
                    label: l.lockRetry,
                    icon: Icons.refresh_rounded,
                    variant: MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    onPressed: () => unawaited(_lock.load()),
                  )
                : MadarButton(
                    label: l.lockForgotPin,
                    variant: MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    sfx: Sfx.navigate,
                    onPressed: _stage == _Stage.done ? null : _forgot,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _newPinControls(BuildContext context, double keySize) {
    final l = L10n.of(context);
    final confirming = _firstPin != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PinDots(
          filled: _pin.length,
          length: _firstPin?.length,
          error: _messageIsError && _pin.isEmpty,
          shake: _shake,
          busy: _busy,
        ),
        const SizedBox(height: Space.l),
        PinKeypad(
          keySize: keySize,
          enabled: !_busy && _stage != _Stage.done,
          onDigit: _onDigit,
          onDelete: _onDelete,
          onClear: _onClear,
          onDone: confirming ? null : _newPinDone,
          doneEnabled: PinRules.isValid(_pin),
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: MadarButton(
              label: l.lockForgotBack,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.back,
              onPressed: _busy || _stage == _Stage.done ? null : () => _enterPin(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _forgotPanel(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
      child: GlassPanel(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.l, Space.xl, Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l.lockForgotTitle, textAlign: TextAlign.center, style: text.titleLarge),
            ),
            const SizedBox(height: Space.s),
            Text(
              l.lockForgotBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.45),
            ),
            const SizedBox(height: Space.m),
            Text(
              _bioUsable ? l.lockForgotBiometric : l.lockForgotNoBiometric,
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.5),
            ),
            if (_message != null) ...[
              const SizedBox(height: Space.s),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: text.bodySmall!.copyWith(color: _messageIsError ? t.danger : t.textSecondary),
              ),
            ],
            const SizedBox(height: Space.l),
            if (_bioUsable) ...[
              MadarButton(
                label: l.lockForgotBiometricAction,
                icon: Icons.fingerprint_rounded,
                expand: true,
                loading: _busy,
                onPressed: _resetWithFingerprint,
              ),
              const SizedBox(height: Space.s),
            ],
            MadarButton(
              label: l.lockForgotBack,
              variant: MadarButtonVariant.ghost,
              expand: true,
              sfx: Sfx.back,
              onPressed: _busy ? null : () => _enterPin(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The astrolabe with its hold gesture, the fingerprint glyph at its
/// centre (hold mode) and the shake of a wrong entry.
class _Dial extends StatelessWidget {
  const _Dial({
    super.key,
    required this.size,
    required this.assembly,
    required this.ignite,
    required this.scan,
    required this.error,
    required this.shake,
    required this.ruleAngle,
    required this.animate,
    required this.fingerprint,
    required this.semanticsHint,
    this.semanticsLabel,
    this.onHoldStart,
    this.onHoldEnd,
    this.onActivate,
  });

  final double size;
  final Animation<double> assembly, ignite, scan, error, shake;
  final double ruleAngle;
  final bool animate;
  final bool fingerprint;
  final String? semanticsLabel;
  final String semanticsHint;
  final VoidCallback? onHoldStart;
  final VoidCallback? onHoldEnd;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dialR = size / 2 / LockAstrolabePainter.boxFactor;
    Widget dial = SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          LockAstrolabe(
            progress: assembly,
            ignite: ignite,
            scan: scan,
            error: error,
            size: size,
            ruleAngle: ruleAngle,
            animate: animate,
          ),
          if (fingerprint)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: assembly,
                builder: (context, child) {
                  final hub = AssemblyTimeline.local(AstrolabePart.hub, assembly.value);
                  final o = (1 - hub).clamp(0.0, 1.0);
                  return Opacity(opacity: o, child: child);
                },
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: dialR * 0.36,
                  color: t.metalGold,
                  shadows: t.isDark ? [Shadow(color: t.accentGlow, blurRadius: 18)] : null,
                ),
              ),
            ),
        ],
      ),
    );
    dial = AnimatedBuilder(
      animation: shake,
      builder: (context, child) =>
          Transform.translate(offset: Offset(shakeOffset(shake.value, amplitude: 10), 0), child: child),
      child: dial,
    );
    if (onHoldStart != null) {
      dial = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onHoldStart!(),
        onPointerUp: (_) => onHoldEnd?.call(),
        onPointerCancel: (_) => onHoldEnd?.call(),
        child: dial,
      );
    }
    return Semantics(
      container: true,
      button: onActivate != null,
      label: semanticsLabel,
      onTapHint: onActivate != null ? semanticsHint : null,
      onTap: onActivate,
      child: ExcludeSemantics(child: dial),
    );
  }
}
