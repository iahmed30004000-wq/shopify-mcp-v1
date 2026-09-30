import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/passphrase_strength.dart';

/// "1,234 records" with grouped, localised digits.
String recordsText(L10n l, MadarFormatter fmt, int count) =>
    fmt.localizeDigits(l.dataRecordsCount(count).replaceFirst('$count', fmt.formatInt(count)));

/// `12.4 KB` / `١٢٫٤ ك.ب` style size text.
String formatDataSize(L10n l, MadarFormatter fmt, int bytes) {
  if (bytes < 1024) return l.dataSizeBytes(fmt.formatInt(bytes));
  if (bytes < 1024 * 1024) return l.dataSizeKb(fmt.formatNumber(bytes / 1024, maxDecimals: 1));
  return l.dataSizeMb(fmt.formatNumber(bytes / (1024 * 1024), maxDecimals: 1));
}

/// A brass eight-point star with a glyph at its heart – the data centre's
/// emblem (vault, backup, restore, success).
class DataEmblem extends StatelessWidget {
  const DataEmblem({super.key, required this.icon, this.size = 84, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.accent;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.92,
              height: size * 0.92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [c.withValues(alpha: 0.22), c.withValues(alpha: 0)]),
              ),
            ),
            IslamicStar(size: size * 0.86, color: t.brass.withValues(alpha: 0.55), filled: false, strokeWidth: 1.1),
            IslamicStar(size: size * 0.64, color: c.withValues(alpha: 0.16), glow: true),
            Container(
              width: size * 0.44,
              height: size * 0.44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.space1.withValues(alpha: t.isDark ? 0.7 : 0.85),
                border: Border.all(color: c.withValues(alpha: 0.55), width: 1),
                boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 14)],
              ),
              child: Icon(icon, size: size * 0.24, color: c),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round tinted icon badge.
class DataIconBadge extends StatelessWidget {
  const DataIconBadge(this.icon, {super.key, this.color, this.size = 40});

  final IconData icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.14),
        border: Border.all(color: c.withValues(alpha: 0.38), width: 0.8),
      ),
      child: Icon(icon, size: size * 0.48, color: c),
    );
  }
}

/// A calm one-line note with an icon (info, warning, success).
class DataNote extends StatelessWidget {
  const DataNote({super.key, required this.text, this.icon = Icons.info_outline_rounded, this.color, this.dense = false});

  final String text;
  final IconData icon;
  final Color? color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.textSecondary;
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(color: c, height: 1.45);
    return Container(
      padding: EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: dense ? Space.s : Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusS),
        color: c.withValues(alpha: 0.08),
        border: Border.all(color: c.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 1),
            child: Icon(icon, size: 16, color: c),
          ),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// A pressable row inside a glass group: badge, title, subtitle, chevron.
class DataTile extends StatelessWidget {
  const DataTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.trailing,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;

  /// Shows a small loader instead of the chevron.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return MadarPressable(
      onTap: busy ? null : onTap,
      sfx: Sfx.navigate,
      semanticLabel: subtitle == null ? title : '$title. $subtitle',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
        child: Row(
          children: [
            DataIconBadge(icon, color: iconColor),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Text(subtitle!, style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.4)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            if (trailing != null)
              trailing!
            else if (busy)
              OrbitLoader(size: 22, color: t.accent)
            else
              Icon(rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Rows on one glass panel separated by hairlines.
class DataGroup extends StatelessWidget {
  const DataGroup({super.key, required this.children, this.seed = 0});

  final List<Widget> children;
  final double seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassPanel(
      padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
      seed: seed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
                child: Divider(height: 1, thickness: 0.6, color: t.glassBorder.withValues(alpha: 0.35)),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Text field styled for glass (used for passphrases and the "about me"
/// note).
InputDecoration dataInputDecoration(BuildContext context, {String? hint, String? label, Widget? suffix, String? error}) {
  final t = context.tokens;
  final text = Theme.of(context).textTheme;
  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(t.radiusS), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    labelText: label,
    errorText: error,
    errorMaxLines: 3,
    hintStyle: text.bodyMedium!.copyWith(color: t.textTertiary),
    labelStyle: text.bodyMedium!.copyWith(color: t.textSecondary),
    floatingLabelStyle: text.bodySmall!.copyWith(color: t.accent),
    errorStyle: text.bodySmall!.copyWith(color: t.danger),
    suffixIcon: suffix,
    filled: true,
    fillColor: t.space0.withValues(alpha: t.isDark ? 0.35 : 0.5),
    contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.m),
    border: border(t.glassBorder),
    enabledBorder: border(t.glassBorder),
    focusedBorder: border(t.accent, 1.3),
    errorBorder: border(t.danger),
    focusedErrorBorder: border(t.danger, 1.3),
  );
}

/// A passphrase field: hidden by default, no suggestions, no learning by the
/// keyboard, never autofilled or saved.
class PassphraseField extends StatefulWidget {
  const PassphraseField({
    super.key,
    required this.controller,
    required this.label,
    this.error,
    this.autofocus = false,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;

  @override
  State<PassphraseField> createState() => _PassphraseFieldState();
}

class _PassphraseFieldState extends State<PassphraseField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      obscureText: !_visible,
      obscuringCharacter: '•',
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp('[\n\r]'))],
      onSubmitted: widget.onSubmitted,
      style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.textPrimary, letterSpacing: _visible ? 0 : 1.5),
      cursorColor: t.accent,
      decoration: dataInputDecoration(
        context,
        label: widget.label,
        error: widget.error,
        suffix: IconButton(
          tooltip: _visible ? l.dataPassphraseHide : l.dataPassphraseShow,
          icon: Icon(_visible ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: t.textSecondary, size: 20),
          onPressed: () {
            Fx.fire(Sfx.tap);
            setState(() => _visible = !_visible);
          },
        ),
      ),
    );
  }
}

/// Five-segment strength meter with a label and one line of advice.
class PassphraseStrengthMeter extends StatelessWidget {
  const PassphraseStrengthMeter({super.key, required this.check});

  final PassphraseCheck check;

  static String levelLabel(L10n l, PassphraseLevel level) => switch (level) {
    PassphraseLevel.empty => l.dataStrengthEmpty,
    PassphraseLevel.veryWeak => l.dataStrengthVeryWeak,
    PassphraseLevel.weak => l.dataStrengthWeak,
    PassphraseLevel.fair => l.dataStrengthFair,
    PassphraseLevel.strong => l.dataStrengthStrong,
    PassphraseLevel.veryStrong => l.dataStrengthVeryStrong,
  };

  static String? hintText(L10n l, PassphraseHint? hint) => switch (hint) {
    PassphraseHint.tooShort => l.dataStrengthHintShort('${PassphraseStrength.minLength}'),
    PassphraseHint.common => l.dataStrengthHintCommon,
    PassphraseHint.pattern => l.dataStrengthHintPattern,
    PassphraseHint.onlyDigits => l.dataStrengthHintDigits,
    PassphraseHint.addWords => l.dataStrengthHintWords,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final color = switch (check.level) {
      PassphraseLevel.empty => t.textTertiary,
      PassphraseLevel.veryWeak || PassphraseLevel.weak => t.danger,
      PassphraseLevel.fair => t.warning,
      PassphraseLevel.strong => t.success,
      PassphraseLevel.veryStrong => t.success,
    };
    final filled = switch (check.level) {
      PassphraseLevel.empty => 0,
      PassphraseLevel.veryWeak => 1,
      PassphraseLevel.weak => 2,
      PassphraseLevel.fair => 3,
      PassphraseLevel.strong => 4,
      PassphraseLevel.veryStrong => 5,
    };
    final rawHint = hintText(l, check.hint);
    final hint = rawHint == null ? null : context.formatter.localizeDigits(rawHint);
    final duration = context.motion(MadarMotion.short);
    return Semantics(
      liveRegion: true,
      label: '${l.dataStrengthLabel}: ${levelLabel(l, check.level)}${hint == null ? '' : '. $hint'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(width: Space.xs),
                Expanded(
                  child: AnimatedContainer(
                    duration: duration,
                    curve: MadarMotion.emphasized,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i < filled ? color : t.glassBorder.withValues(alpha: 0.45),
                      boxShadow: i < filled ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6)] : null,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l.dataStrengthLabel}: ', style: text.bodySmall!.copyWith(color: t.textSecondary)),
              Text(levelLabel(l, check.level), style: text.bodySmall!.copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.xxs),
              child: Text(hint, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.4)),
            ),
        ],
      ),
    );
  }
}

/// Centered progress state: loader, title and a calm explanation.
class DataBusy extends StatelessWidget {
  const DataBusy({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xxl, horizontal: Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrbitLoader(size: 56, color: t.accent, semanticLabel: title),
            const SizedBox(height: Space.xl),
            Text(title, textAlign: TextAlign.center, style: text.titleMedium!.copyWith(color: t.textPrimary)),
            if (body != null) ...[
              const SizedBox(height: Space.s),
              Text(body!, textAlign: TextAlign.center, style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}
