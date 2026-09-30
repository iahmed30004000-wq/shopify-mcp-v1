import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/record_providers.dart';
import '../record_actions.dart';
import '../record_ui.dart';

/// Standing alerts pinned at the top of Health ("No cortisone"): one card
/// per pinned alert, styled by importance (critical / caution / note).
///
/// With [editable] (default) a tap edits, long-press opens the menu (edit,
/// unpin, manage all, delete) and swiping towards the end reveals unpin /
/// delete – all with undo. Reuse it at the top of every Health screen and on
/// the Health hub ([maxVisible] keeps it compact there).
class HealthAlertsBanner extends ConsumerWidget {
  const HealthAlertsBanner({
    super.key,
    this.editable = true,
    this.showHeader = false,
    this.showEmptyHint = false,
    this.maxVisible,
    this.dense = false,
    this.padding = EdgeInsets.zero,
  });

  /// Tighter cards (inside screens with more to show).
  final bool dense;

  final bool editable;

  /// A "Standing alerts" section header with a Manage action.
  final bool showHeader;

  /// Without pinned alerts: a quiet "add a standing alert" card (else the
  /// banner takes no space).
  final bool showEmptyHint;

  /// Show at most this many; a "+N more" pill opens the manager.
  final int? maxVisible;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final alerts = ref.watch(pinnedHealthAlertsProvider).value ?? const <HealthAlertRow>[];
    final actions = RecordActions(context, ref);
    if (alerts.isEmpty) {
      if (!showEmptyHint || !editable) return const SizedBox.shrink();
      return Padding(
        padding: padding,
        child: _EmptyHint(onTap: actions.addAlert),
      );
    }
    final limit = maxVisible;
    final visible = limit == null || alerts.length <= limit ? alerts : alerts.take(limit).toList();
    final hidden = alerts.length - visible.length;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader)
            SectionHeader(
              title: l.recordSectionAlerts,
              actionLabel: editable ? l.recordAlertsManage : null,
              onAction: editable ? () => showHealthAlertsManager(context) : null,
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
            ),
          for (final a in visible)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: AnimatedReveal(
                key: ValueKey(a.id),
                child: editable
                    ? ActionableItem(
                        onTap: () => actions.editAlert(a),
                        semanticLabel: '${context.recordTexts.severity(a.severity)}: ${a.body}',
                        actions: ItemActions(
                          onEdit: () => actions.editAlert(a),
                          onDelete: () => actions.deleteAlert(a),
                          extra: [
                            ItemAction(
                              icon: Icons.push_pin_outlined,
                              label: l.recordAlertUnpin,
                              onSelected: () => actions.togglePin(a),
                            ),
                            ItemAction(
                              icon: Icons.low_priority_rounded,
                              label: l.recordAlertsManage,
                              onSelected: () async {
                                await showHealthAlertsManager(context);
                                return null;
                              },
                            ),
                          ],
                        ),
                        quickActions: [
                          QuickAction(
                            icon: Icons.push_pin_outlined,
                            label: l.recordAlertUnpin,
                            onPressed: () => actions.togglePin(a),
                            tone: ActionTone.warning,
                          ),
                          QuickAction(
                            icon: Icons.delete_outline_rounded,
                            label: l.recordDelete,
                            onPressed: () => actions.deleteAlert(a),
                            tone: ActionTone.danger,
                          ),
                        ],
                        child: HealthAlertCard(alert: a, dense: dense),
                      )
                    : HealthAlertCard(alert: a, dense: dense),
              ),
            ),
          if (hidden > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MadarChip(
                label: l.recordAlertsMore(hidden, MadarFormatter.of(context).formatInt(hidden)),
                icon: Icons.expand_more_rounded,
                dense: true,
                onSelected: (_) => showHealthAlertsManager(context),
              ),
            ),
        ],
      ),
    );
  }
}

/// One standing alert: an importance stripe on the start side, icon, label
/// and the alert itself.
class HealthAlertCard extends StatelessWidget {
  const HealthAlertCard({super.key, required this.alert, this.dense = false});

  final HealthAlertRow alert;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = RecordColors.severity(t, alert.severity);
    final critical = alert.severity == Severity.critical;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            Color.alphaBlend(color.withValues(alpha: t.isDark ? 0.22 : 0.14), t.glassFill),
            Color.alphaBlend(color.withValues(alpha: t.isDark ? 0.08 : 0.05), t.glassFill),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: critical ? 0.55 : 0.35),
          width: critical ? 1.1 : 0.9,
        ),
        boxShadow: critical && t.isDark ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 18)] : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusM),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    Space.m,
                    dense ? Space.s : Space.m,
                    Space.m,
                    dense ? Space.s : Space.m,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: dense ? 30 : 36,
                        height: dense ? 30 : 36,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
                        child: Icon(RecordIcons.severity(alert.severity), size: dense ? 17 : 20, color: color),
                      ),
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.recordTexts.severity(alert.severity),
                              style: text.labelSmall!.copyWith(
                                color: RecordColors.onWash(t, color, t.isDark ? 0.22 : 0.14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              alert.body,
                              style: (dense ? text.titleSmall! : text.titleMedium!).copyWith(color: t.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.sheetOpen,
      semanticLabel: l.recordAlertAdd,
      child: CustomPaint(
        painter: _DashedBorder(color: t.glassBorder, radius: t.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(Space.m),
          child: Row(
            children: [
              Icon(Icons.add_alert_outlined, color: t.accent, size: 22),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.recordAlertAdd, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                    const SizedBox(height: 2),
                    Text(l.recordAlertsEmptyHint, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}

/// All standing alerts – pinned and not – to reorder (drag), pin / unpin,
/// edit, delete and add.
Future<void> showHealthAlertsManager(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const _AlertsManager());

class _AlertsManager extends ConsumerWidget {
  const _AlertsManager();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final all = ref.watch(healthAlertsProvider).value ?? const <HealthAlertRow>[];
    final actions = RecordActions(context, ref);
    return InteractionSheetFrame(
      title: l.recordSectionAlerts,
      subtitle: l.recordAlertsManagerSubtitle,
      icon: RecordIcons.alert,
      body: all.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xl),
              child: Text(
                l.recordAlertsEmptyHint,
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: t.textTertiary),
              ),
            )
          : ReorderableGlassList<HealthAlertRow>(
              items: all,
              itemKey: (a) => a.id,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              animateEntrance: false,
              onReorder: actions.reorderAlerts,
              itemBuilder: (context, a, index, grip) => ActionableItem(
                onTap: () => actions.editAlert(a),
                swipeEnabled: false,
                actions: ItemActions(onEdit: () => actions.editAlert(a), onDelete: () => actions.deleteAlert(a)),
                child: GlassCard(
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.s, Space.m, Space.s),
                  child: Row(
                    children: [
                      grip,
                      Icon(RecordIcons.severity(a.severity), size: 20, color: RecordColors.severity(t, a.severity)),
                      const SizedBox(width: Space.s),
                      Expanded(
                        child: Text(
                          a.body,
                          style: text.bodyLarge!.copyWith(color: a.pinned ? t.textPrimary : t.textTertiary),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      MadarSwitch(
                        value: a.pinned,
                        semanticLabel: l.recordAlertPinned,
                        onChanged: (_) async {
                          final undo = await actions.togglePin(a);
                          if (undo != null && context.mounted) await showUndoToast(context, undo);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
      footer: SheetButton(
        label: l.recordAlertAdd,
        icon: Icons.add_rounded,
        primary: true,
        sfx: Sfx.sheetOpen,
        onPressed: actions.addAlert,
      ),
    );
  }
}
