import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/record_providers.dart';
import '../domain/appointment_plan.dart';
import 'doctor_report_sheet.dart';
import 'record_actions.dart';
import 'record_navigation.dart';
import 'record_ui.dart';
import 'widgets/health_alerts_banner.dart';
import 'widgets/record_tiles.dart';

enum RecordTab { labs, appointments, questions, conditions }

/// The medical record: standing alerts on top, then labs, appointments,
/// questions for the doctor and conditions; the doctor report and the
/// record's settings in the app bar.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key, this.initialTab = RecordTab.labs, this.animateBackdrop = true});

  final RecordTab initialTab;
  final bool animateBackdrop;

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  late RecordTab _tab = widget.initialTab;
  bool _reorderLabs = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final actions = RecordActions(context, ref);
    final (fabIcon, fabLabel, fabAction) = switch (_tab) {
      RecordTab.labs => (RecordIcons.visit, l.recordLabVisit, actions.labVisit),
      RecordTab.appointments => (Icons.add_rounded, l.recordAppointmentAdd, actions.addAppointment),
      RecordTab.questions => (Icons.add_comment_outlined, l.recordQuestionAdd, () => actions.addQuestion()),
      RecordTab.conditions => (Icons.add_rounded, l.recordConditionAdd, actions.addCondition),
    };
    return MadarScaffold(
      title: l.recordTitle,
      backdropSeed: 4.4,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: RecordIcons.report,
          onPressed: () => showDoctorReportSheet(context),
          semanticLabel: l.recordDoctorReport,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
        ),
        MadarButton.icon(
          icon: RecordIcons.settings,
          onPressed: actions.openSettings,
          semanticLabel: l.recordSettingsTitle,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
        ),
      ],
      floatingAction: MadarButton.icon(
        icon: fabIcon,
        onPressed: fabAction,
        semanticLabel: fabLabel,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
      ),
      body: EntranceChoreo(
        id: 'record',
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 110),
          children: [
            const StaggerItem(
              index: 0,
              child: HealthAlertsBanner(
                showHeader: true,
                showEmptyHint: true,
                dense: true,
                padding: EdgeInsets.only(bottom: Space.m),
              ),
            ),
            StaggerItem(
              index: 1,
              child: RecordTabs(
                value: _tab,
                onChanged: (t) => setState(() {
                  _tab = t;
                  _reorderLabs = false;
                }),
              ),
            ),
            const SizedBox(height: Space.l),
            StaggerItem(
              index: 2,
              child: AnimatedSwitcher(
                duration: context.motion(MadarMotion.medium),
                switchInCurve: MadarMotion.decelerate,
                switchOutCurve: MadarMotion.accelerate,
                layoutBuilder: (current, previous) =>
                    Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: switch (_tab) {
                    RecordTab.labs => LabsView(
                      reorder: _reorderLabs,
                      onToggleReorder: () => setState(() => _reorderLabs = !_reorderLabs),
                    ),
                    RecordTab.appointments => const AppointmentsView(),
                    RecordTab.questions => const QuestionsView(),
                    RecordTab.conditions => const ConditionsView(),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The record's four tabs (a sliding lit pill follows the choice).
class RecordTabs extends StatelessWidget {
  const RecordTabs({super.key, required this.value, required this.onChanged});

  final RecordTab value;
  final ValueChanged<RecordTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    const values = RecordTab.values;
    final labels = {
      RecordTab.labs: (l.recordTabLabs, RecordIcons.labs),
      RecordTab.appointments: (l.recordTabAppointments, RecordIcons.appointments),
      RecordTab.questions: (l.recordTabQuestions, RecordIcons.questions),
      RecordTab.conditions: (l.recordTabConditions, RecordIcons.conditions),
    };
    final index = values.indexOf(value);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: 60,
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
                  builder: (context, v, _) => Positioned(
                    left: rtl ? constraints.maxWidth - w * (v + 1) : w * v,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: DecoratedBox(
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
                  ),
                ),
                Row(
                  children: [
                    for (final v in values)
                      Expanded(
                        child: MadarPressable(
                          onTap: v == value ? null : () => onChanged(v),
                          sfx: Sfx.navigate,
                          selected: v == value,
                          semanticLabel: labels[v]!.$1,
                          excludeChildSemantics: true,
                          focusRadius: BorderRadius.circular(t.radiusL - 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(labels[v]!.$2, size: 18, color: v == value ? t.textOnAccent : t.textTertiary),
                              const SizedBox(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: AnimatedDefaultTextStyle(
                                    duration: context.motion(MadarMotion.short),
                                    style: text.labelMedium!.copyWith(
                                      color: v == value ? t.textOnAccent : t.textSecondary,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                    child: Text(labels[v]!.$1, maxLines: 1),
                                  ),
                                ),
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

Widget _header(BuildContext context, String title, {String? subtitle, String? action, VoidCallback? onAction}) =>
    RecordGroupHeader(title: title, subtitle: subtitle, actionLabel: action, onAction: onAction);

Widget _empty(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required VoidCallback onAction,
  IconData icon = Icons.add_rounded,
}) => Padding(
  padding: const EdgeInsets.only(top: Space.l),
  child: AnimatedEmptyState(
    kind: EmptyStateKind.emptyList,
    title: title,
    body: body,
    actionLabel: action,
    actionIcon: icon,
    onAction: onAction,
    illustrationSize: 120,
  ),
);

// ------------------------------------------------------------------ labs --

/// Lab tests grouped by category, each with its sparkline and latest flag.
class LabsView extends ConsumerWidget {
  const LabsView({super.key, this.reorder = false, this.onToggleReorder});

  final bool reorder;
  final VoidCallback? onToggleReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final views = ref.watch(labTestViewsProvider);
    final actions = RecordActions(context, ref);
    final nav = ref.watch(recordNavigationProvider);
    final list = views.value;
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.all(Space.xl),
        child: Center(child: OrbitLoader(size: 36)),
      );
    }
    if (list.isEmpty) {
      return _empty(
        context,
        title: l.recordLabsEmpty,
        body: l.recordLabsEmptyBody,
        action: l.recordLabAddTest,
        onAction: actions.addTest,
      );
    }
    final groups = <String?, List<LabTestView>>{};
    for (final v in list) {
      final c = v.test.category?.trim();
      (groups[c == null || c.isEmpty ? null : c] ??= []).add(v);
    }
    final keys = [...groups.keys.whereType<String>(), if (groups.containsKey(null)) null];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: MadarButton(
                label: l.recordLabVisit,
                icon: RecordIcons.visit,
                onPressed: actions.labVisit,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: MadarButton(
                label: l.recordLabAddTest,
                icon: Icons.add_rounded,
                onPressed: actions.addTest,
                variant: MadarButtonVariant.secondary,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
              ),
            ),
            const SizedBox(width: Space.s),
            MadarButton.icon(
              icon: reorder ? Icons.check_rounded : Icons.swap_vert_rounded,
              onPressed: onToggleReorder,
              semanticLabel: reorder ? l.recordReorderDone : l.recordReorder,
              variant: reorder ? MadarButtonVariant.primary : MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: reorder ? Sfx.drop : Sfx.pickUp,
            ),
          ],
        ),
        for (final k in keys) ...[
          // Uncategorised tests alone need no group name ("Other" only
          // reads next to named categories; "Labs" would repeat the tab):
          // the count heads them.
          if (k == null && keys.length == 1)
            _header(context, l.recordLabTestsCount(groups[k]!.length, fmt.formatInt(groups[k]!.length)))
          else
            _header(
              context,
              k ?? l.recordLabUncategorized,
              subtitle: l.recordLabTestsCount(groups[k]!.length, fmt.formatInt(groups[k]!.length)),
            ),
          if (reorder)
            ReorderableGlassList<LabTestView>(
              items: groups[k]!,
              itemKey: (v) => v.test.id,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              animateEntrance: false,
              onReorder: (order) => actions.reorderTests([for (final v in order) v.test.id]),
              itemBuilder: (context, v, index, grip) => LabTestTile(view: v, grip: grip),
            )
          else
            for (final v in groups[k]!)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: AnimatedReveal(
                  key: ValueKey(v.test.id),
                  child: ActionableItem(
                    onTap: () => nav.openLabTest(context, v.test.id),
                    semanticLabel: v.test.name,
                    actions: ItemActions(
                      onEdit: () => actions.editTest(v.test),
                      onDelete: () => actions.deleteTest(v.test),
                      extra: [
                        ItemAction(
                          icon: Icons.add_chart_rounded,
                          label: l.recordLabAddReading,
                          tone: ActionTone.accent,
                          onSelected: () async {
                            await actions.addReading(v);
                            return null;
                          },
                        ),
                      ],
                    ),
                    onCompleteSwipe: null,
                    quickActions: [
                      QuickAction(
                        icon: Icons.add_chart_rounded,
                        label: l.recordLabAddReading,
                        onPressed: () async {
                          await actions.addReading(v);
                          return null;
                        },
                      ),
                      QuickAction(
                        icon: Icons.delete_outline_rounded,
                        label: l.recordDelete,
                        onPressed: () => actions.deleteTest(v.test),
                        tone: ActionTone.danger,
                      ),
                    ],
                    child: LabTestTile(view: v),
                  ),
                ),
              ),
        ],
        const SizedBox(height: Space.s),
        Text(
          l.recordLabMarginNote(context.recordTexts.margin(ref.watch(recordSettingsValueProvider).borderlineMargin)),
          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.tokens.textTertiary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------- appointments --

/// Upcoming appointments (the next one lit, with its questions) and the
/// latest past ones.
class AppointmentsView extends ConsumerWidget {
  const AppointmentsView({super.key, this.pastLimit = 3, this.showAll = false, this.highlightId});

  final int pastLimit;

  /// Every past appointment (the Appointments screen).
  final bool showAll;
  final String? highlightId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final buckets = ref.watch(appointmentBucketsProvider).value;
    final questions = ref.watch(doctorQuestionsProvider).value ?? const <DoctorQuestionRow>[];
    final actions = RecordActions(context, ref);
    final nav = ref.watch(recordNavigationProvider);
    final now = ref.watch(recordClockProvider)();
    if (buckets == null) {
      return const Padding(
        padding: EdgeInsets.all(Space.xl),
        child: Center(child: OrbitLoader(size: 36)),
      );
    }
    final openFor = <String, List<DoctorQuestionRow>>{};
    for (final q in questions) {
      if (!q.answered && q.appointmentId != null) (openFor[q.appointmentId!] ??= []).add(q);
    }
    final past = showAll ? buckets.past : buckets.past.take(pastLimit).toList();

    Widget tile(AppointmentRow a, {bool highlight = false}) {
      final qs = openFor[a.id] ?? const <DoctorQuestionRow>[];
      final upcoming = AppointmentTimeline.isUpcoming(a, now);
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.s),
        child: AnimatedReveal(
          key: ValueKey(a.id),
          child: ActionableItem(
            onTap: () => actions.editAppointment(a),
            semanticLabel: a.title,
            onCompleteSwipe: () => actions.toggleAppointmentDone(a),
            completeLabel: a.done ? l.recordAppointmentMarkUndone : l.recordAppointmentMarkDone,
            completeIcon: a.done ? Icons.undo_rounded : Icons.check_rounded,
            actions: ItemActions(
              onEdit: () => actions.editAppointment(a),
              onDelete: () => actions.deleteAppointment(a),
              extra: [
                if (upcoming)
                  ItemAction(
                    icon: Icons.add_comment_outlined,
                    label: l.recordQuestionAdd,
                    tone: ActionTone.accent,
                    onSelected: () async {
                      await actions.addQuestion(appointmentId: a.id);
                      return null;
                    },
                  ),
                ItemAction(
                  icon: a.done ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                  label: a.done ? l.recordAppointmentMarkUndone : l.recordAppointmentMarkDone,
                  tone: ActionTone.success,
                  onSelected: () => actions.toggleAppointmentDone(a),
                ),
              ],
            ),
            quickActions: [
              if (upcoming)
                QuickAction(
                  icon: Icons.add_comment_outlined,
                  label: l.recordQuestionAdd,
                  onPressed: () async {
                    await actions.addQuestion(appointmentId: a.id);
                    return null;
                  },
                ),
              QuickAction(
                icon: Icons.delete_outline_rounded,
                label: l.recordDelete,
                onPressed: () => actions.deleteAppointment(a),
                tone: ActionTone.danger,
              ),
            ],
            child: AppointmentTile(
              appointment: a,
              now: now,
              highlight: highlight || a.id == highlightId,
              openQuestions: highlight ? 0 : qs.length,
              footer: highlight
                  ? _InlineQuestions(
                      questions: qs,
                      onAdd: () => actions.addQuestion(appointmentId: a.id),
                    )
                  : null,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (buckets.upcoming.isEmpty)
          _empty(
            context,
            title: l.recordAppointmentsEmpty,
            body: l.recordAppointmentsEmptyBody,
            action: l.recordAppointmentAdd,
            onAction: actions.addAppointment,
          )
        else ...[
          _header(context, l.recordAppointmentUpcoming),
          for (var i = 0; i < buckets.upcoming.length; i++) tile(buckets.upcoming[i], highlight: i == 0),
        ],
        if (past.isNotEmpty) ...[
          _header(
            context,
            l.recordAppointmentPast,
            action: !showAll && buckets.past.length > past.length ? l.recordAppointmentShowAll : null,
            onAction: () => nav.openAppointments(context),
          ),
          for (final a in past) tile(a),
        ],
      ],
    );
  }
}

class _InlineQuestions extends StatelessWidget {
  const _InlineQuestions({required this.questions, required this.onAdd});

  final List<DoctorQuestionRow> questions;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadarDivider(ornament: false, height: 10, color: t.glassBorder),
          for (final q in questions.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(Icons.help_outline_rounded, size: 16, color: t.info),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(q.question, style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          if (questions.length > 4)
            Text(
              l.recordQuestionsMore(questions.length - 4, MadarFormatter.of(context).formatInt(questions.length - 4)),
              style: text.labelSmall!.copyWith(color: t.textTertiary),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              label: questions.isEmpty ? l.recordQuestionAddForVisit : l.recordQuestionAdd,
              icon: Icons.add_comment_outlined,
              onPressed: onAdd,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- questions --

/// Open questions grouped by appointment (then general ones), reorderable;
/// answered ones with their answers below.
class QuestionsView extends ConsumerWidget {
  const QuestionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final questions = ref.watch(doctorQuestionsProvider).value;
    final buckets = ref.watch(appointmentBucketsProvider).value;
    final all = ref.watch(appointmentsProvider).value ?? const <AppointmentRow>[];
    final actions = RecordActions(context, ref);
    if (questions == null || buckets == null) {
      return const Padding(
        padding: EdgeInsets.all(Space.xl),
        child: Center(child: OrbitLoader(size: 36)),
      );
    }
    if (questions.isEmpty) {
      return _empty(
        context,
        title: l.recordQuestionsEmpty,
        body: l.recordQuestionsEmptyBody,
        action: l.recordQuestionAdd,
        onAction: () => actions.addQuestion(),
        icon: Icons.add_comment_outlined,
      );
    }
    final byId = {for (final a in all) a.id: a};
    final upcomingIds = [for (final a in buckets.upcoming) a.id];
    final open = [
      for (final q in questions)
        if (!q.answered) q,
    ];
    final answered = [
      for (final q in questions)
        if (q.answered) q,
    ];
    final groups = <String?, List<DoctorQuestionRow>>{};
    for (final q in open) {
      final key = upcomingIds.contains(q.appointmentId) ? q.appointmentId : null;
      (groups[key] ??= []).add(q);
    }
    String? pastLabel(DoctorQuestionRow q) {
      final a = byId[q.appointmentId];
      if (a == null || upcomingIds.contains(a.id)) return null;
      return l.recordReportQuestionFor(
        BidiIsolate.isolate(a.title),
        fmt.formatDate(a.at, style: MadarDateStyle.dayMonth),
      );
    }

    Widget list(List<DoctorQuestionRow> items, {bool reorderable = true}) => ReorderableGlassList<DoctorQuestionRow>(
      items: items,
      itemKey: (q) => q.id,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      animateEntrance: false,
      onReorder: actions.reorderQuestions,
      itemBuilder: (context, q, index, grip) => ActionableItem(
        onTap: () => actions.editQuestion(q),
        semanticLabel: q.question,
        onCompleteSwipe: () => actions.markAnswered(q),
        completeLabel: q.answered ? l.recordQuestionReopen : l.recordQuestionMarkAnswered,
        completeIcon: q.answered ? Icons.undo_rounded : Icons.check_rounded,
        actions: ItemActions(onEdit: () => actions.editQuestion(q), onDelete: () => actions.deleteQuestion(q)),
        quickActions: [
          QuickAction(
            icon: Icons.delete_outline_rounded,
            label: l.recordDelete,
            onPressed: () => actions.deleteQuestion(q),
            tone: ActionTone.danger,
          ),
        ],
        child: QuestionTile(
          question: q,
          grip: reorderable ? grip : null,
          appointmentLabel: pastLabel(q),
          onToggle: () async {
            final undo = await actions.markAnswered(q);
            if (undo != null && context.mounted) await showUndoToast(context, undo);
          },
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final id in upcomingIds)
          if (groups[id] case final qs?) ...[
            _header(
              context,
              byId[id]!.title,
              subtitle: fmt.formatDate(byId[id]!.at, style: MadarDateStyle.weekdayDayMonth),
              action: l.recordAdd,
              onAction: () => actions.addQuestion(appointmentId: id),
            ),
            list(qs),
          ],
        if (groups[null] case final qs?) ...[
          _header(context, l.recordQuestionsGeneralHeader, action: l.recordAdd, onAction: () => actions.addQuestion()),
          list(qs),
        ],
        if (answered.isNotEmpty) ...[
          _header(context, l.recordQuestionsAnsweredHeader, subtitle: fmt.formatInt(answered.length)),
          list(answered, reorderable: false),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------ conditions --

/// Active conditions (reorderable), then inactive ones.
class ConditionsView extends ConsumerWidget {
  const ConditionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final conditions = ref.watch(conditionsProvider).value;
    final actions = RecordActions(context, ref);
    if (conditions == null) {
      return const Padding(
        padding: EdgeInsets.all(Space.xl),
        child: Center(child: OrbitLoader(size: 36)),
      );
    }
    if (conditions.isEmpty) {
      return _empty(
        context,
        title: l.recordConditionsEmpty,
        body: l.recordConditionsEmptyBody,
        action: l.recordConditionAdd,
        onAction: actions.addCondition,
      );
    }
    final active = [
      for (final c in conditions)
        if (c.active) c,
    ];
    final inactive = [
      for (final c in conditions)
        if (!c.active) c,
    ];

    Widget item(ConditionRow c, Widget? grip) => ActionableItem(
      onTap: () => actions.editCondition(c),
      semanticLabel: c.name,
      actions: ItemActions(
        onEdit: () => actions.editCondition(c),
        onDelete: () => actions.deleteCondition(c),
        extra: [
          ItemAction(
            icon: c.active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
            label: c.active ? l.recordConditionMarkInactive : l.recordConditionMarkActive,
            onSelected: () => actions.toggleConditionActive(c),
            tone: ActionTone.warning,
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: c.active ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
          label: c.active ? l.recordConditionMarkInactive : l.recordConditionMarkActive,
          onPressed: () => actions.toggleConditionActive(c),
          tone: ActionTone.warning,
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.recordDelete,
          onPressed: () => actions.deleteCondition(c),
          tone: ActionTone.danger,
        ),
      ],
      child: ConditionTile(condition: c, grip: grip),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (active.isNotEmpty)
          ReorderableGlassList<ConditionRow>(
            items: active,
            itemKey: (c) => c.id,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            animateEntrance: false,
            onReorder: actions.reorderConditions,
            itemBuilder: (context, c, index, grip) => item(c, grip),
          ),
        if (inactive.isNotEmpty) ...[
          _header(context, l.recordConditionsInactiveHeader),
          for (final c in inactive)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: AnimatedReveal(key: ValueKey(c.id), child: item(c, null)),
            ),
        ],
      ],
    );
  }
}
