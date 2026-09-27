import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';

/// Localised theme name.
String themeName(L10n l, MadarThemeId id) => switch (id) {
  MadarThemeId.lapis => l.designThemeLapis,
  MadarThemeId.emerald => l.designThemeEmerald,
  MadarThemeId.desert => l.designThemeDesert,
  MadarThemeId.aurora => l.designThemeAurora,
  MadarThemeId.pearl => l.designThemePearl,
};

/// Accent swatches: every planet's signature colour (theme-independent
/// palette data).
List<Color> get accentChoices => [for (final p in PlanetPalettes.byKey.values) p.surface];

/// A live miniature of the app in theme [id]: its cosmos, a tiny astrolabe
/// dial, a glass panel with an accent pill – painted from that theme's
/// tokens, so what you see is what you get.
class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({
    super.key,
    required this.id,
    required this.label,
    required this.selected,
    required this.onTap,
    this.customAccent,
    this.width = 104,
  });

  final MadarThemeId id;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? customAccent;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    var preview = MadarPalettes.tokensFor(id);
    final accent = customAccent;
    if (accent != null) {
      preview = preview.copyWith(
        accent: accent,
        accentSoft: accent.withValues(alpha: 0.2),
        accentGlow: accent.withValues(alpha: 0.6),
      );
    }
    final height = width * 1.45;
    return MadarPressable(
      onTap: selected ? null : onTap,
      selected: selected,
      semanticLabel: label,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusL),
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: selected ? 1 : 0),
              duration: context.motion(MadarMotion.medium),
              curve: MadarMotion.standard,
              builder: (context, v, child) => CustomPaint(
                foregroundPainter: _SelectionRingPainter(
                  progress: v,
                  color: t.accent,
                  onColor: t.textOnAccent,
                  radius: t.radiusL,
                ),
                child: child,
              ),
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(t.radiusL),
                  child: CustomPaint(
                    size: Size(width, height),
                    painter: ThemeMiniPainter(preview, rtl: Directionality.of(context) == TextDirection.rtl),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.s),
            AnimatedDefaultTextStyle(
              duration: context.motion(MadarMotion.short),
              style: text.labelLarge!.copyWith(
                color: selected ? t.textPrimary : t.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionRingPainter extends CustomPainter {
  const _SelectionRingPainter({
    required this.progress,
    required this.color,
    required this.onColor,
    required this.radius,
  });

  final double progress;
  final Color color;
  final Color onColor;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)).inflate(3);
    paintOuterGlow(canvas, rrect, color.withValues(alpha: 0.45 * progress), 10);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: progress),
    );
    // Check badge at the top end corner.
    final c = Offset(size.width - 14, 14);
    canvas.drawCircle(c, 9 * progress, Paint()..color = color);
    final check = Path()
      ..moveTo(c.dx - 4, c.dy)
      ..lineTo(c.dx - 1.2, c.dy + 3)
      ..lineTo(c.dx + 4.2, c.dy - 3);
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = onColor.withValues(alpha: progress),
    );
  }

  @override
  bool shouldRepaint(_SelectionRingPainter old) =>
      old.progress != progress || old.color != color || old.onColor != onColor || old.radius != radius;
}

/// Paints a theme miniature from its [tokens].
class ThemeMiniPainter extends CustomPainter {
  const ThemeMiniPainter(this.tokens, {this.rtl = true});

  final MadarTokens tokens;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.space2, t.space0],
        ).createShader(rect),
    );
    // Nebulae.
    void nebula(Offset c, double r, Color color, double alpha) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    nebula(Offset(size.width * 0.2, size.height * 0.22), size.width * 0.75, t.nebulaA, t.isDark ? 0.55 : 0.8);
    nebula(Offset(size.width * 0.9, size.height * 0.55), size.width * 0.6, t.nebulaB, t.isDark ? 0.45 : 0.7);

    // Stars.
    final rnd = math.Random(7);
    final star = Paint()..color = t.starTint.withValues(alpha: t.isDark ? 0.9 : 0.5);
    for (var i = 0; i < 18; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.6),
        rnd.nextDouble() * 0.9 + 0.3,
        star,
      );
    }

    // Mini astrolabe.
    final dc = Offset(size.width / 2, size.height * 0.33);
    final dr = size.width * 0.26;
    canvas.drawCircle(
      dc,
      dr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = t.brass,
    );
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        dc + d * dr,
        dc + d * (dr - (i % 3 == 0 ? 4 : 2)),
        Paint()
          ..strokeWidth = 0.8
          ..color = t.gold.withValues(alpha: 0.8),
      );
    }
    final arc = Rect.fromCircle(center: dc, radius: dr * 0.7);
    canvas.drawArc(
      arc,
      -math.pi * 0.85,
      math.pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = t.accent,
    );
    canvas.drawCircle(dc, 2.2, Paint()..color = t.gold);

    // Glass panel.
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.08, size.height * 0.6, size.width * 0.84, size.height * 0.33),
      Radius.circular(size.width * 0.1),
    );
    canvas.drawRRect(panel, Paint()..color = Color.alphaBlend(t.glassFill, t.space1.withValues(alpha: 0.7)));
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = t.glassBorder.withValues(alpha: (t.glassBorder.a * 2).clamp(0.0, 1.0)),
    );
    final inset = size.width * 0.14;
    double x(double start, double w) => rtl ? size.width - start - w : start;
    final lineH = size.height * 0.03;
    // Title + subtitle bars, aligned to the reading start.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x(inset, size.width * 0.44), size.height * 0.66, size.width * 0.44, lineH),
        Radius.circular(lineH),
      ),
      Paint()..color = t.textPrimary.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x(inset, size.width * 0.3), size.height * 0.715, size.width * 0.3, lineH * 0.8),
        Radius.circular(lineH),
      ),
      Paint()..color = t.textTertiary.withValues(alpha: 0.9),
    );
    // Accent pill.
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(x(inset, size.width * 0.5), size.height * 0.78, size.width * 0.5, size.height * 0.085),
      Radius.circular(size.height * 0.05),
    );
    paintOuterGlow(canvas, pill, t.accentGlow.withValues(alpha: t.accentGlow.a * 0.7), 5);
    canvas.drawRRect(pill, Paint()..color = t.accent);
  }

  @override
  bool shouldRepaint(ThemeMiniPainter old) => old.tokens != tokens || old.rtl != rtl;
}

/// The five theme cards in a horizontally scrolling row.
class ThemeCarousel extends StatelessWidget {
  const ThemeCarousel({
    super.key,
    required this.selected,
    required this.onSelected,
    this.customAccent,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
    this.cardWidth = 104,
  });

  final MadarThemeId selected;
  final ValueChanged<MadarThemeId> onSelected;
  final Color? customAccent;
  final EdgeInsetsGeometry padding;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return SizedBox(
      height: cardWidth * 1.45 + 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        clipBehavior: Clip.none,
        itemCount: MadarThemeId.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.m),
        itemBuilder: (context, i) {
          final id = MadarThemeId.values[i];
          return Padding(
            padding: const EdgeInsetsDirectional.only(top: Space.xs),
            child: ThemePreviewCard(
              id: id,
              width: cardWidth,
              label: themeName(l, id),
              selected: id == selected,
              customAccent: customAccent,
              onTap: () => onSelected(id),
            ),
          );
        },
      ),
    );
  }
}

/// Arabic / English pills (each always written in its own language).
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, required this.languageCode, required this.onChanged});

  final String languageCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return ChoicePills<String>.single(
      options: [
        ChoiceOption(value: 'ar', label: l.settingsLanguageArabic, icon: Icons.translate_rounded),
        ChoiceOption(value: 'en', label: l.settingsLanguageEnglish, icon: Icons.language_rounded),
      ],
      selected: languageCode,
      onChanged: (v) {
        if (v != null && v != languageCode) onChanged(v);
      },
    );
  }
}

/// Theme accent or a planet colour, as glowing swatches.
class AccentPicker extends StatelessWidget {
  const AccentPicker({super.key, required this.theme, required this.value, required this.onChanged});

  /// The theme whose own accent is the first ("theme colour") swatch.
  final MadarThemeId theme;

  /// null = the theme's own accent.
  final Color? value;
  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Semantics(
      container: true,
      label: l.settingsAccent,
      child: Wrap(
        spacing: Space.m,
        runSpacing: Space.m,
        children: [
          _Swatch(
            color: MadarPalettes.tokensFor(theme).accent,
            selected: value == null,
            label: l.settingsAccentDefault,
            icon: Icons.auto_awesome_rounded,
            onTap: () => onChanged(null),
          ),
          for (final c in accentChoices)
            _Swatch(
              color: c,
              selected: value?.toARGB32() == c.toARGB32(),
              label: l.settingsAccentCustom,
              onTap: () => onChanged(c),
            ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.label, required this.onTap, this.icon});

  final Color color;
  final bool selected;
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? t.starTint : t.space0;
    return MadarPressable(
      onTap: selected ? null : onTap,
      selected: selected,
      semanticLabel: label,
      excludeChildSemantics: true,
      sfx: Sfx.tap,
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        curve: MadarMotion.standard,
        width: 38,
        height: 38,
        padding: EdgeInsets.all(selected ? 3 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? color : t.glassBorder, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 12)] : null,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.3, -0.35),
              colors: [Color.lerp(color, t.starTint, 0.35)!, color],
            ),
          ),
          child: Center(
            child: selected
                ? Icon(Icons.check_rounded, size: 16, color: onColor)
                : (icon == null ? null : Icon(icon, size: 14, color: onColor)),
          ),
        ),
      ),
    );
  }
}

/// Automatic / Western / Arabic-Indic digits with a live sample.
class DigitStylePicker extends StatelessWidget {
  const DigitStylePicker({super.key, required this.value, required this.onChanged});

  final DigitStyle value;
  final ValueChanged<DigitStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return ChoicePills<DigitStyle>.single(
      options: [
        ChoiceOption(value: DigitStyle.auto, label: l.settingsDigitsAuto, icon: Icons.auto_mode_rounded),
        ChoiceOption(value: DigitStyle.western, label: '${l.settingsDigitsWestern} 123'),
        ChoiceOption(
          value: DigitStyle.arabicIndic,
          label: '${l.settingsDigitsArabicIndic} ${Digits.toArabicIndic('123')}',
        ),
      ],
      selected: value,
      onChanged: (v) {
        if (v != null && v != value) onChanged(v);
      },
    );
  }
}
