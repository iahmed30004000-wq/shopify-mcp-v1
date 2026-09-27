import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design/painters/astrolabe_ticks_painter.dart';
import '../../core/design/painters/islamic_star_painter.dart';
import '../../core/design/themes.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/gen/app_localizations.dart';
import 'design_gallery_screen.dart';

/// The scrolling content of the design gallery.
class GalleryBody extends StatelessWidget {
  const GalleryBody({
    super.key,
    required this.theme,
    required this.direction,
    required this.demo,
    required this.arabicDigits,
    required this.onTheme,
    required this.onDirection,
    required this.onDemo,
    required this.onStartLoading,
  });

  final MadarThemeId theme;
  final TextDirection direction;
  final GalleryDemoState demo;
  final bool arabicDigits;
  final ValueChanged<MadarThemeId> onTheme;
  final ValueChanged<TextDirection> onDirection;
  final ValueChanged<GalleryDemoState> onDemo;
  final VoidCallback onStartLoading;

  String _digits(String s) => arabicDigits ? AstrolabeScale.toArabicIndic(s, separators: true) : s;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsetsDirectional.only(top: top + Space.s, bottom: 120),
      children: [
        _Hero(theme: theme, direction: direction, onTheme: onTheme, onDirection: onDirection),
        SectionHeader(title: l.designSectionSurfaces),
        _Surfaces(digits: _digits),
        SectionHeader(title: l.designSectionButtons),
        _Buttons(loading: demo.loading, onStartLoading: onStartLoading),
        SectionHeader(title: l.designSectionChips),
        _Choices(demo: demo, onDemo: onDemo),
        SectionHeader(title: l.designSectionToggles),
        _Toggles(demo: demo, onDemo: onDemo),
        SectionHeader(title: l.designSectionProgress),
        _Rings(demo: demo, onDemo: onDemo, digits: _digits),
        SectionHeader(title: l.designSectionStats, actionLabel: l.designSeeAll, onAction: () {}),
        _Stats(digits: _digits),
        SectionHeader(title: l.designSectionOrnaments),
        const _Ornaments(),
        SectionHeader(title: l.designSectionLoaders),
        const _Loaders(),
        SectionHeader(title: l.designSectionEmpty),
        const _EmptyStates(),
        SectionHeader(title: l.designSectionType),
        const _TypeAndColour(),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.theme, required this.direction, required this.onTheme, required this.onDirection});

  final MadarThemeId theme;
  final TextDirection direction;
  final ValueChanged<MadarThemeId> onTheme;
  final ValueChanged<TextDirection> onDirection;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final names = {
      MadarThemeId.lapis: l.designThemeLapis,
      MadarThemeId.emerald: l.designThemeEmerald,
      MadarThemeId.desert: l.designThemeDesert,
      MadarThemeId.aurora: l.designThemeAurora,
      MadarThemeId.pearl: l.designThemePearl,
    };
    return Padding(
      padding: galleryGutter,
      child: GlassPanel(
        padding: EdgeInsetsDirectional.zero,
        child: Stack(
          children: [
            PositionedDirectional(
              top: -38,
              end: -38,
              child: Opacity(opacity: 0.55, child: GirihRosette(size: 150, rotation: math.pi / 8)),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l + 2, Space.l + 2, Space.l + 2, Space.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.appName, style: text.displaySmall!.copyWith(color: t.accent)),
                  Text(l.designGallerySubtitle, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
                  const SizedBox(height: Space.l),
                  _Label(l.designGalleryTheme),
                  ChoicePills<MadarThemeId>.single(
                    scrollable: true,
                    dense: true,
                    options: [
                      for (final id in MadarThemeId.values)
                        ChoiceOption(value: id, label: names[id]!, color: MadarPalettes.tokensFor(id).accent),
                    ],
                    selected: theme,
                    onChanged: (id) => onTheme(id!),
                  ),
                  const SizedBox(height: Space.m),
                  _Label(l.designGalleryDirection),
                  ChoicePills<TextDirection>.single(
                    dense: true,
                    options: [
                      ChoiceOption(
                        value: TextDirection.rtl,
                        label: l.designDirectionRtl,
                        icon: Icons.format_textdirection_r_to_l_rounded,
                      ),
                      ChoiceOption(
                        value: TextDirection.ltr,
                        label: l.designDirectionLtr,
                        icon: Icons.format_textdirection_l_to_r_rounded,
                      ),
                    ],
                    selected: direction,
                    onChanged: (d) => onDirection(d!),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.s),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: context.tokens.textTertiary)),
    );
  }
}

class _Surfaces extends StatelessWidget {
  const _Surfaces({required this.digits});

  final String Function(String) digits;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final rows = [
      (l.planetFaith, PlanetPalettes.faith, 5, Icons.brightness_3_rounded),
      (l.planetHealth, PlanetPalettes.health, 3, Icons.favorite_rounded),
      (l.planetGrowth, PlanetPalettes.growth, 8, Icons.spa_rounded),
    ];
    return Padding(
      padding: galleryGutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.designPanelTitle, style: text.titleLarge),
                const SizedBox(height: Space.xs),
                Text(l.designPanelBody, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          Text(l.designCardBody, style: text.bodySmall!.copyWith(color: t.textTertiary)),
          const SizedBox(height: Space.s),
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: Space.s),
            GlassCard(
              seed: i.toDouble(),
              onTap: () {},
              semanticLabel: row.$1,
              padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
              child: Row(
                children: [
                  _PlanetBadge(palette: row.$2, icon: row.$4),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.$1, style: text.titleMedium),
                        Text(digits(l.itemsCount(row.$3)), style: text.bodySmall),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: t.textTertiary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanetBadge extends StatelessWidget {
  const _PlanetBadge({required this.palette, required this.icon});

  final PlanetPalette palette;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const AlignmentDirectional(-0.35, -0.4).resolve(Directionality.of(context)),
          colors: [palette.glow, palette.surface, palette.deep],
          stops: const [0, 0.55, 1],
        ),
        boxShadow: [BoxShadow(color: palette.surface.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: -3)],
      ),
      child: Icon(icon, size: 20, color: palette.deep),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.loading, required this.onStartLoading});

  final bool loading;
  final VoidCallback onStartLoading;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: galleryGutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadarButton(
            label: l.designButtonPrimary,
            icon: Icons.wb_twilight_rounded,
            size: MadarButtonSize.large,
            expand: true,
            onPressed: () {},
          ),
          const SizedBox(height: Space.m),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MadarButton(label: l.actionSave, loading: loading, onPressed: onStartLoading),
              MadarButton(label: l.designButtonSecondary, variant: MadarButtonVariant.secondary, onPressed: () {}),
              MadarButton(
                label: l.designButtonGhost,
                variant: MadarButtonVariant.ghost,
                trailingIcon: Icons.chevron_right_rounded,
                onPressed: () {},
              ),
              MadarButton(
                label: l.actionDelete,
                icon: Icons.delete_outline_rounded,
                variant: MadarButtonVariant.danger,
                onPressed: () {},
              ),
              MadarButton(
                label: l.actionEdit,
                variant: MadarButtonVariant.secondary,
                size: MadarButtonSize.small,
                icon: Icons.edit_rounded,
                onPressed: () {},
              ),
              MadarButton(label: l.actionContinue, onPressed: null),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              MadarButton.icon(icon: Icons.search_rounded, semanticLabel: l.actionSearch, onPressed: () {}),
              const SizedBox(width: Space.s),
              MadarButton.icon(
                icon: Icons.notifications_none_rounded,
                semanticLabel: l.actionSetReminder,
                onPressed: () {},
              ),
              const SizedBox(width: Space.s),
              MadarButton.icon(
                icon: Icons.undo_rounded,
                semanticLabel: l.actionUndo,
                variant: MadarButtonVariant.ghost,
                onPressed: () {},
              ),
              const SizedBox(width: Space.s),
              MadarButton.icon(
                icon: Icons.add_rounded,
                semanticLabel: l.actionAdd,
                variant: MadarButtonVariant.primary,
                onPressed: () {},
              ),
              const SizedBox(width: Space.s),
              MadarButton.icon(
                icon: Icons.check_rounded,
                semanticLabel: l.actionDone,
                variant: MadarButtonVariant.primary,
                loading: true,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({required this.demo, required this.onDemo});

  final GalleryDemoState demo;
  final ValueChanged<GalleryDemoState> onDemo;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final windows = {
      'fajr': l.windowFajr,
      'duha': l.windowDuha,
      'dhuhr': l.windowDhuhr,
      'asr': l.windowAsr,
      'maghrib': l.windowMaghrib,
      'isha': l.windowIsha,
    };
    final planets = {
      'faith': l.planetFaith,
      'health': l.planetHealth,
      'family': l.planetFamily,
      'work': l.planetWork,
      'money': l.planetMoney,
      'growth': l.planetGrowth,
      'body': l.planetBody,
      'travel': l.planetTravel,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: galleryGutter, child: _Label(l.designChipsSingle)),
        ChoicePills<String>.single(
          scrollable: true,
          padding: galleryGutter,
          options: [for (final e in windows.entries) ChoiceOption(value: e.key, label: e.value)],
          selected: demo.window,
          onChanged: (w) => onDemo(demo.copyWith(window: w)),
        ),
        const SizedBox(height: Space.l),
        Padding(padding: galleryGutter, child: _Label(l.designChipsMulti)),
        ChoicePills<String>.multi(
          padding: galleryGutter,
          maxSelected: 5,
          options: [
            for (final e in planets.entries)
              ChoiceOption(value: e.key, label: e.value, color: PlanetPalettes.byKey[e.key]!.surface),
          ],
          selected: demo.planets,
          onChanged: (p) => onDemo(demo.copyWith(planets: p)),
        ),
      ],
    );
  }
}

class _Toggles extends StatelessWidget {
  const _Toggles({required this.demo, required this.onDemo});

  final GalleryDemoState demo;
  final ValueChanged<GalleryDemoState> onDemo;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    Widget row(IconData icon, String label, bool value, ValueChanged<bool> onChanged) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.tokens.textSecondary),
          const SizedBox(width: Space.m),
          Expanded(child: Text(label, style: text.bodyLarge)),
          MadarSwitch(value: value, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
    return Padding(
      padding: galleryGutter,
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.m, Space.s),
        child: Column(
          children: [
            row(Icons.graphic_eq_rounded, l.designToggleSound, demo.sound, (v) => onDemo(demo.copyWith(sound: v))),
            const MadarDivider(ornament: false, height: 8),
            row(Icons.vibration_rounded, l.designToggleHaptics, demo.haptics, (v) => onDemo(demo.copyWith(haptics: v))),
            const MadarDivider(ornament: false, height: 8),
            row(
              Icons.motion_photos_off_rounded,
              l.designToggleReduceMotion,
              demo.reduceMotion,
              (v) => onDemo(demo.copyWith(reduceMotion: v)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rings extends StatelessWidget {
  const _Rings({required this.demo, required this.onDemo, required this.digits});

  final GalleryDemoState demo;
  final ValueChanged<GalleryDemoState> onDemo;
  final String Function(String) digits;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    Widget labelled(Widget ring, String label) => Expanded(
      child: Column(
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: ring),
          const SizedBox(height: Space.s),
          Text(
            label,
            style: text.labelMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    final pct = '${(demo.ring * 100).round()}';
    return Padding(
      padding: galleryGutter,
      child: GlassCard(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.l, horizontal: Space.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelled(
              MadarPressable(
                onTap: () => onDemo(demo.copyWith(ring: demo.ring >= 0.95 ? 0.18 : math.min(1, demo.ring + 0.2))),
                child: ProgressRing(
                  value: demo.ring,
                  size: 92,
                  semanticLabel: l.designRingDaily,
                  child: Text(
                    digits(pct),
                    style: MadarTypography.numerals(t, size: 22).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              l.designRingDaily,
            ),
            labelled(
              ProgressRing(
                value: 3 / 5,
                size: 92,
                strokeWidth: 6,
                color: PlanetPalettes.faith.surface,
                gradientEnd: PlanetPalettes.faith.glow,
                semanticLabel: l.designRingPrayers,
                child: Text(
                  digits('3/5'),
                  textDirection: TextDirection.ltr,
                  style: MadarTypography.numerals(t, size: 20),
                ),
              ),
              l.designRingPrayers,
            ),
            labelled(
              ProgressRing(
                value: 1,
                size: 92,
                strokeWidth: 10,
                color: t.success,
                semanticLabel: l.designRingDone,
                child: Icon(Icons.check_rounded, color: t.success, size: 30),
              ),
              l.designRingDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.digits});

  final String Function(String) digits;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final vs = l.designStatVsLastWeek;
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: Space.m),
        Expanded(child: b),
      ],
    );
    return Padding(
      padding: galleryGutter,
      child: Column(
        children: [
          pair(
            StatTile(
              label: l.designStatStreak,
              value: digits('12'),
              unit: l.designUnitDays(12),
              icon: Icons.local_fire_department_rounded,
              color: PlanetPalettes.faith.surface,
              trend: StatTrend.up,
              trendLabel: digits('+3'),
              onTap: () {},
            ),
            StatTile(
              label: l.designStatSteps,
              value: digits('8,420'),
              icon: Icons.directions_walk_rounded,
              color: PlanetPalettes.health.surface,
              trend: StatTrend.up,
              trendLabel: digits('+12%'),
              caption: vs,
            ),
          ),
          const SizedBox(height: Space.m),
          pair(
            StatTile(
              label: l.designStatWater,
              value: digits('1.6'),
              unit: l.designUnitLitres,
              icon: Icons.water_drop_rounded,
              color: PlanetPalettes.travel.surface,
              trend: StatTrend.down,
              trendLabel: digits('-8%'),
            ),
            StatTile(
              label: l.designStatFocus,
              value: digits('3.5'),
              unit: l.designUnitHours,
              icon: Icons.center_focus_strong_rounded,
              color: PlanetPalettes.work.glow,
              trend: StatTrend.flat,
              trendLabel: digits('0%'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ornaments extends StatelessWidget {
  const _Ornaments();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    // Flexible cells: ornaments scale down and captions wrap, so the rows
    // hold up at any width and text scale.
    Widget captioned(Widget child, String caption) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: child),
          const SizedBox(height: Space.s),
          Text(
            caption,
            style: text.labelMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    return Padding(
      padding: galleryGutter,
      child: GlassPanel(
        seed: 3,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                captioned(const IslamicStar(size: 58, glow: true), l.designOrnamentStar),
                captioned(
                  CustomPaint(
                    size: const Size.square(58),
                    painter: IslamicStarPainter(
                      style: IslamicStarStyle.rubElHizb,
                      fillColor: t.accentSoft,
                      strokeColor: t.gold,
                      strokeWidth: 1.6,
                      centerDotColor: t.gold,
                    ),
                  ),
                  l.designOrnamentRub,
                ),
                captioned(
                  CustomPaint(
                    size: const Size.square(58),
                    painter: IslamicStarPainter(
                      points: 12,
                      strokeColor: t.brass,
                      strokeWidth: 1.4,
                      fillColor: t.accentSoft,
                    ),
                  ),
                  l.designOrnamentStar12,
                ),
              ],
            ),
            const SizedBox(height: Space.l),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                captioned(const GirihRosette(size: 138), l.designOrnamentRosette),
                captioned(
                  const AstrolabeRing(
                    size: 138,
                    child: IslamicStar(size: 46, style: IslamicStarStyle.rubElHizb, filled: false, glow: true),
                  ),
                  l.designOrnamentAstrolabe,
                ),
              ],
            ),
            const SizedBox(height: Space.l),
            const ArabesqueBorder(height: 30),
            const SizedBox(height: Space.xs),
            Text(l.designOrnamentArabesque, style: text.labelMedium),
            const MadarDivider(),
          ],
        ),
      ),
    );
  }
}

class _Loaders extends StatelessWidget {
  const _Loaders();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: galleryGutter,
      child: GlassCard(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const OrbitLoader(size: 24),
            const OrbitLoader(size: 44),
            OrbitLoader(size: 72, color: t.highlight),
          ],
        ),
      ),
    );
  }
}

class _EmptyStates extends StatelessWidget {
  const _EmptyStates();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: galleryGutter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            padding: EdgeInsetsDirectional.zero,
            child: AnimatedEmptyState(
              kind: EmptyStateKind.emptyList,
              actionLabel: l.actionAdd,
              actionIcon: Icons.add_rounded,
              onAction: () {},
            ),
          ),
          const SizedBox(height: Space.m),
          const GlassCard(
            padding: EdgeInsetsDirectional.zero,
            child: AnimatedEmptyState(kind: EmptyStateKind.noData),
          ),
          const SizedBox(height: Space.m),
          const GlassCard(
            padding: EdgeInsetsDirectional.zero,
            child: AnimatedEmptyState(kind: EmptyStateKind.noResults),
          ),
        ],
      ),
    );
  }
}

class _TypeAndColour extends StatelessWidget {
  const _TypeAndColour();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final swatches = [
      t.accent,
      t.secondary,
      t.highlight,
      t.gold,
      t.brass,
      t.success,
      t.warning,
      t.danger,
      t.info,
      t.nebulaA,
      t.nebulaB,
    ];
    return Padding(
      padding: galleryGutter,
      child: GlassPanel(
        seed: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.appName, style: text.displayMedium!.copyWith(color: t.gold)),
            Text(l.appTagline, style: text.headlineSmall),
            const SizedBox(height: Space.s),
            Text(l.designTypeSample, style: text.bodyLarge!.copyWith(color: t.textSecondary)),
            const MadarDivider(),
            Wrap(
              spacing: Space.s + 2,
              runSpacing: Space.s + 2,
              children: [
                for (final c in swatches)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.glassHighlight, width: 0.8),
                      boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 10, spreadRadius: -2)],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
