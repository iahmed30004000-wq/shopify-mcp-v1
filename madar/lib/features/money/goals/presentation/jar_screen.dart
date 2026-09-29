import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/goals_providers.dart';
import '../domain/due_dates.dart';
import '../domain/goals_snapshot.dart';
import '../domain/jar_plan.dart';
import '../goals_texts.dart';
import 'astrolabe_ring.dart';
import 'goals_actions.dart';
import 'goals_tiles.dart';
import 'goals_ui.dart';

/// One savings jar: the astrolabe ring with the plan's alidade, deposit and
/// withdraw, what the deadline asks for, the saving trajectory against the
/// target and the history of movements (deletable with undo).
class JarScreen extends ConsumerWidget {
  const JarScreen({super.key, required this.jarId, this.animateBackdrop = true});

  final String jarId;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final snap = ref.watch(goalsSnapshotProvider);
    final jar = ref.watch(goalsJarProvider(jarId));
    if (jar == null) {
      return MadarScaffold(
        title: l.goalsTabJars,
        animateBackdrop: animateBackdrop,
        body: Center(
          child: snap == null
              ? const OrbitLoader()
              : Text(l.goalsGone, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
        ),
      );
    }
    final actions = GoalsActions(context, ref);

    Future<void> run(Future<UndoableAction?> Function() f, {bool pop = false}) async {
      final action = await f();
      if (!pop) {
        if (context.mounted) await goalsUndoToast(context, action);
        return;
      }
      if (!context.mounted) return;
      // The toast outlives this page: show it from the navigator below.
      final host = Navigator.of(context).context;
      Navigator.of(context).maybePop();
      if (host.mounted) await goalsUndoToast(host, action);
    }

    final archived = jar.jar.archived;
    return MadarScaffold(
      title: jar.jar.name,
      backdropSeed: 6.2,
      animateBackdrop: animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: Icons.edit_outlined,
          semanticLabel: l.actionEdit,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => actions.editJar(jar.jar),
        ),
        MadarButton.icon(
          icon: archived ? GoalsIcons.unarchive : GoalsIcons.archive,
          semanticLabel: archived ? l.goalsUnarchive : l.goalsArchive,
          variant: MadarButtonVariant.ghost,
          onPressed: () => run(() => actions.setArchived(jar, !archived)),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: _staggered([
          _JarHero(jar: jar),
          const SizedBox(height: Space.m),
          if (!archived)
            Row(
              children: [
                Expanded(
                  child: MadarButton(
                    label: l.goalsDeposit,
                    icon: GoalsIcons.deposit,
                    expand: true,
                    sfx: Sfx.sheetOpen,
                    onPressed: () => run(() => actions.moveMoney(jar)),
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: MadarButton(
                    label: l.goalsWithdraw,
                    icon: GoalsIcons.withdraw,
                    variant: MadarButtonVariant.secondary,
                    expand: true,
                    sfx: Sfx.sheetOpen,
                    onPressed: jar.plan.savedMilli > 0 ? () => run(() => actions.moveMoney(jar, withdraw: true)) : null,
                  ),
                ),
              ],
            )
          else
            MadarButton(
              label: l.goalsUnarchive,
              icon: GoalsIcons.unarchive,
              variant: MadarButtonVariant.secondary,
              expand: true,
              onPressed: () => run(() => actions.setArchived(jar, false)),
            ),
          const SizedBox(height: Space.m),
          _JarStats(jar: jar),
          if (jar.movements.length >= 2) ...[
            GoalsSectionTitle(l.goalsTrajectory),
            GlassCard(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.l, Space.m, Space.s),
              borderRadius: BorderRadius.circular(t.radiusL),
              child: JarTrajectoryChart(jar: jar),
            ),
          ],
          GoalsSectionTitle(
            l.goalsHistory,
            count: jar.movements.isEmpty ? null : MadarFormatter.of(context).formatInt(jar.movements.length),
          ),
          if (jar.movements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.l),
              child: Text(
                l.goalsNoMovements,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: t.textTertiary),
              ),
            )
          else
            _JarHistory(jar: jar),
          const SizedBox(height: Space.l),
          Center(
            child: MadarButton(
              label: l.goalsDeleteJar,
              icon: Icons.delete_outline_rounded,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.delete,
              onPressed: () => run(() => actions.deleteJar(jar), pop: true),
            ),
          ),
        ]),
      ),
    );
  }

  static List<Widget> _staggered(List<Widget> children) => [
    for (var i = 0; i < children.length; i++) StaggerItem(index: i, child: children[i]),
  ];
}

class _JarHero extends ConsumerWidget {
  const _JarHero({required this.jar});

  final JarView jar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final plan = jar.plan;
    final color = jarColor(t, jar);
    final currency = jar.jar.currency;
    return GoalsHeaderCard(
      seed: 0.9,
      child: Column(
        children: [
          AstrolabeProgressRing(
            progress: plan.progress,
            expected: plan.expectedProgress,
            size: 232,
            color: color,
            reached: plan.reached,
            semanticLabel: [
              l.goalsSavedOfTarget(texts.money(plan.savedMilli, currency), texts.money(plan.targetMilli, currency)),
              jarPacePhrase(texts, plan, today),
            ].join('. '),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GoalsJarGlyph(icon: jar.jar.icon, color: plan.reached ? t.gold : color),
                const SizedBox(height: 2),
                Text(
                  plan.targetMilli > 0 ? texts.percent(plan.rawProgress) : texts.money(plan.savedMilli, currency),
                  style: text.titleLarge?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      texts.money(plan.savedMilli, currency),
                      style: text.titleSmall?.copyWith(color: plan.reached ? t.gold : t.textSecondary),
                    ),
                  ),
                ),
                if (plan.targetMilli > 0)
                  Text(
                    l.goalsOfTotal(texts.money(plan.targetMilli, currency)),
                    style: text.labelSmall?.copyWith(color: t.textTertiary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.s,
            runSpacing: Space.xs,
            children: [
              GoalsPill(
                label: jarPacePhrase(texts, plan, today),
                color: jarPaceColor(t, plan.pace),
                filled: plan.reached,
                icon: plan.reached ? Icons.emoji_events_rounded : null,
              ),
              if (plan.deadline != null)
                GoalsPill(
                  label: l.goalsDeadlineOn(texts.shortDate(plan.deadline!, today)),
                  color: t.brass,
                  icon: GoalsIcons.deadline,
                ),
            ],
          ),
          if (plan.expectedProgress != null && !plan.reached) ...[
            const SizedBox(height: Space.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.navigation_rounded, size: 12, color: t.metalGold),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    l.goalsAlidadeHint(texts.percent(plan.expectedProgress!)),
                    style: text.labelSmall?.copyWith(color: t.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _JarStats extends ConsumerWidget {
  const _JarStats({required this.jar});

  final JarView jar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final plan = jar.plan;
    final currency = jar.jar.currency;
    final tiles = <Widget>[
      StatTile(
        label: plan.reached ? l.goalsSurplusLabel : l.goalsRemaining,
        value: texts.money(plan.reached ? plan.surplusMilli : plan.remainingMilli, currency),
        icon: plan.reached ? Icons.emoji_events_rounded : Icons.hourglass_bottom_rounded,
        color: plan.reached ? t.gold : null,
      ),
      if (plan.requiredPerMonthMilli != null)
        StatTile(
          label: plan.pace == JarPace.overdue ? l.goalsNeededNow : l.goalsPerMonth,
          value: texts.money(plan.requiredPerMonthMilli!, currency),
          icon: Icons.calendar_month_rounded,
          color: plan.pace == JarPace.overdue ? t.danger : t.gold,
          caption: plan.pace == JarPace.overdue
              ? null
              : l.goalsPerWeekCaption(texts.money(plan.requiredPerWeekMilli ?? 0, currency)),
        ),
      if (plan.deadline != null)
        StatTile(
          label: l.goalsFieldDeadline,
          value: texts.shortDate(plan.deadline!, today),
          icon: GoalsIcons.deadline,
          caption: plan.daysLeft == null
              ? null
              : (plan.daysLeft! >= 0 ? texts.daysLeft(plan.daysLeft!) : texts.dueRelative(plan.deadline!, today)),
        ),
      if (plan.eta != null)
        StatTile(
          label: l.goalsAtYourPace,
          value: texts.shortDate(plan.eta!, today),
          icon: Icons.trending_up_rounded,
          caption: plan.deadline == null
              ? null
              : (plan.eta!.isAfter(plan.deadline!) ? l.goalsAfterDeadline : l.goalsBeforeDeadline),
        ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - Space.s) / 2;
        return Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [for (final tile in tiles) SizedBox(width: w, child: tile)],
        );
      },
    );
  }
}

class _JarHistory extends ConsumerWidget {
  const _JarHistory({required this.jar});

  final JarView jar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    final texts = goalsTexts(context, ref);
    final today = ref.watch(goalsTodayProvider);
    final wallets = ref.watch(goalsSnapshotProvider)?.wallets ?? const {};
    final actions = GoalsActions(context, ref);
    final byMonth = <DateTime, List<JarDepositRow>>{};
    for (final m in jar.movements) {
      (byMonth[DateTime(m.date.year, m.date.month)] ??= []).add(m);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in byMonth.entries) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.s, Space.xs, Space.xs),
            child: Text(
              _monthTitle(texts, entry.key),
              style: text.labelMedium?.copyWith(color: t.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          for (final m in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: _MovementRow(
                move: m,
                currency: jar.jar.currency,
                walletName: m.walletId == null ? null : wallets[m.walletId]?.name,
                dateText: texts.shortDate(m.date, today),
                texts: texts,
                deleteLabel: l.actionDelete,
                onDelete: () => actions.deleteJarMovement(m),
              ),
            ),
        ],
      ],
    );
  }

  static String _monthTitle(GoalsTexts texts, DateTime month) {
    DateFormat f;
    try {
      f = DateFormat.yMMMM(texts.fmt.languageCode);
    } catch (_) {
      f = DateFormat.yMMMM('en');
    }
    return texts.fmt.localizeDigits(f.format(month));
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.move,
    required this.currency,
    required this.walletName,
    required this.dateText,
    required this.texts,
    required this.deleteLabel,
    required this.onDelete,
  });

  final JarDepositRow move;
  final String currency;
  final String? walletName;
  final String dateText;
  final GoalsTexts texts;
  final String deleteLabel;
  final Future<UndoableAction?> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = texts.l;
    final deposit = move.amountMilli >= 0;
    final color = deposit ? t.success : t.warning;
    final amount = texts.money(move.amountMilli, currency, signed: true);
    final sub = [
      if (walletName != null) (deposit ? l.goalsFromWallet(walletName!) : l.goalsToWallet(walletName!)),
      ?move.note,
    ].join(' · ');
    return ActionableItem(
      semanticLabel: '${deposit ? l.goalsDeposit : l.goalsWithdraw}: $amount. $dateText. $sub',
      borderRadius: BorderRadius.circular(t.radiusM),
      swipeEnabled: false,
      actions: ItemActions(onDelete: onDelete),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.14)),
              child: Icon(deposit ? GoalsIcons.deposit : GoalsIcons.withdraw, size: 16, color: color),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amount,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: deposit ? t.textPrimary : (t.isDark ? color : t.textPrimary),
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(
                      sub,
                      style: text.labelSmall?.copyWith(color: t.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(dateText, style: text.labelMedium?.copyWith(color: t.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// The jar's running balance over time, the target as a dashed line and
/// the deadline as a brass marker (time flows with the reading direction).
class JarTrajectoryChart extends ConsumerWidget {
  const JarTrajectoryChart({super.key, required this.jar, this.height = 180});

  final JarView jar;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = goalsTexts(context, ref);
    final fmt = texts.fmt;
    final today = ref.watch(goalsTodayProvider);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final series = JarPlan.series([for (final m in jar.movements) JarMovement(m.amountMilli, m.date)]);
    if (series.length < 2) return const SizedBox.shrink();
    final color = jarColor(t, jar);
    final from = series.first.$1;
    final deadline = jar.plan.deadline;
    final end = [today, series.last.$1, ?deadline].reduce((a, b) => a.isAfter(b) ? a : b);
    final span = math.max(1, CalendarDays.between(from, end)).toDouble();
    double xOf(DateTime d) {
      final x = CalendarDays.between(from, d).toDouble();
      return rtl ? span - x : x;
    }

    DateTime dayOf(double x) => CalendarDays.addDays(from, (rtl ? span - x : x).round());
    final units = jar.plan.targetMilli / 1000;
    final peak = series.fold<double>(0, (m, p) => math.max(m, p.$2 / 1000));
    final maxY = _niceCeil(math.max(units, peak) * 1.08);
    final spots = [
      for (final p in series) FlSpot(xOf(p.$1), math.max(0, p.$2) / 1000),
      // Carry the last balance to today.
      if (today.isAfter(series.last.$1)) FlSpot(xOf(today), math.max(0, series.last.$2) / 1000),
    ]..sort((a, b) => a.x.compareTo(b.x));
    final labelStyle = (text.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: t.textTertiary);
    final dateFormat = _format(fmt.languageCode);
    final axisFormat = _axisFormat(fmt.languageCode);
    // The plan from today to the deadline, dashed in gold.
    final saved = math.max(0, series.last.$2) / 1000;
    final plan = deadline != null && deadline.isAfter(today) && units > saved && !jar.plan.reached
        ? LineChartBarData(
            spots: [FlSpot(xOf(today), saved), FlSpot(xOf(deadline), units)]..sort((a, b) => a.x.compareTo(b.x)),
            color: t.metalGold.withValues(alpha: 0.85),
            barWidth: 1.6,
            dashArray: const [4, 4],
            dotData: FlDotData(
              getDotPainter: (spot, _, _, _) =>
                  FlDotCirclePainter(radius: 2.6, color: t.metalGold, strokeWidth: 0, strokeColor: t.metalGold),
            ),
          )
        : null;
    final valueTitles = AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        interval: maxY / 2,
        getTitlesWidget: (value, meta) => SideTitleWidget(
          meta: meta,
          space: 6,
          child: Text(fmt.formatNumber(value, maxDecimals: 0), style: labelStyle),
        ),
      ),
    );
    return Semantics(
      label: texts.l.goalsTrajectory,
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: span,
            minY: 0,
            maxY: maxY,
            clipData: const FlClipData.none(),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isStepLineChart: true,
                // A balance holds until the next movement, whichever way
                // time runs on screen.
                lineChartStepData: LineChartStepData(
                  stepDirection: rtl ? LineChartStepData.stepDirectionBackward : LineChartStepData.stepDirectionForward,
                ),
                color: color,
                barWidth: 2.4,
                isStrokeCapRound: true,
                shadow: Shadow(color: color.withValues(alpha: 0.45), blurRadius: 8),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: t.isDark ? 0.28 : 0.16),
                      color.withValues(alpha: 0),
                    ],
                  ),
                ),
                dotData: FlDotData(
                  show: spots.length <= 24,
                  checkToShowDot: (spot, bar) => !today.isAfter(series.last.$1) || spot.x != xOf(today),
                  getDotPainter: (spot, _, _, _) =>
                      FlDotCirclePainter(radius: 3, color: color, strokeWidth: 1.4, strokeColor: t.space1),
                ),
              ),
              ?plan,
            ],
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (units > 0)
                  HorizontalLine(
                    y: units,
                    color: t.metalGold.withValues(alpha: 0.8),
                    strokeWidth: 1.2,
                    dashArray: const [6, 4],
                  ),
              ],
              verticalLines: [
                if (deadline != null)
                  VerticalLine(
                    x: xOf(deadline),
                    color: t.brass.withValues(alpha: 0.7),
                    strokeWidth: 1,
                    dashArray: const [3, 3],
                  ),
              ],
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: maxY / 2,
              getDrawingHorizontalLine: (_) => FlLine(color: t.glassBorder.withValues(alpha: 0.4), strokeWidth: 0.8),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              leftTitles: rtl ? const AxisTitles() : valueTitles,
              rightTitles: rtl ? valueTitles : const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: span / 2,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    space: 6,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                    child: Text(fmt.localizeDigits(axisFormat.format(dayOf(value))), style: labelStyle),
                  ),
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => t.space2.withValues(alpha: 0.95),
                tooltipBorder: BorderSide(color: t.glassBorder),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    if (s.barIndex != 0)
                      null
                    else
                      LineTooltipItem(
                        '${fmt.localizeDigits(dateFormat.format(dayOf(s.x)))}\n',
                        labelStyle,
                        children: [
                          TextSpan(
                            text: texts.money((s.y * 1000).round(), jar.jar.currency),
                            style: (text.titleSmall ?? const TextStyle()).copyWith(color: color),
                          ),
                        ],
                      ),
                ],
              ),
              touchCallback: (event, response) {
                if (event is FlTapUpEvent && response?.lineBarSpots?.isNotEmpty == true) {
                  Fx.fire(Sfx.countTick, volume: 0.5);
                }
              },
            ),
          ),
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
        ),
      ),
    );
  }

  static DateFormat _axisFormat(String language) {
    try {
      return DateFormat.yMMM(language);
    } catch (_) {
      return DateFormat.yMMM('en');
    }
  }

  static DateFormat _format(String language) {
    try {
      return DateFormat.MMMd(language);
    } catch (_) {
      return DateFormat.MMMd('en');
    }
  }

  /// A round axis maximum (1, 2, 2.5, 5 × 10ⁿ).
  static double _niceCeil(double v) {
    if (v <= 0) return 1;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * exp >= v) return m * exp;
    }
    return 10 * exp;
  }
}
