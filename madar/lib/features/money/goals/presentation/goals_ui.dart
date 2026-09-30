import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/goals_providers.dart';
import '../domain/due_dates.dart';
import '../domain/goals_rates.dart';
import '../goals_texts.dart';

/// Bottom padding every tab leaves for the floating button.
const double goalsTabBottomPadding = 112;

/// Icons of the goals package.
abstract final class GoalsIcons {
  static const IconData jars = Icons.savings_rounded;
  static const IconData debts = Icons.handshake_rounded;
  static const IconData obligations = Icons.event_repeat_rounded;
  static const IconData deposit = Icons.south_rounded;
  static const IconData withdraw = Icons.north_rounded;
  static const IconData iOwe = Icons.call_made_rounded;
  static const IconData owedToMe = Icons.call_received_rounded;
  static const IconData paid = Icons.task_alt_rounded;
  static const IconData skip = Icons.redo_rounded;
  static const IconData settle = Icons.verified_rounded;
  static const IconData reopen = Icons.restart_alt_rounded;
  static const IconData archive = Icons.inventory_2_rounded;
  static const IconData unarchive = Icons.unarchive_rounded;
  static const IconData pause = Icons.pause_circle_outline_rounded;
  static const IconData resume = Icons.play_circle_outline_rounded;
  static const IconData reminders = Icons.notifications_active_outlined;
  static const IconData wallet = Icons.account_balance_wallet_rounded;
  static const IconData deadline = Icons.flag_rounded;
  static const IconData calendar = Icons.event_rounded;
  static const IconData note = Icons.notes_rounded;

  /// Icons offered for a jar (keys of the interaction kit's curated set, so
  /// imported and hand-picked jars share one vocabulary).
  static final Map<String, IconData> jarChoices = {
    for (final k in const [
      'savings',
      'plane',
      'luggage',
      'home',
      'car',
      'school',
      'mosque',
      'heart',
      'family',
      'child',
      'gift',
      'party',
      'laptop',
      'hospital',
      'trophy',
      'star',
      'coins',
      'explore',
    ])
      if (InteractionIcons.curated[k] != null) k: InteractionIcons.curated[k]!,
  };

  /// A stored jar icon key (unknown keys fall back to the savings jar).
  static IconData jar(String? key) => InteractionIcons.curated[key] ?? jars;

  /// The emoji an imported jar carries as its icon (`✈️`), or null for a
  /// curated key, a plain word or nothing.
  static String? jarEmoji(String? key) {
    final k = key?.trim();
    if (k == null || k.isEmpty || InteractionIcons.curated.containsKey(k)) return null;
    // Short and without letters or digits of any script: a pictograph.
    if (k.runes.length > 8 || RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(k)) return null;
    return k;
  }
}

/// A jar's icon: its curated glyph, or the emoji an import brought along.
class GoalsJarGlyph extends StatelessWidget {
  const GoalsJarGlyph({super.key, required this.icon, required this.color, this.size = 22});

  final String? icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emoji = GoalsIcons.jarEmoji(icon);
    if (emoji == null) return Icon(GoalsIcons.jar(icon), size: size, color: color);
    return ExcludeSemantics(
      child: Text(
        emoji,
        style: TextStyle(fontSize: size * 0.9, height: 1.1),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Tone of a due state (theme tokens).
Color dueColor(MadarTokens t, DueState state) => switch (state) {
  DueState.overdue => t.danger,
  DueState.today => t.warning,
  DueState.soon => t.gold,
  DueState.later || DueState.none => t.textTertiary,
};

/// The texts for the current snapshot's currencies.
GoalsTexts goalsTexts(BuildContext context, WidgetRef ref) =>
    GoalsTexts.of(context, ref.watch(goalsSnapshotProvider)?.rates ?? GoalsRates.single('JOD'));

/// Glass segmented tabs whose thumb springs between them (follows the
/// reading direction).
class GoalsTabBar<T> extends StatelessWidget {
  const GoalsTabBar({
    super.key,
    required this.values,
    required this.value,
    required this.labels,
    required this.icons,
    required this.onChanged,
    this.badges = const {},
  });

  final List<T> values;
  final T value;
  final Map<T, String> labels;
  final Map<T, IconData> icons;
  final ValueChanged<T> onChanged;

  /// A small count dot per tab (e.g. overdue items); 0 hides it.
  final Map<T, int> badges;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dir = Directionality.of(context);
    final index = values.indexOf(value);
    return Semantics(
      container: true,
      explicitChildNodes: true,
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
            final w = constraints.maxWidth / values.length;
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
                            colors: [t.accent.withValues(alpha: 0.32), t.accent.withValues(alpha: 0.16)],
                          ),
                          border: Border.all(color: t.accent.withValues(alpha: 0.55)),
                          boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.25), blurRadius: 12)],
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (final tab in values)
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icons[tab], size: 18, color: tab == value ? t.textPrimary : t.textTertiary),
                                  if ((badges[tab] ?? 0) > 0) ...[
                                    const SizedBox(width: 3),
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: t.danger,
                                        boxShadow: [BoxShadow(color: t.danger.withValues(alpha: 0.5), blurRadius: 6)],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: context.motion(MadarMotion.short),
                                style: (text.labelSmall ?? const TextStyle()).copyWith(
                                  color: tab == value ? t.textPrimary : t.textSecondary,
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

/// Builds a tab when first shown, keeps it alive afterwards and cross-fades
/// between them.
class GoalsFadeStack extends StatefulWidget {
  const GoalsFadeStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<GoalsFadeStack> createState() => _GoalsFadeStackState();
}

class _GoalsFadeStackState extends State<GoalsFadeStack> {
  final Set<int> _built = {};

  @override
  Widget build(BuildContext context) {
    final d = context.motion(MadarMotion.short);
    final index = widget.index;
    final children = widget.children;
    _built.add(index);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          if (!_built.contains(i))
            const SizedBox.shrink()
          else
            IgnorePointer(
              ignoring: i != index,
              child: ExcludeSemantics(
                excluding: i != index,
                child: TickerMode(
                  enabled: i == index,
                  child: AnimatedOpacity(opacity: i == index ? 1 : 0, duration: d, child: children[i]),
                ),
              ),
            ),
      ],
    );
  }
}

/// A small rounded status label ("متأخر يومين", "على المسار").
class GoalsPill extends StatelessWidget {
  const GoalsPill({super.key, required this.label, required this.color, this.icon, this.filled = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, 3, Space.s, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: filled ? 0.22 : 0.10),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: t.isDark ? color : Color.lerp(color, t.textPrimary, 0.25)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A headline card of a tab (glass, with a gold title row).
class GoalsHeaderCard extends StatelessWidget {
  const GoalsHeaderCard({super.key, required this.child, this.seed = 0, this.tint});

  final Widget child;
  final double seed;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassCard(
      seed: seed,
      tint: tint,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
      borderRadius: BorderRadius.circular(t.radiusXL),
      child: child,
    );
  }
}

/// A label over a value, for header stats.
class GoalsFigure extends StatelessWidget {
  const GoalsFigure({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.caption,
    this.large = false,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final Color? color;
  final String? caption;
  final bool large;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '$label: $value${caption == null ? '' : '. $caption'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Wraps rather than being cut at a large text size.
          Text(label, style: text.labelMedium?.copyWith(color: t.textSecondary), maxLines: 2),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: (large ? text.titleLarge?.copyWith(fontSize: 24, height: 1.25) : text.titleMedium)?.copyWith(
                color: color ?? t.textPrimary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: text.labelSmall?.copyWith(color: t.textTertiary), maxLines: 2),
          ],
        ],
      ),
    );
  }
}

/// A thin rounded progress bar (reading direction).
class GoalsBar extends StatelessWidget {
  const GoalsBar({super.key, required this.value, required this.color, this.height = 5, this.track});

  final double value;
  final Color color;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v),
      duration: context.motion(MadarMotion.long),
      curve: MadarMotion.emphasized,
      builder: (context, x, _) => Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          color: track ?? t.textTertiary.withValues(alpha: t.isDark ? 0.18 : 0.14),
        ),
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: x,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.65), color]),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title inside a tab list ("Due soon", "Settled").
class GoalsSectionTitle extends StatelessWidget {
  const GoalsSectionTitle(this.title, {super.key, this.count, this.color, this.trailing});

  final String title;
  final String? count;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.xs),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            IslamicStar(size: 10, color: color ?? t.brass),
            const SizedBox(width: Space.s),
            // The title and its count take all the free space, so the
            // trailing action sits flush at the end (a Flexible title next
            // to a Spacer would split the space and strand it mid-row).
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: text.titleSmall?.copyWith(color: color ?? t.gold, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: Space.s),
                    Text(count!, style: text.labelMedium?.copyWith(color: t.textTertiary)),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A round glyph medallion (initials, icons) with a soft glow ring.
class GoalsMedallion extends StatelessWidget {
  const GoalsMedallion({super.key, required this.color, this.icon, this.label, this.size = 44, this.badge});

  final Color color;
  final IconData? icon;
  final String? label;
  final double size;

  /// A small corner glyph (e.g. the debt direction arrow).
  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Dark themes: a fainter core and a lighter initial, so the
                // letter keeps AA contrast on its own hue (2.6:1 before).
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: t.isDark ? 0.16 : 0.30),
                    color.withValues(alpha: t.isDark ? 0.06 : 0.10),
                  ],
                ),
                border: Border.all(color: color.withValues(alpha: 0.65), width: 1.2),
                boxShadow: [BoxShadow(color: color.withValues(alpha: t.isDark ? 0.28 : 0.16), blurRadius: 10)],
              ),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: size * 0.46, color: t.isDark ? color : Color.lerp(color, t.textPrimary, 0.3))
                  : Text(
                      label ?? '',
                      style: text.titleMedium?.copyWith(
                        color: Color.lerp(color, t.textPrimary, t.isDark ? 0.55 : 0.3),
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
            ),
          ),
          if (badge != null)
            PositionedDirectional(
              bottom: -2,
              end: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.space1,
                  border: Border.all(color: color.withValues(alpha: 0.8)),
                ),
                child: Icon(badge, size: 11, color: t.isDark ? color : Color.lerp(color, t.textPrimary, 0.3)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The first letter of a name (for initials medallions).
String goalsInitial(String name) {
  var trimmed = name.trim();
  if (trimmed.isEmpty) return '·';
  // The Arabic article is not an initial: "المورّد" → "م".
  if (trimmed.length > 3 && (trimmed.startsWith('ال') || trimmed.startsWith('أل'))) trimmed = trimmed.substring(2);
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

/// Shows the undo toast for [action] (when there is one and [context] is
/// still mounted).
Future<void> goalsUndoToast(BuildContext context, UndoableAction? action) async {
  if (action == null || !context.mounted) return;
  await showUndoToast(context, action);
}

/// One quiet action of a detail sheet (icon over a short label).
class GoalsSheetAction {
  const GoalsSheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sfx = Sfx.tap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Sfx sfx;
  final bool danger;
}

/// A row of evenly spaced secondary actions at the foot of a detail sheet.
class GoalsSheetActions extends StatelessWidget {
  const GoalsSheetActions({super.key, required this.actions});

  final List<GoalsSheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusL),
        border: Border.all(color: t.glassBorder.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          for (final a in actions)
            Expanded(
              child: MadarPressable(
                semanticLabel: a.label,
                sfx: a.sfx,
                onTap: a.onTap,
                excludeChildSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.s),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(a.icon, size: 20, color: a.danger ? t.danger : t.gold),
                      const SizedBox(height: 4),
                      Text(
                        a.label,
                        style: text.labelSmall?.copyWith(color: a.danger ? t.danger : t.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
