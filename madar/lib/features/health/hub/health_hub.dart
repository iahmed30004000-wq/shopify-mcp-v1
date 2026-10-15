import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/routing/health_route_pages.dart';
import '../../../core/sound/sound_api.dart';
import '../meds/meds.dart' show MedsTab, TodayDosesCard;
import '../record/record.dart'
    show
        HealthAlertsBanner,
        LabFlagsCard,
        NextAppointmentCard,
        RecordActions,
        RecordIcons,
        RecordTab,
        appointmentsProvider,
        doctorQuestionsProvider,
        labTestViewsProvider,
        pinnedHealthAlertsProvider,
        showDoctorReportSheet;
import '../wellbeing/presentation/widgets/wb_palette.dart' show WbPalette;
import '../wellbeing/wellbeing.dart'
    show
        PainDraft,
        WellbeingTodayCard,
        showPainLogSheet,
        todayPainProvider,
        wellbeingClockProvider,
        wellbeingServiceProvider;
import 'health_hub_logic.dart';

/// The Health world's own page content – the hub of the body's care, in
/// three movements under the standing alerts:
///
/// * **pinned at the top** – the standing alerts ("No cortisone – AVN"),
///   styled by importance and editable in place ([HealthAlertsBanner]; no
///   space at all when there are none);
/// * **today's care** – the day's doses with a one-tap Taken
///   ([TodayDosesCard]), wellbeing today: the check-in, habits, parked
///   worries, breathing and, when low moods repeat, the gentle support
///   banner with the emergency number ([WellbeingTodayCard]), and the pain
///   right now – one tap on the calm 0–10 scale logs it, with undo
///   ([HealthPainCard]);
/// * **with your doctor** – the next appointment and its questions
///   ([NextAppointmentCard]), the open questions ([HealthQuestionsCard],
///   once there are some) and the latest lab results outside or near the
///   user's own ranges ([LabFlagsCard], once there are readings); the
///   header's "Record" opens the whole medical record;
/// * **tools** – medications, labs, appointments, wellbeing, breathing and
///   the doctor summary (PDF) ([HealthTools]).
///
/// Tracking only: every card records and shows the user's own data – no
/// interpretation, no advice. Every part is a [StaggerItem] of the planet
/// page's entrance, and every screen opens as a route ([HealthNav]).
class HealthHub extends ConsumerWidget {
  const HealthHub({super.key, this.firstIndex = 1});

  /// Stagger index of the first card.
  final int firstIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final alerts = ref.watch(pinnedHealthAlertsProvider).value ?? const [];
    final questions = HealthHubLogic.openQuestions(ref.watch(doctorQuestionsProvider).value ?? const []);
    final labs = HealthHubLogic.hasReadings(ref.watch(labTestViewsProvider).value ?? const []);

    var index = firstIndex;
    final children = <Widget>[];
    void card(Widget child, {bool gap = true}) {
      if (gap && children.isNotEmpty && children.last is! _Header) {
        children.add(const SizedBox(height: Space.m));
      }
      children.add(
        StaggerItem(
          index: index++,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
            child: child,
          ),
        ),
      );
    }

    void header(String title, {String? action, VoidCallback? onAction}) =>
        children.add(_Header(index: index, title: title, action: action, onAction: onAction));

    // The standing alerts ride above everything, like a pinned note.
    if (alerts.isNotEmpty) card(const HealthAlertsBanner());

    header(l.healthHubTodayTitle);
    card(TodayDosesCard(onOpen: (context) => HealthNav.meds(context)));
    card(
      WellbeingTodayCard(
        onOpen: (tab) => HealthNav.wellbeing(context, tab: tab),
        onBreathe: () => HealthNav.breathing(context),
      ),
    );
    card(const HealthPainCard());

    header(l.healthHubDoctorTitle, action: l.healthHubRecordAction, onAction: () => HealthNav.record(context));
    card(const NextAppointmentCard());
    if (questions.isNotEmpty) card(const HealthQuestionsCard());
    if (labs) card(LabFlagsCard(onOpen: () => HealthNav.record(context)));

    header(l.healthHubToolsTitle);
    card(const HealthTools());

    // The planet sheet has no Material above it: the cards the packages
    // bring would otherwise inherit the debug fallback text style.
    return Material(
      type: MaterialType.transparency,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// A movement's title, rising with its first card.
class _Header extends StatelessWidget {
  const _Header({required this.index, required this.title, this.action, this.onAction});

  final int index;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => StaggerItem(
    index: index,
    child: SectionHeader(
      title: title,
      actionLabel: action,
      onAction: onAction,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.s),
    ),
  );
}

// ------------------------------------------------------------------ pain --

/// The pain right now: eleven beads on the calm pain scale (0 at the reading
/// start); a tap logs that score at this moment, with an undo toast. "Where"
/// opens the full log (body map, locations, triggers, notes). Under the
/// title: today's entries and the highest score – numbers only.
class HealthPainCard extends ConsumerWidget {
  const HealthPainCard({super.key});

  Future<void> _log(BuildContext context, WidgetRef ref, int score) async {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final service = ref.read(wellbeingServiceProvider);
    try {
      final row = await service.logPain(PainDraft(at: ref.read(wellbeingClockProvider)(), score: score));
      Fx.fire(Sfx.complete);
      if (!context.mounted) return;
      unawaited(
        showUndoToast(
          context,
          UndoableAction(label: l.wbPainLogged(fmt.formatInt(score)), undo: () async => service.deletePain(row.id)),
        ),
      );
    } catch (e) {
      Fx.fire(Sfx.error);
      debugPrint('Health hub: logging pain failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final today = HealthHubLogic.painToday(ref.watch(todayPainProvider));
    final summary = today == null
        ? l.healthHubPainNone
        : l.healthHubPainToday(today.count, fmt.formatInt(today.count), fmt.formatInt(today.highest));
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.l),
      seed: 2.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.healing_rounded, size: 18, color: t.gold),
              const SizedBox(width: Space.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(l.healthHubPainTitle, style: text.titleMedium)),
                    Text(
                      summary,
                      style: text.bodySmall!.copyWith(color: t.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.s),
              MadarButton(
                label: l.healthHubPainWhere,
                icon: Icons.accessibility_new_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                semanticLabel: l.healthHubPainWhereHint,
                onPressed: () => showPainLogSheet(context),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Space.xs),
            child: _PainBeads(onPick: (score) => _log(context, ref, score)),
          ),
          const SizedBox(height: Space.xs),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.xxs),
            child: Row(
              children: [
                Text(l.healthHubPainLow, style: text.labelSmall!.copyWith(color: t.textTertiary)),
                const Spacer(),
                Text(l.healthHubPainHigh, style: text.labelSmall!.copyWith(color: t.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Eleven numbered beads, 0 to 10 in the reading direction, each in the
/// calm pain colour of its score (every theme's own tokens).
class _PainBeads extends StatelessWidget {
  const _PainBeads({required this.onPick});

  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        for (var score = 0; score <= 10; score++)
          Expanded(
            child: MadarPressable(
              onTap: () => onPick(score),
              sfx: Sfx.countTick,
              pressScale: 0.86,
              semanticLabel: l.healthHubPainLogScore(fmt.formatInt(score), fmt.formatInt(10)),
              excludeChildSemantics: true,
              focusRadius: BorderRadius.circular(20),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: WbPalette.pain(t, score).withValues(alpha: t.isDark ? 0.22 : 0.16),
                      border: Border.all(color: WbPalette.pain(t, score).withValues(alpha: 0.85), width: 1.2),
                      boxShadow: [
                        BoxShadow(color: WbPalette.painGlow(t, score).withValues(alpha: 0.28), blurRadius: 8),
                      ],
                    ),
                    child: Text(
                      fmt.formatInt(score),
                      style: text.labelMedium!.copyWith(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- questions --

/// The questions still open for the doctor – up to three, each with the
/// appointment it is for; the tick records an answer (with undo), the card
/// opens the record's questions, "+" adds one.
class HealthQuestionsCard extends ConsumerWidget {
  const HealthQuestionsCard({super.key, this.maxRows = 3});

  final int maxRows;

  Future<void> _answer(BuildContext context, WidgetRef ref, DoctorQuestionRow q) async {
    final undo = await RecordActions(context, ref).markAnswered(q);
    if (undo != null && context.mounted) unawaited(showUndoToast(context, undo));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final open = HealthHubLogic.openQuestions(ref.watch(doctorQuestionsProvider).value ?? const []);
    if (open.isEmpty) return const SizedBox.shrink();
    final titles = {for (final a in ref.watch(appointmentsProvider).value ?? const <AppointmentRow>[]) a.id: a.title};
    final shown = open.take(maxRows).toList();
    final more = open.length - shown.length;
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
      seed: 4.2,
      onTap: () => HealthNav.record(context, tab: RecordTab.questions),
      semanticLabel:
          '${l.healthHubQuestionsTitle}: ${l.healthHubQuestionsCount(open.length, fmt.formatInt(open.length))}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(RecordIcons.questions, size: 18, color: t.info),
              const SizedBox(width: Space.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(header: true, child: Text(l.healthHubQuestionsTitle, style: text.titleMedium)),
                    Text(
                      l.healthHubQuestionsCount(open.length, fmt.formatInt(open.length)),
                      style: text.bodySmall!.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              MadarButton.icon(
                icon: Icons.add_rounded,
                semanticLabel: l.recordQuestionAdd,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
                onPressed: () => RecordActions(context, ref).addQuestion(),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          for (final q in shown)
            _QuestionRow(
              question: q,
              appointment: q.appointmentId == null ? null : titles[q.appointmentId],
              onAnswer: () => _answer(context, ref, q),
            ),
          if (more > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 44, top: Space.xxs),
              child: Text(
                l.recordQuestionsMore(more, fmt.formatInt(more)),
                style: text.labelMedium!.copyWith(color: t.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.question, required this.onAnswer, this.appointment});

  final DoctorQuestionRow question;
  final String? appointment;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MadarPressable(
            onTap: onAnswer,
            sfx: Sfx.tap,
            semanticLabel: '${l.recordQuestionMarkAnswered}: ${question.question}',
            excludeChildSemantics: true,
            focusRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.info.withValues(alpha: 0.7), width: 1.4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question.question, style: text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (appointment != null)
                    Text(
                      l.healthHubQuestionFor(BidiIsolate.isolate(appointment!)),
                      style: text.labelSmall!.copyWith(color: t.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- tools --

/// The health tools: a grid of three by two glass tiles, each a brass seal
/// around its icon over its name – medications, labs and appointments, then
/// wellbeing, breathing and the doctor summary (PDF).
class HealthTools extends StatelessWidget {
  const HealthTools({super.key});

  static const int columns = 3;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final tools = <_Tool>[
      (
        Icons.medication_rounded,
        l.healthHubToolMeds,
        l.healthHubToolMedsHint,
        () => HealthNav.meds(context, tab: MedsTab.meds),
      ),
      (RecordIcons.labs, l.healthHubToolLabs, l.healthHubToolLabsHint, () => HealthNav.record(context)),
      (
        RecordIcons.appointments,
        l.healthHubToolAppointments,
        l.healthHubToolAppointmentsHint,
        () => HealthNav.appointments(context),
      ),
      (Icons.spa_outlined, l.healthHubToolWellbeing, l.healthHubToolWellbeingHint, () => HealthNav.wellbeing(context)),
      (Icons.air_rounded, l.healthHubToolBreathe, l.healthHubToolBreatheHint, () => HealthNav.breathing(context)),
      (RecordIcons.report, l.healthHubToolReport, l.healthHubToolReportHint, () => showDoctorReportSheet(context)),
    ];
    final rows = <Widget>[];
    for (var i = 0; i < tools.length; i += columns) {
      if (i > 0) rows.add(const SizedBox(height: Space.s));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = i; j < i + columns; j++) ...[
                if (j > i) const SizedBox(width: Space.s),
                Expanded(child: j < tools.length ? _ToolTile(tool: tools[j]) : const SizedBox.shrink()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Icon, name, hint (for screen readers) and where it leads.
typedef _Tool = (IconData, String, String, VoidCallback);

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool});

  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (icon, title, hint, onTap) = tool;
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.navigate,
      semanticLabel: '$title. $hint',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: GlassCard(
        glow: false,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.m),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Seal(icon: icon),
            const SizedBox(height: Space.s),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall!.copyWith(color: t.textPrimary, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

/// A brass eight-point seal holding a tool's icon (the Faith tools' seal).
class _Seal extends StatelessWidget {
  const _Seal({required this.icon});

  final IconData icon;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IslamicStar(size: size, color: t.accentSoft),
          IslamicStar(size: size, filled: false, color: t.brass.withValues(alpha: 0.8), strokeWidth: 1.2),
          Icon(icon, size: 20, color: t.accent),
        ],
      ),
    );
  }
}
