import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../lock/application/lock_controller.dart';
import '../../../lock/data/biometric_auth.dart';
import '../application/kids_providers.dart';
import 'kids_palette.dart';

/// The parent gate (docs/kids screen 1c): the PIN pad and the fingerprint key
/// over a calm dusk. A wrong PIN empties the dots and says «جرّب مرّة ثانية»:
/// no shaking, no red, nothing that blames a child. Three wrong tries in a row
/// start a 30-second pause with a gentle message.
class KidsParentGate extends ConsumerStatefulWidget {
  const KidsParentGate({super.key});

  @override
  ConsumerState<KidsParentGate> createState() => _KidsParentGateState();
}

enum _Note { none, tryAgain, unavailable }

class _KidsParentGateState extends ConsumerState<KidsParentGate> {
  String _pin = '';
  bool _busy = false;
  _Note _note = _Note.none;
  bool _fingerprint = false;
  DateTime? _pausedUntil;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFingerprint());
    final now = ref.read(kidsClockProvider)();
    final left = ref.read(kidsModeProvider).backoff.remaining(now);
    if (left > Duration.zero) _startPause(left);
  }

  Future<void> _loadFingerprint() async {
    final available = await ref.read(kidsModeProvider.notifier).fingerprintAvailable();
    if (mounted && available != _fingerprint) setState(() => _fingerprint = available);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Duration _pauseLeft() {
    final until = _pausedUntil;
    if (until == null) return Duration.zero;
    final left = until.difference(ref.read(kidsClockProvider)());
    return left > Duration.zero ? left : Duration.zero;
  }

  void _startPause(Duration left) {
    _pausedUntil = ref.read(kidsClockProvider)().add(left);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_pauseLeft() == Duration.zero) {
        t.cancel();
        _pausedUntil = null;
      }
      setState(() {});
    });
  }

  void _accepted() => ref.read(kidsParentPhaseProvider.notifier).verified();

  void _apply(GateResult r) {
    switch (r.outcome) {
      case GateOutcome.accepted:
        _accepted();
      case GateOutcome.wrong:
        setState(() {
          _pin = '';
          _note = _Note.tryAgain;
        });
      case GateOutcome.paused:
        setState(() {
          _pin = '';
          _note = _Note.none;
          _startPause(r.pause);
        });
      case GateOutcome.unavailable:
        setState(() {
          _pin = '';
          _note = _Note.unavailable;
        });
      case GateOutcome.busy:
        break;
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final r = await ref.read(kidsModeProvider.notifier).tryPin(_pin);
    if (!mounted) return;
    setState(() => _busy = false);
    _apply(r);
  }

  void _digit(int d, int length) {
    if (_busy || _pauseLeft() > Duration.zero || _pin.length >= length) return;
    setState(() {
      _pin += '$d';
      _note = _Note.none;
    });
    if (_pin.length == length) unawaited(_submit());
  }

  void _delete() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _useFingerprint() async {
    if (_busy) return;
    final l = L10n.of(context);
    final text = BiometricPromptText(
      reason: l.kidsShellGateBioReason,
      title: l.kidsShellGateBioTitle,
      hint: l.kidsShellGateBioHint,
      cancel: l.kidsShellGateBioCancel,
    );
    setState(() => _busy = true);
    final r = await ref.read(kidsModeProvider.notifier).tryFingerprint(text);
    if (!mounted) return;
    setState(() => _busy = false);
    // A cancelled or unrecognised finger is not a wrong PIN: stay quiet.
    if (r != null && r.accepted) _accepted();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final length = ref.watch(lockControllerProvider.select((s) => s.pinLength));
    final pause = _pauseLeft();
    final paused = pause > Duration.zero;
    final String message;
    if (paused) {
      message = kidsDigits(context, l.kidsShellGatePause((pause.inMilliseconds / 1000).ceil()));
    } else {
      message = switch (_note) {
        _Note.none => '',
        _Note.tryAgain => l.kidsShellGateTryAgain,
        _Note.unavailable => l.kidsShellGateUnavailable,
      };
    }

    return Material(
      key: const ValueKey('kids-parent-gate'),
      color: KidsColors.night900,
      child: KidsNightBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 32, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const KhatamStar(
                        size: 96,
                        color: KidsColors.night700,
                        child: Icon(Icons.lock_rounded, color: KidsColors.sun500, size: 40),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l.kidsShellGateTitle,
                        textAlign: TextAlign.center,
                        style: KidsText.title(Colors.white, size: 34),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.kidsShellGateBody,
                        textAlign: TextAlign.center,
                        style: KidsText.text(KidsColors.night100, size: 18),
                      ),
                      const SizedBox(height: 20),
                      _Dots(filled: _pin.length, length: length),
                      SizedBox(
                        height: 56,
                        child: Center(
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: KidsText.text(KidsColors.sun300, size: 17),
                            ),
                          ),
                        ),
                      ),
                      _Keypad(
                        enabled: !_busy && !paused,
                        fingerprint: _fingerprint,
                        onDigit: (d) => _digit(d, length),
                        onDelete: _delete,
                        onFingerprint: _useFingerprint,
                        deleteLabel: l.kidsShellGateDelete,
                        fingerprintLabel: l.kidsShellGateFingerprint,
                      ),
                      const SizedBox(height: 20),
                      KidsBigButton(
                        label: l.kidsShellGateBack,
                        icon: Icons.home_rounded,
                        tone: KidsButtonTone.paper,
                        onPressed: ref.read(kidsParentPhaseProvider.notifier).close,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.filled, required this.length});

  final int filled;
  final int length;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < length; i++)
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? KidsColors.sun300 : Colors.transparent,
              border: Border.all(color: KidsColors.night300, width: 2),
            ),
          ),
        ),
    ],
  );
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.fingerprint,
    required this.onDigit,
    required this.onDelete,
    required this.onFingerprint,
    required this.deleteLabel,
    required this.fingerprintLabel,
  });

  final bool enabled;
  final bool fingerprint;
  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onFingerprint;
  final String deleteLabel;
  final String fingerprintLabel;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap, {required Key k, required String label}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: SizedBox(
            height: kKidsMinTarget,
            child: Material(
              key: k,
              color: const Color(0x33FFFFFF),
              shape: const StadiumBorder(side: BorderSide(color: Color(0x55FFFFFF))),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: enabled ? onTap : null,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );

    Widget digit(int d) => key(
      Text(kidsDigits(context, '$d'), style: KidsText.title(Colors.white, size: 30)),
      () => onDigit(d),
      k: ValueKey('kids-key-$d'),
      label: kidsDigits(context, '$d'),
    );

    // A phone's pad reads 1-2-3 left to right in either direction.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in const [
              [1, 2, 3],
              [4, 5, 6],
              [7, 8, 9],
            ])
              Row(children: [for (final d in row) digit(d)]),
            Row(
              children: [
                if (fingerprint)
                  key(
                    const Icon(Icons.fingerprint_rounded, color: KidsColors.sun300, size: 34),
                    onFingerprint,
                    k: const ValueKey('kids-key-fingerprint'),
                    label: fingerprintLabel,
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
                digit(0),
                key(
                  const Icon(Icons.backspace_rounded, color: Colors.white, size: 28),
                  onDelete,
                  k: const ValueKey('kids-key-delete'),
                  label: deleteLabel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
