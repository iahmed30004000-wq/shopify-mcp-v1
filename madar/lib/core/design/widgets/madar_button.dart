import 'package:flutter/material.dart';

import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../tokens.dart';
import 'glass.dart';
import 'orbit_loader.dart';
import 'pressable.dart';

enum MadarButtonVariant {
  /// Filled accent with a soft glow – the one main action of a screen.
  primary,

  /// Faux-glass pill – secondary actions.
  secondary,

  /// Text-only accent – tertiary actions, inline links.
  ghost,

  /// Danger-tinted outline – destructive actions.
  danger,
}

enum MadarButtonSize { small, medium, large }

/// Resolved paint recipe of a button (pure, derived from tokens).
@immutable
class MadarButtonStyle {
  const MadarButtonStyle({
    required this.foreground,
    this.gradient,
    this.fill,
    this.border,
    this.glow,
    this.pressedFill,
  });

  factory MadarButtonStyle.of(MadarTokens t, MadarButtonVariant variant) {
    switch (variant) {
      case MadarButtonVariant.primary:
        final hsl = HSLColor.fromColor(t.accent);
        return MadarButtonStyle(
          foreground: t.textOnAccent,
          gradient: [
            hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 0.95)).toColor(),
            t.accent,
            hsl.withLightness((hsl.lightness - 0.08).clamp(0.05, 1.0)).toColor(),
          ],
          border: t.glassHighlight,
          glow: t.accentGlow,
        );
      case MadarButtonVariant.secondary:
        return MadarButtonStyle(
          foreground: t.textPrimary,
          fill: Color.alphaBlend(t.glassFill, t.space2.withValues(alpha: t.isDark ? 0.55 : 0.45)),
          border: t.glassBorder,
          pressedFill: t.accentSoft,
        );
      case MadarButtonVariant.ghost:
        return MadarButtonStyle(foreground: t.accent, pressedFill: t.accentSoft);
      case MadarButtonVariant.danger:
        return MadarButtonStyle(
          foreground: t.danger,
          fill: t.danger.withValues(alpha: 0.08),
          border: t.danger.withValues(alpha: 0.45),
          pressedFill: t.danger.withValues(alpha: 0.18),
        );
    }
  }

  /// Quiet, colourless recipe for a disabled button of any variant.
  factory MadarButtonStyle.disabled(MadarTokens t, MadarButtonVariant variant) {
    if (variant == MadarButtonVariant.ghost) return MadarButtonStyle(foreground: t.textTertiary);
    return MadarButtonStyle(
      foreground: t.textTertiary,
      fill: Color.alphaBlend(t.glassFill, t.space2.withValues(alpha: t.isDark ? 0.35 : 0.3)),
      border: t.glassBorder.withValues(alpha: t.glassBorder.a * 0.6),
    );
  }

  final Color foreground;
  final List<Color>? gradient;
  final Color? fill;
  final Color? border;
  final Color? glow;
  final Color? pressedFill;
}

/// Madar's button: primary (accent + glow), secondary (glass), ghost, danger;
/// label with optional icons, or icon-only ([MadarButton.icon]); loading
/// state with an [OrbitLoader] that keeps the button's size. Presses spring
/// to [MadarMotion.pressScale] and fire [sfx] (default [Sfx.tap]).
class MadarButton extends StatefulWidget {
  const MadarButton({
    super.key,
    required String this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = MadarButtonVariant.primary,
    this.size = MadarButtonSize.medium,
    this.loading = false,
    this.expand = false,
    this.sfx = Sfx.tap,
    this.semanticLabel,
  });

  /// Round icon-only button; [semanticLabel] is required for screen readers
  /// (and shown as a tooltip on long-press).
  const MadarButton.icon({
    super.key,
    required IconData this.icon,
    required this.onPressed,
    required String this.semanticLabel,
    this.variant = MadarButtonVariant.secondary,
    this.size = MadarButtonSize.medium,
    this.loading = false,
    this.sfx = Sfx.tap,
  }) : label = null,
       trailingIcon = null,
       expand = false;

  final String? label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final MadarButtonVariant variant;
  final MadarButtonSize size;
  final bool loading;

  /// Stretch to the available width.
  final bool expand;
  final Sfx sfx;
  final String? semanticLabel;

  bool get isIconOnly => label == null;
  bool get enabled => onPressed != null && !loading;

  static double heightFor(MadarButtonSize size) => switch (size) {
    MadarButtonSize.small => 36,
    MadarButtonSize.medium => 48,
    MadarButtonSize.large => 56,
  };

  @override
  State<MadarButton> createState() => _MadarButtonState();
}

class _MadarButtonState extends State<MadarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final theme = Theme.of(context).textTheme;
    final style = widget.onPressed == null
        ? MadarButtonStyle.disabled(t, widget.variant)
        : MadarButtonStyle.of(t, widget.variant);
    final h = MadarButton.heightFor(widget.size);
    final iconSize = switch (widget.size) {
      MadarButtonSize.small => 17.0,
      MadarButtonSize.medium => 20.0,
      MadarButtonSize.large => 22.0,
    };
    final textStyle = (switch (widget.size) {
      MadarButtonSize.small => theme.labelMedium,
      MadarButtonSize.medium => theme.labelLarge,
      MadarButtonSize.large => theme.titleMedium,
    })!.copyWith(color: style.foreground, fontWeight: FontWeight.w600, height: 1.2);
    final duration = context.motion(MadarMotion.short);

    Widget content;
    if (widget.isIconOnly) {
      content = Icon(widget.icon, size: iconSize + 2, color: style.foreground);
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: iconSize, color: style.foreground),
            SizedBox(width: widget.size == MadarButtonSize.small ? Space.xs + 2 : Space.s),
          ],
          Flexible(
            child: Text(
              widget.label!,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          if (widget.trailingIcon != null) ...[
            SizedBox(width: widget.size == MadarButtonSize.small ? Space.xs : Space.s - 2),
            Icon(widget.trailingIcon, size: iconSize - 2, color: style.foreground),
          ],
        ],
      );
    }

    final loaderColor = widget.variant == MadarButtonVariant.primary ? t.textOnAccent : t.accent;
    content = Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(opacity: widget.loading ? 0 : 1, duration: duration, child: content),
        if (widget.loading) OrbitLoader(size: h * 0.62, color: loaderColor, secondaryColor: loaderColor),
      ],
    );

    final radius = BorderRadius.circular(h / 2);
    final hPad = switch (widget.size) {
      MadarButtonSize.small => Space.m + 2,
      MadarButtonSize.medium => Space.xl - 2,
      MadarButtonSize.large => Space.xxl - 4,
    };

    final glow = style.glow;
    Widget surface = AnimatedContainer(
      duration: duration,
      curve: MadarMotion.standard,
      height: h,
      width: widget.isIconOnly ? h : (widget.expand ? double.infinity : null),
      constraints: widget.isIconOnly ? null : BoxConstraints(minWidth: h * 1.8),
      padding: widget.isIconOnly ? EdgeInsets.zero : EdgeInsetsDirectional.symmetric(horizontal: hPad),
      decoration: BoxDecoration(
        borderRadius: radius,
        color: _pressed && style.pressedFill != null
            ? Color.alphaBlend(style.pressedFill!, style.fill ?? Colors.transparent)
            : style.fill,
        gradient: style.gradient == null
            ? null
            : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: style.gradient!),
        boxShadow: glow == null || !widget.enabled
            ? null
            : [
                BoxShadow(
                  color: glow.withValues(alpha: glow.a * (_pressed ? 0.9 : 0.6)),
                  blurRadius: _pressed ? 26 : 18,
                  spreadRadius: -5,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      // widthFactor 1: hug the label (a Container alignment would stretch).
      child: Center(widthFactor: widget.expand ? null : 1, child: content),
    );

    final border = style.border;
    if (border != null) {
      surface = CustomPaint(
        foregroundPainter: GlassBorderPainter(
          radius: radius,
          highlight: style.gradient != null ? t.glassHighlight : Color.lerp(border, t.glassHighlight, 0.6)!,
          border: style.gradient != null ? border.withValues(alpha: 0) : border,
          direction: Directionality.of(context),
        ),
        child: surface,
      );
    }

    final loadingLabel = Localizations.of<L10n>(context, L10n)?.designLoading;
    final semantic = widget.semanticLabel ?? widget.label;
    surface = MadarPressable(
      onTap: widget.enabled ? widget.onPressed : null,
      sfx: widget.sfx,
      semanticLabel: widget.loading && loadingLabel != null ? '${semantic ?? ''} ($loadingLabel)' : semantic,
      excludeChildSemantics: true,
      focusRadius: radius,
      onPressedChanged: (v) {
        if (mounted) setState(() => _pressed = v);
      },
      child: AnimatedOpacity(opacity: widget.onPressed == null ? 0.72 : 1, duration: duration, child: surface),
    );
    if (widget.isIconOnly && widget.semanticLabel != null) {
      // No platform vibration (it bypasses the haptics setting); the
      // tooltip is paired with Madar's own tap sound + haptic instead.
      surface = Tooltip(
        message: widget.semanticLabel!,
        excludeFromSemantics: true,
        enableFeedback: false,
        onTriggered: () => Fx.fire(Sfx.tap),
        child: surface,
      );
    }
    return surface;
  }
}
