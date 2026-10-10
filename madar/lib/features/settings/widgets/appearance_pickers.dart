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
    this.modeBadge,
    this.modeLabel,
  });

  final MadarThemeId id;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? customAccent;
  final double width;

  /// While following the device: a sun on the light-mode theme and a moon on
  /// the dark-mode one, with [modeLabel] for screen readers.
  final IconData? modeBadge;
  final String? modeLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    // Exactly what the theme would install, custom accent included.
    final preview = MadarPalettes.resolve(id, accent: customAccent);
    final height = width * 1.45;
    return MadarPressable(
      onTap: selected ? null : onTap,
      selected: selected,
      semanticLabel: modeLabel == null ? label : '$label${L10n.of(context).interactionListSeparator}$modeLabel',
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
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(t.radiusL),
                      child: CustomPaint(
                        size: Size(width, height),
                        painter: ThemeMiniPainter(preview, rtl: Directionality.of(context) == TextDirection.rtl),
                      ),
                    ),
                  ),
                  // Opposite the selection check (top right).
                  if (modeBadge != null)
                    Positioned(
                      left: 7,
                      top: 7,
                      child: _ModeBadge(icon: modeBadge!, tokens: preview),
                    ),
                ],
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

/// A small glass disc with a sun / moon, drawn in the previewed theme.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.icon, required this.tokens});

  final IconData icon;
  final MadarTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(tokens.glassFill, tokens.space1),
        border: Border.all(color: tokens.gold.withValues(alpha: 0.7), width: 0.8),
      ),
      child: Icon(icon, size: 13, color: tokens.gold),
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

/// The five theme cards in a horizontally scrolling row. The selected card
/// is always brought into view – on first build (Pearl and Aurora sit past
/// the fold on a phone) and whenever the selection changes.
class ThemeCarousel extends StatefulWidget {
  const ThemeCarousel({
    super.key,
    required this.selected,
    required this.onSelected,
    this.customAccent,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
    this.cardWidth = 104,
    this.followSystem = false,
  });

  final MadarThemeId selected;
  final ValueChanged<MadarThemeId> onSelected;
  final Color? customAccent;
  final EdgeInsetsGeometry padding;
  final double cardWidth;

  /// Following the device: Pearl carries a sun (light mode) and the chosen
  /// theme a moon (dark mode).
  final bool followSystem;

  static const double spacing = Space.m;

  /// Scroll offset that centres card [index] in a [viewport]-wide row
  /// (clamped to the scroll range). Pure – unit-tested.
  static double offsetFor(
    int index, {
    required int count,
    required double cardWidth,
    required double viewport,
    required double paddingStart,
    required double paddingEnd,
  }) {
    final content = paddingStart + paddingEnd + count * cardWidth + (count - 1) * spacing;
    final max = math.max(0.0, content - viewport);
    final cardStart = paddingStart + index * (cardWidth + spacing);
    return (cardStart + cardWidth / 2 - viewport / 2).clamp(0.0, max);
  }

  @override
  State<ThemeCarousel> createState() => _ThemeCarouselState();
}

class _ThemeCarouselState extends State<ThemeCarousel> {
  ScrollController? _scroll;
  double _viewport = 0;

  double _target(BuildContext context) {
    final padding = widget.padding.resolve(Directionality.of(context));
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ThemeCarousel.offsetFor(
      MadarThemeId.values.indexOf(widget.selected),
      count: MadarThemeId.values.length,
      cardWidth: widget.cardWidth,
      viewport: _viewport,
      // The list scrolls from the reading start.
      paddingStart: rtl ? padding.right : padding.left,
      paddingEnd: rtl ? padding.left : padding.right,
    );
  }

  @override
  void didUpdateWidget(ThemeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final scroll = _scroll;
    if (oldWidget.selected != widget.selected && scroll != null && scroll.hasClients) {
      final target = _target(context);
      if (context.reducedMotion) {
        scroll.jumpTo(target);
      } else {
        scroll.animateTo(target, duration: MadarMotion.long, curve: MadarMotion.standard);
      }
    }
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    // Card + gap + one line of label, grown with the user's text size.
    final label = Theme.of(context).textTheme.labelLarge!;
    final labelHeight = MediaQuery.textScalerOf(context).scale(label.fontSize!) * (label.height ?? 1.3);
    return SizedBox(
      height: widget.cardWidth * 1.45 + Space.xs + Space.s + labelHeight.ceilToDouble() + 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.maxWidth;
          final scroll = _scroll ??= ScrollController(initialScrollOffset: _target(context));
          return ListView.separated(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            padding: widget.padding,
            clipBehavior: Clip.none,
            itemCount: MadarThemeId.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: ThemeCarousel.spacing),
            itemBuilder: (context, i) {
              final id = MadarThemeId.values[i];
              return Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.xs),
                child: ThemePreviewCard(
                  id: id,
                  width: widget.cardWidth,
                  label: themeName(l, id),
                  selected: id == widget.selected,
                  customAccent: widget.customAccent,
                  onTap: () => widget.onSelected(id),
                  modeBadge: !widget.followSystem
                      ? null
                      : id == MadarThemeId.pearl
                      ? Icons.light_mode_rounded
                      : (id == widget.selected ? Icons.dark_mode_rounded : null),
                  modeLabel: !widget.followSystem
                      ? null
                      : id == MadarThemeId.pearl
                      ? l.settingsThemeLightMode
                      : (id == widget.selected ? l.settingsThemeDarkMode : null),
                ),
              );
            },
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

/// Theme accent, a planet colour or any hue, as glowing swatches over a hue
/// rail. Every swatch shows the colour *as it will be used* in [theme]: a
/// custom accent is adjusted per theme so it stays legible (see
/// `MadarPalettes.withAccent`), and the stored value stays the user's raw
/// pick so another theme can adapt it again.
class AccentPicker extends StatelessWidget {
  const AccentPicker({super.key, required this.theme, required this.value, required this.onChanged});

  /// The theme whose own accent is the first ("theme colour") swatch.
  final MadarThemeId theme;

  /// null = the theme's own accent.
  final Color? value;
  final ValueChanged<Color?> onChanged;

  /// Swatch planets, in the planets' orbit order.
  static const List<String> planetKeys = ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel'];

  /// Saturation and lightness of colours picked on the hue rail (the raw
  /// pick – the theme then adjusts the lightness).
  static const double railSaturation = 0.72;
  static const double railLightness = 0.6;

  /// The raw accent for [hue] on the rail.
  static Color colorForHue(double hue) => HSLColor.fromAHSL(1, hue % 360, railSaturation, railLightness).toColor();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final base = MadarPalettes.tokensFor(theme);
    final shown = MadarPalettes.resolve(theme, accent: value).accent;
    final isPlanet = value != null && accentChoices.any((c) => c.toARGB32() == value!.toARGB32());
    return Semantics(
      container: true,
      label: l.settingsAccent,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              _Swatch(
                raw: base.accent,
                theme: theme,
                selected: value == null,
                label: l.settingsAccentDefault,
                icon: Icons.auto_awesome_rounded,
                onTap: () => onChanged(null),
              ),
              for (final key in planetKeys)
                _Swatch(
                  raw: PlanetPalettes.byKey[key]!.surface,
                  theme: theme,
                  selected: value?.toARGB32() == PlanetPalettes.byKey[key]!.surface.toARGB32(),
                  label: l.settingsAccentPlanet(planetName(l, key)),
                  onTap: () => onChanged(PlanetPalettes.byKey[key]!.surface),
                ),
            ],
          ),
          const SizedBox(height: Space.m),
          AccentHueRail(
            theme: theme,
            // The raw pick's hue (the theme may nudge the shown colour's hue
            // by a degree or two; the thumb stays where the finger left it).
            hue: HSLColor.fromColor(value ?? shown).hue,
            color: shown,
            custom: value != null && !isPlanet,
            onChanged: (h) => onChanged(colorForHue(h)),
          ),
        ],
      ),
    );
  }
}

/// Localised planet name for the accent swatches' labels.
String planetName(L10n l, String key) => switch (key) {
  'faith' => l.planetFaith,
  'health' => l.planetHealth,
  'family' => l.planetFamily,
  'work' => l.planetWork,
  'money' => l.planetMoney,
  'growth' => l.planetGrowth,
  'body' => l.planetBody,
  'travel' => l.planetTravel,
  _ => key,
};

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.raw,
    required this.theme,
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
  });

  /// The colour as picked; shown as [theme] will use it.
  final Color raw;
  final MadarThemeId theme;
  final bool selected;
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  /// Visual diameter; the tap target is [target] square.
  static const double size = 38;
  static const double target = 48;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final resolved = MadarPalettes.resolve(theme, accent: raw);
    final color = resolved.accent;
    final onColor = resolved.textOnAccent;
    return MadarPressable(
      onTap: selected ? null : onTap,
      selected: selected,
      semanticLabel: label,
      excludeChildSemantics: true,
      sfx: Sfx.tap,
      child: SizedBox.square(
        dimension: target,
        child: Center(
          child: AnimatedContainer(
            duration: context.motion(MadarMotion.short),
            curve: MadarMotion.standard,
            width: size,
            height: size,
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
                  colors: [Color.lerp(color, onColor, 0.3)!, color],
                ),
              ),
              child: Center(
                child: selected
                    ? Icon(Icons.check_rounded, size: 16, color: onColor)
                    : (icon == null ? null : Icon(icon, size: 14, color: onColor)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rainbow rail for any accent hue. The rail is painted in the colours the
/// theme will really use (each hue already adjusted for legibility), the
/// thumb wears the current accent, and dragging clicks softly every 30°.
class AccentHueRail extends StatefulWidget {
  const AccentHueRail({
    super.key,
    required this.theme,
    required this.hue,
    required this.color,
    required this.custom,
    required this.onChanged,
  });

  final MadarThemeId theme;

  /// Hue (0–360) of the current accent.
  final double hue;

  /// The current accent as the theme uses it (the thumb).
  final Color color;

  /// Whether the current accent came from this rail (highlights the rail).
  final bool custom;
  final ValueChanged<double> onChanged;

  /// The rail's gradient: [steps] hues, each as [theme] would show it
  /// (computed once per theme – each colour runs a contrast search).
  static List<Color> railColors(MadarThemeId theme, {int steps = 13}) => _railCache.putIfAbsent(
    (theme, steps),
    () => [
      for (var i = 0; i < steps; i++)
        MadarPalettes.resolve(theme, accent: AccentPicker.colorForHue(360.0 * i / (steps - 1))).accent,
    ],
  );

  static final Map<(MadarThemeId, int), List<Color>> _railCache = {};

  @override
  State<AccentHueRail> createState() => _AccentHueRailState();
}

class _AccentHueRailState extends State<AccentHueRail> {
  /// The hue under the finger while dragging: previewed on the thumb only.
  /// The accent is saved once, on release – saving on every pointer move
  /// would write the settings to disk and re-theme (and animate) the whole
  /// app up to 60 times a second.
  double? _dragHue;

  void _onChanged(double hue) {
    final previous = _dragHue ?? widget.hue;
    if ((previous / 30).floor() != (hue / 30).floor()) Fx.fire(Sfx.countTick);
    setState(() => _dragHue = hue);
  }

  void _onEnd(double hue) {
    Fx.fire(Sfx.drop);
    widget.onChanged(hue);
    setState(() => _dragHue = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final dragging = _dragHue;
    final hue = (dragging ?? widget.hue).clamp(0.0, 360.0);
    final thumb = dragging == null
        ? widget.color
        : MadarPalettes.resolve(widget.theme, accent: AccentPicker.colorForHue(dragging)).accent;
    final custom = widget.custom || dragging != null;
    final rail = AccentHueRail.railColors(widget.theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.colorize_rounded, size: 16, color: custom ? thumb : t.textSecondary),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text(
                l.settingsAccentCustom,
                style: text.labelLarge!.copyWith(color: custom ? t.textPrimary : t.textSecondary),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 10,
            trackShape: _HueTrackShape(rail, border: t.glassBorder),
            thumbColor: thumb,
            overlayColor: thumb.withValues(alpha: 0.18),
            thumbShape: _HueThumbShape(ring: t.textPrimary, shadow: t.glassShadow),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: hue,
            max: 360,
            label: l.settingsAccentCustom,
            onChanged: _onChanged,
            onChangeEnd: _onEnd,
            semanticFormatterCallback: (v) => l.settingsAccentHueValue(fmt.formatInt(v.round())),
          ),
        ),
        Text(l.settingsAccentCustomHint, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.4)),
      ],
    );
  }
}

/// The rainbow track (no active / inactive split).
class _HueTrackShape extends RoundedRectSliderTrackShape {
  const _HueTrackShape(this.colors, {required this.border});

  final List<Color> colors;
  final Color border;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2));
    // The slider runs from the reading start: mirror the rainbow in RTL so
    // the thumb always sits on its own colour.
    final stops = textDirection == TextDirection.rtl ? colors.reversed.toList() : colors;
    context.canvas
      ..drawRRect(rrect, Paint()..shader = LinearGradient(colors: stops).createShader(rect))
      ..drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = border,
      );
  }
}

/// A jewel thumb: the accent itself inside a light ring.
class _HueThumbShape extends SliderComponentShape {
  const _HueThumbShape({required this.ring, required this.shadow});

  final Color ring;
  final Color shadow;

  static const double radius = 12;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final r = radius + 2 * activationAnimation.value;
    canvas
      ..drawCircle(center.translate(0, 1.5), r, Paint()..color = shadow)
      ..drawCircle(center, r, Paint()..color = ring)
      ..drawCircle(center, r - 3, Paint()..color = sliderTheme.thumbColor ?? ring);
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
