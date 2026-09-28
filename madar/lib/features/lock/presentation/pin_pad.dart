import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/pin_hash.dart';

/// Horizontal shake of a wrong entry: a decaying sine (0 → 1 animation).
double shakeOffset(double t, {double amplitude = 14}) {
  if (t <= 0 || t >= 1) return 0;
  return math.sin(t * math.pi * 7) * amplitude * (1 - t) * (1 - t);
}

/// The PIN's dots: filled for entered digits, a ring for the rest. With a
/// known [length] exactly that many; while choosing a new PIN ([length]
/// null) at least [PinRules.minLength] and one ring past the entered digits.
/// Always left-to-right (digits read that way in Arabic too).
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, this.length, this.error = false, this.shake, this.busy = false});

  final int filled;
  final int? length;
  final bool error;
  final bool busy;
  final Animation<double>? shake;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = context.formatter;
    final total = length ?? math.min(PinRules.maxLength, math.max(PinRules.minLength, filled + 1));
    final label = length != null
        ? l.lockPinProgress(fmt.formatInt(filled), fmt.formatInt(length!))
        : l.lockPinProgressOpen(fmt.formatInt(filled));
    Widget dots = Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: _Dot(on: i < filled, error: error, busy: busy, index: i, tokens: t),
            ),
        ],
      ),
    );
    final s = shake;
    if (s != null) {
      dots = AnimatedBuilder(
        animation: s,
        builder: (context, child) => Transform.translate(offset: Offset(shakeOffset(s.value), 0), child: child),
        child: dots,
      );
    }
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(child: SizedBox(height: 22, child: dots)),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.on, required this.error, required this.busy, required this.index, required this.tokens});

  final bool on, error, busy;
  final int index;
  final MadarTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final color = error ? t.danger : t.gold;
    return AnimatedContainer(
      duration: context.motion(MadarMotion.short),
      curve: MadarMotion.standard,
      width: on ? 14 : 12,
      height: on ? 14 : 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? color.withValues(alpha: busy ? 0.6 : 1) : Colors.transparent,
        border: Border.all(color: on ? color : t.textTertiary.withValues(alpha: 0.7), width: 1.3),
        boxShadow: on && !t.isDark
            ? null
            : on
            ? [BoxShadow(color: (error ? t.danger : t.accentGlow).withValues(alpha: 0.55), blurRadius: 10)]
            : null,
      ),
    );
  }
}

/// A 3 × 4 numeric keypad (1–9, then an optional leading key, 0 and delete).
///
/// The grid keeps the telephone order in both directions; digits follow the
/// digit style (Arabic-Indic in Arabic). Every key plays [Sfx.tap] with its
/// haptic; delete plays [Sfx.back] and a long press clears. A hardware
/// keyboard works too (digits, backspace, enter).
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onClear,
    this.onBiometric,
    this.onDone,
    this.enabled = true,
    this.doneEnabled = false,
    this.keySize = 72,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onClear;

  /// Shows a fingerprint key at the bottom start.
  final VoidCallback? onBiometric;

  /// Shows a "done" key at the bottom start (choosing a new PIN).
  final VoidCallback? onDone;
  final bool enabled;
  final bool doneEnabled;
  final double keySize;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (!enabled) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final digit = _digitOf(key) ?? _digitOfChar(event.character);
    if (digit != null) {
      Fx.fire(Sfx.tap);
      onDigit(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      Fx.fire(Sfx.back);
      onDelete();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) && onDone != null && doneEnabled) {
      Fx.fire(Sfx.complete);
      onDone!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static int? _digitOf(LogicalKeyboardKey key) {
    const row = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const pad = [
      LogicalKeyboardKey.numpad0,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final a = row.indexOf(key);
    if (a >= 0) return a;
    final b = pad.indexOf(key);
    return b >= 0 ? b : null;
  }

  static int? _digitOfChar(String? c) {
    if (c == null || c.length != 1) return null;
    final w = Digits.toWestern(c);
    final code = w.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39 ? code - 0x30 : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = context.formatter;
    final gap = keySize * 0.3;
    Widget digit(int d) => _PinKey(
      size: keySize,
      enabled: enabled,
      semanticLabel: fmt.localizeDigits('$d'),
      onTap: () => onDigit(d),
      child: Text(
        fmt.localizeDigits('$d'),
        style: Theme.of(context).textTheme.headlineMedium!.copyWith(
          fontSize: keySize * 0.38,
          fontWeight: FontWeight.w500,
          height: 1.1,
          color: context.tokens.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final Widget leading;
    if (onDone != null) {
      leading = _PinKey(
        size: keySize,
        enabled: enabled && doneEnabled,
        accent: true,
        sfx: Sfx.complete,
        semanticLabel: l.lockKeyDone,
        onTap: onDone!,
        child: Icon(Icons.check_rounded, size: keySize * 0.4),
      );
    } else if (onBiometric != null) {
      leading = _PinKey(
        size: keySize,
        enabled: true,
        quiet: true,
        sfx: Sfx.navigate,
        semanticLabel: l.lockKeyFingerprint,
        onTap: onBiometric!,
        child: Icon(Icons.fingerprint_rounded, size: keySize * 0.46, color: context.tokens.gold),
      );
    } else {
      leading = SizedBox.square(dimension: keySize);
    }
    final delete = _PinKey(
      size: keySize,
      enabled: enabled,
      quiet: true,
      sfx: Sfx.back,
      semanticLabel: l.lockKeyDelete,
      onTap: onDelete,
      onLongPress: onClear,
      child: Icon(Icons.backspace_outlined, size: keySize * 0.34, color: context.tokens.textSecondary),
    );
    Widget row(List<Widget> keys) => Padding(
      padding: EdgeInsets.only(bottom: gap * 0.55),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < keys.length; i++) ...[if (i > 0) SizedBox(width: gap), keys[i]],
        ],
      ),
    );
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Directionality(
        // Keypads keep the telephone order in right-to-left languages.
        textDirection: TextDirection.ltr,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row([digit(1), digit(2), digit(3)]),
            row([digit(4), digit(5), digit(6)]),
            row([digit(7), digit(8), digit(9)]),
            row([leading, digit(0), delete]),
          ],
        ),
      ),
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.size,
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.onLongPress,
    this.enabled = true,
    this.quiet = false,
    this.accent = false,
    this.sfx = Sfx.tap,
  });

  final double size;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String semanticLabel;
  final bool enabled;

  /// No disc: the delete and fingerprint keys.
  final bool quiet;

  /// Filled with the accent: the done key.
  final bool accent;
  final Sfx sfx;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final BoxDecoration deco;
    if (accent) {
      deco = BoxDecoration(
        shape: BoxShape.circle,
        color: enabled ? t.accent : t.accent.withValues(alpha: 0.25),
        boxShadow: enabled ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.45), blurRadius: 16)] : null,
      );
    } else if (quiet) {
      deco = const BoxDecoration(shape: BoxShape.circle);
    } else {
      deco = BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 1.1,
          colors: [
            t.glassHighlight.withValues(alpha: t.isDark ? 0.16 : 0.7),
            t.glassFill,
          ],
        ),
        border: Border.all(color: t.glassBorder.withValues(alpha: t.isDark ? 0.7 : 0.9), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: t.glassShadow.withValues(alpha: t.isDark ? 0.35 : 0.18),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      );
    }
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: MadarPressable(
        onTap: enabled ? onTap : null,
        onLongPress: enabled ? onLongPress : null,
        enabled: enabled,
        sfx: sfx,
        longPressSfx: Sfx.delete,
        pressScale: 0.9,
        semanticLabel: semanticLabel,
        excludeChildSemantics: true,
        focusRadius: BorderRadius.circular(size / 2),
        child: IconTheme.merge(
          data: IconThemeData(color: accent ? t.textOnAccent : t.textPrimary),
          child: Container(width: size, height: size, alignment: Alignment.center, decoration: deco, child: child),
        ),
      ),
    );
  }
}
