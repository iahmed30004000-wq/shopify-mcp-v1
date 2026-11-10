import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart' show showInteractionSheet, InteractionSheetFrame, SheetButton;
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../application/lock_controller.dart';
import '../data/biometric_auth.dart';
import '../domain/pin_hash.dart';
import 'lock_texts.dart';
import 'pin_pad.dart';

/// What [showPinSetupSheet] sets up.
enum PinSetupMode {
  /// A first PIN (turning the lock on).
  create,

  /// A new PIN after the current one.
  change,
}

/// The PIN (and fingerprint choice) the owner settled on.
@immutable
class PinSetupResult {
  const PinSetupResult({required this.pin, this.biometrics});

  final String pin;

  /// Fingerprint unlock chosen in the last step (null: not asked).
  final bool? biometrics;
}

/// Opens the PIN sheet: (current PIN →) new PIN → confirm (→ "fingerprint
/// too?"). Returns null when dismissed. Saving is the caller's job
/// (`LockController.setPin`).
Future<PinSetupResult?> showPinSetupSheet(BuildContext context, {PinSetupMode mode = PinSetupMode.create}) =>
    showInteractionSheet<PinSetupResult>(context, builder: (_) => PinSetupSheet(mode: mode));

/// Asks for the current PIN on a sheet; true when it was right.
Future<bool> showPinVerifySheet(BuildContext context) async =>
    await showInteractionSheet<bool>(context, builder: (_) => const PinVerifySheet()) ?? false;

/// Confirms the owner before a change to the lock: fingerprint when it is
/// on and available (its negative button falls back to the PIN), otherwise
/// the PIN on a sheet. True without asking when no PIN exists yet.
Future<bool> confirmLockIdentity(BuildContext context, WidgetRef ref) async {
  final lock = ref.read(lockControllerProvider);
  if (!lock.hasPin) return true;
  final l = L10n.of(context);
  if (lock.biometrics) {
    BiometricAvailability? a;
    try {
      a = await ref.read(biometricAvailabilityProvider.future);
    } catch (_) {
      a = null;
    }
    if (a == BiometricAvailability.available) {
      final outcome = await ref
          .read(lockControllerProvider.notifier)
          .authenticateWithBiometrics(LockTexts.settingsPrompt(l), unlock: false);
      if (outcome == BiometricOutcome.success) return true;
    }
  }
  if (!context.mounted) return false;
  return showPinVerifySheet(context);
}

enum _Step { current, enter, confirm, biometrics }

/// Keeps a PIN sheet's lockout live: the countdown updates every second and
/// the keypad comes back the moment the lockout ends.
mixin _LockoutCountdown<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _lockoutTimer;

  /// What is left of the wrong-PIN lockout now (zero when none).
  Duration lockoutLeft() {
    final until = ref.read(lockControllerProvider).lockedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(ref.read(lockClockProvider)());
    return left > Duration.zero ? left : Duration.zero;
  }

  /// Starts the per-second refresh while a lockout runs (safe in build).
  void watchLockout() {
    if ((_lockoutTimer?.isActive ?? false) || lockoutLeft() == Duration.zero) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      ref.read(lockControllerProvider.notifier).refreshLockout();
      if (lockoutLeft() == Duration.zero) timer.cancel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }
}

/// The sheet behind [showPinSetupSheet].
class PinSetupSheet extends ConsumerStatefulWidget {
  const PinSetupSheet({super.key, this.mode = PinSetupMode.create});

  final PinSetupMode mode;

  @override
  ConsumerState<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<PinSetupSheet>
    with SingleTickerProviderStateMixin, _LockoutCountdown<PinSetupSheet> {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late _Step _step = widget.mode == PinSetupMode.change ? _Step.current : _Step.enter;
  String _pin = '';
  String? _first;
  String? _message;
  bool _error = false;
  bool _busy = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool get _bioAvailable => ref.read(biometricAvailabilityProvider).value == BiometricAvailability.available;

  void _digit(int d) {
    if (_busy) return;
    final lock = ref.read(lockControllerProvider);
    final max = switch (_step) {
      _Step.current => lock.pinLength,
      _Step.confirm => _first!.length,
      _ => PinRules.maxLength,
    };
    if (_pin.length >= max) return;
    setState(() {
      _pin += '$d';
      if (_step != _Step.confirm) {
        _message = null;
        _error = false;
      }
    });
    if (_pin.length == max) {
      if (_step == _Step.current) unawaited(_checkCurrent());
      if (_step == _Step.confirm) unawaited(_confirm());
    }
  }

  void _delete() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _fail(String? message) {
    Fx.fire(Sfx.error);
    unawaited(_shake.forward(from: 0));
    setState(() {
      _pin = '';
      _message = message;
      _error = true;
    });
  }

  Future<void> _checkCurrent() async {
    final l = L10n.of(context);
    final fmt = context.formatter;
    setState(() => _busy = true);
    final r = await ref.read(lockControllerProvider.notifier).checkPin(_pin, unlock: false);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.accepted) {
      Fx.fire(Sfx.toggleOn);
      setState(() {
        _step = _Step.enter;
        _pin = '';
        _message = null;
        _error = false;
      });
      return;
    }
    if (r.check == PinCheck.busy) return;
    // A lockout shows its own live countdown (see build).
    _fail(r.check == PinCheck.lockedOut ? null : LockTexts.pinMessage(l, fmt, r) ?? l.lockStorageError);
  }

  Future<void> _currentWithFingerprint() async {
    final l = L10n.of(context);
    setState(() => _busy = true);
    final o = await ref
        .read(lockControllerProvider.notifier)
        .authenticateWithBiometrics(LockTexts.settingsPrompt(l), unlock: false);
    if (!mounted) return;
    setState(() => _busy = false);
    if (o == BiometricOutcome.success) {
      Fx.fire(Sfx.toggleOn);
      setState(() {
        _step = _Step.enter;
        _pin = '';
        _message = null;
      });
    } else {
      final m = LockTexts.biometricMessage(l, o);
      if (m != null) _fail(m);
    }
  }

  void _next() {
    if (!PinRules.isValid(_pin)) return;
    final l = L10n.of(context);
    setState(() {
      _first = _pin;
      _pin = '';
      _step = _Step.confirm;
      _message = PinRules.isWeak(_first!) ? l.lockPinWeak : null;
      _error = false;
    });
  }

  Future<void> _confirm() async {
    final l = L10n.of(context);
    if (_pin != _first) {
      setState(() {
        _step = _Step.enter;
        _first = null;
      });
      _fail(l.lockPinMismatch);
      return;
    }
    Fx.fire(Sfx.complete);
    if (widget.mode == PinSetupMode.create && _bioAvailable) {
      setState(() {
        _step = _Step.biometrics;
        _message = null;
      });
      return;
    }
    Navigator.of(context).pop(PinSetupResult(pin: _pin));
  }

  Future<void> _enableBiometrics() async {
    final l = L10n.of(context);
    setState(() => _busy = true);
    final o = await ref
        .read(lockControllerProvider.notifier)
        .authenticateWithBiometrics(LockTexts.settingsPrompt(l), unlock: false, enrolling: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (o == BiometricOutcome.success) {
      Fx.fire(Sfx.toggleOn);
      Navigator.of(context).pop(PinSetupResult(pin: _first!, biometrics: true));
    } else {
      final m = LockTexts.biometricMessage(l, o);
      if (m != null) {
        Fx.fire(Sfx.error);
        setState(() {
          _message = m;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final lock = ref.watch(lockControllerProvider);
    ref.watch(biometricAvailabilityProvider);
    final lockout = _step == _Step.current ? lockoutLeft() : Duration.zero;
    if (lockout > Duration.zero) watchLockout();
    final message = lockout > Duration.zero ? LockTexts.lockedOut(l, fmt, lockout) : _message;
    final error = lockout > Duration.zero || _error;
    final (title, subtitle) = switch (_step) {
      _Step.current => (l.lockPinCurrentTitle, null),
      _Step.enter => (
        widget.mode == PinSetupMode.change ? l.lockNewPinTitle : l.lockPinCreateTitle,
        l.lockPinCreateBody(fmt.formatInt(PinRules.minLength), fmt.formatInt(PinRules.maxLength)),
      ),
      _Step.confirm => (l.lockPinConfirmTitle, l.lockPinConfirmBody),
      _Step.biometrics => (l.lockBioOfferTitle, l.lockBioOfferBody),
    };

    final Widget body;
    if (_step == _Step.biometrics) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Space.l),
          Icon(Icons.fingerprint_rounded, size: 72, color: t.gold),
          const SizedBox(height: Space.l),
          if (message != null)
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: error ? t.danger : t.textSecondary),
            ),
          const SizedBox(height: Space.l),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Space.s),
          PinDots(
            filled: _pin.length,
            length: switch (_step) {
              _Step.current => lock.pinLength,
              _Step.confirm => _first?.length,
              _ => null,
            },
            error: error && _pin.isEmpty,
            shake: _shake,
            busy: _busy,
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: AnimatedSwitcher(
                duration: context.motion(MadarMotion.short),
                child: Text(
                  message ?? '',
                  key: ValueKey(lockout > Duration.zero ? 'lockout' : message),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: text.bodySmall!.copyWith(color: error ? t.danger : t.textSecondary),
                ),
              ),
            ),
          ),
          PinKeypad(
            keySize: 64,
            enabled: !_busy && lockout == Duration.zero,
            onDigit: _digit,
            onDelete: _delete,
            onClear: () => setState(() => _pin = ''),
            onDone: _step == _Step.enter ? _next : null,
            doneEnabled: PinRules.isValid(_pin),
            onBiometric: _step == _Step.current && lock.biometrics && _bioAvailable ? _currentWithFingerprint : null,
          ),
        ],
      );
    }

    return InteractionSheetFrame(
      title: title,
      subtitle: subtitle,
      icon: _step == _Step.biometrics ? Icons.fingerprint_rounded : Icons.password_rounded,
      scrollable: false,
      body: body,
      footer: _step == _Step.biometrics
          ? Row(
              children: [
                Expanded(
                  child: SheetButton(
                    label: l.lockBioOfferSkip,
                    sfx: Sfx.back,
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(PinSetupResult(pin: _first!, biometrics: false)),
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: SheetButton(
                    label: l.lockBioOfferEnable,
                    icon: Icons.fingerprint_rounded,
                    primary: true,
                    sfx: null,
                    onPressed: _busy ? null : _enableBiometrics,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

/// The sheet behind [showPinVerifySheet].
class PinVerifySheet extends ConsumerStatefulWidget {
  const PinVerifySheet({super.key});

  @override
  ConsumerState<PinVerifySheet> createState() => _PinVerifySheetState();
}

class _PinVerifySheetState extends ConsumerState<PinVerifySheet>
    with SingleTickerProviderStateMixin, _LockoutCountdown<PinVerifySheet> {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  String _pin = '';
  String? _message;
  bool _error = false;
  bool _busy = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final l = L10n.of(context);
    final fmt = context.formatter;
    setState(() => _busy = true);
    final r = await ref.read(lockControllerProvider.notifier).checkPin(_pin, unlock: false);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.accepted) {
      Fx.fire(Sfx.toggleOn);
      Navigator.of(context).pop(true);
      return;
    }
    if (r.check == PinCheck.busy) return;
    Fx.fire(Sfx.error);
    unawaited(_shake.forward(from: 0));
    setState(() {
      _pin = '';
      // A lockout shows its own live countdown (see build).
      _message = r.check == PinCheck.lockedOut ? null : LockTexts.pinMessage(l, fmt, r);
      _error = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final lock = ref.watch(lockControllerProvider);
    final lockout = lockoutLeft();
    final lockedOut = lockout > Duration.zero;
    if (lockedOut) watchLockout();
    final message = lockedOut ? LockTexts.lockedOut(l, context.formatter, lockout) : _message;
    return InteractionSheetFrame(
      title: l.lockConfirmTitle,
      subtitle: l.lockConfirmBody,
      icon: Icons.lock_rounded,
      scrollable: false,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: Space.s),
          PinDots(
            filled: _pin.length,
            length: lock.pinLength,
            error: (lockedOut || _error) && _pin.isEmpty,
            shake: _shake,
            busy: _busy,
          ),
          SizedBox(
            height: 40,
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: text.bodySmall!.copyWith(color: t.danger),
                ),
              ),
            ),
          ),
          PinKeypad(
            keySize: 64,
            enabled: !_busy && !lockedOut,
            onDigit: (d) {
              if (_pin.length >= lock.pinLength) return;
              setState(() {
                _pin += '$d';
                _message = null;
                _error = false;
              });
              if (_pin.length == lock.pinLength) unawaited(_check());
            },
            onDelete: () {
              if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
            },
            onClear: () => setState(() => _pin = ''),
          ),
        ],
      ),
    );
  }
}
