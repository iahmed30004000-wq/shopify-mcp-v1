import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/pantry.dart';
import '../../domain/pantry_match.dart';

/// «السفرة»'s semantic colours, derived from the theme tokens so all five
/// themes (Pearl included) keep their contrast. Nothing here is read from
/// the planet's own colour, which lives on the sky.
class SufraPalette {
  SufraPalette(this.t);

  factory SufraPalette.of(BuildContext context) => SufraPalette(context.tokens);

  final MadarTokens t;

  /// A dish she can cook now.
  Color get ready => t.success;

  /// Nearly there – something to buy.
  Color get nearly => t.warning;

  /// Madar cannot work it out: the colour of a question, not of a mistake.
  Color get unsure => t.info;

  /// Nothing left, or past its date.
  Color get out => t.danger;

  /// The pantry itself.
  Color get pantry => t.gold;

  /// One of her standing constraints.
  Color get rule => Color.lerp(t.danger, t.gold, 0.35)!;

  /// What one verdict is painted in.
  Color verdict(MatchVerdict v) => switch (v) {
    MatchVerdict.cookNow => ready,
    MatchVerdict.nearly => nearly,
    MatchVerdict.unsure => unsure,
    MatchVerdict.far => t.textTertiary,
  };

  /// What one item of the house is painted in.
  Color state(PantryState s) => switch (s) {
    PantryState.out => out,
    PantryState.expired => out,
    PantryState.low => nearly,
    PantryState.expiringSoon => nearly,
    PantryState.ok => ready,
  };
}

/// Icon of one verdict (the same glyph everywhere in the kitchen).
IconData sufraVerdictIcon(MatchVerdict v) => switch (v) {
  MatchVerdict.cookNow => Icons.check_circle_rounded,
  MatchVerdict.nearly => Icons.shopping_basket_rounded,
  MatchVerdict.unsure => Icons.help_outline_rounded,
  MatchVerdict.far => Icons.remove_circle_outline_rounded,
};

/// Icon of one ingredient verdict.
IconData sufraCheckIcon(IngredientVerdict v) => switch (v) {
  IngredientVerdict.have => Icons.check_rounded,
  IngredientVerdict.short => Icons.exposure_neg_1_rounded,
  IngredientVerdict.missing => Icons.close_rounded,
  IngredientVerdict.unknownAmount => Icons.help_outline_rounded,
  IngredientVerdict.unknownUnit => Icons.straighten_rounded,
  IngredientVerdict.ambiguous => Icons.call_split_rounded,
};

/// Icon of one item of the house.
IconData sufraStateIcon(PantryState s) => switch (s) {
  PantryState.out => Icons.remove_shopping_cart_rounded,
  PantryState.expired => Icons.event_busy_rounded,
  PantryState.low => Icons.trending_down_rounded,
  PantryState.expiringSoon => Icons.schedule_rounded,
  PantryState.ok => Icons.check_rounded,
};

/// A card of the kitchen: a titled glass panel, the same one on every
/// screen.
class SufraCard extends StatelessWidget {
  const SufraCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.l),
    this.onTap,
    this.semanticLabel,
    this.seed = 0,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      padding: padding,
      onTap: onTap,
      seed: seed,
      semanticLabel: semanticLabel,
      borderRadius: BorderRadius.circular(t.radiusL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: iconColor ?? t.gold), const SizedBox(width: Space.s)],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title!, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: Space.m),
          ],
          child,
        ],
      ),
    );
  }
}

/// A small tinted pill with an icon and a word.
class SufraPill extends StatelessWidget {
  const SufraPill({super.key, required this.label, this.icon, required this.color, this.dense = false});

  final String label;
  final IconData? icon;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        dense ? 6 : Space.s,
        dense ? 2 : 3,
        dense ? 8 : Space.s + 2,
        dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet one-line note with an icon – where the kitchen says what it
/// could not work out.
class SufraNote extends StatelessWidget {
  const SufraNote(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.color});

  final String text;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.textTertiary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: c),
        ),
        const SizedBox(width: Space.xs),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c)),
        ),
      ],
    );
  }
}

/// A heading between sections of a kitchen screen.
class SufraSectionTitle extends StatelessWidget {
  const SufraSectionTitle(this.title, {super.key, this.trailing, this.icon, this.color});

  final String title;
  final Widget? trailing;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, Space.s),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: color ?? t.gold), const SizedBox(width: Space.s)],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: text.titleSmall?.copyWith(color: t.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Loose and flex-free, so the action keeps its place at the end
          // of the row and a long label (hers, or an English one at text
          // scale 1.3) gives way instead of overflowing.
          if (trailing != null) Flexible(flex: 0, child: trailing!),
        ],
      ),
    );
  }
}

/// The kitchen's segmented control: the same glass bar Travel and Body
/// wear, with its thumb springing between the tabs in reading order.
class SufraTabBar<T> extends StatelessWidget {
  const SufraTabBar({
    super.key,
    required this.tabs,
    required this.value,
    required this.labels,
    required this.icons,
    required this.onChanged,
  });

  final List<T> tabs;
  final T value;
  final Map<T, String> labels;
  final Map<T, IconData> icons;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dir = Directionality.of(context);
    final index = tabs.indexOf(value);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      // 58 − 2 × 4 padding: every tab stays a 48 dp target.
      child: Container(
        height: 58,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusL),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth / tabs.length;
            return Stack(
              children: [
                SpringBuilder(
                  value: index.toDouble(),
                  spring: MadarMotion.snappy,
                  builder: (context, v, _) {
                    final x = dir == TextDirection.rtl ? constraints.maxWidth - w * (v + 1) : w * v;
                    return Positioned(
                      left: x,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(t.radiusL - 4),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color.lerp(t.accent, t.starTint, 0.18)!, t.accent],
                          ),
                          boxShadow: t.isDark
                              ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 14)]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (final tab in tabs)
                      Expanded(
                        child: MadarPressable(
                          semanticLabel: labels[tab],
                          selected: tab == value,
                          sfx: Sfx.navigate,
                          excludeChildSemantics: true,
                          onTap: () {
                            if (tab != value) onChanged(tab);
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icons[tab], size: 18, color: tab == value ? t.textOnAccent : t.textTertiary),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: context.motion(MadarMotion.short),
                                style: (text.labelSmall ?? const TextStyle()).copyWith(
                                  color: tab == value ? t.textOnAccent : t.textSecondary,
                                  fontWeight: tab == value ? FontWeight.w600 : FontWeight.w400,
                                ),
                                child: Text(labels[tab]!, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
