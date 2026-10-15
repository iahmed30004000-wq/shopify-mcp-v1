import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../data/meds_providers.dart';
import '../domain/course_schedule.dart';
import '../domain/med_models.dart';
import '../meds_texts.dart';
import 'meds_actions.dart';
import 'meds_sheets.dart';
import 'widgets/meds_widgets.dart';

/// Injection / treatment courses: phases, progress through them and the
/// next dose; tap for the dates.
class MedCoursesView extends ConsumerWidget {
  const MedCoursesView({super.key, this.bottomPadding = 110});

  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final courses = ref.watch(medCoursesProvider).value;
    if (courses == null) return const Center(child: OrbitLoader());
    if (courses.isEmpty) {
      return ListView(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xl, Space.gutter, bottomPadding),
        children: [
          AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.medsCoursesEmptyTitle,
            body: l.medsCoursesEmptyBody,
            actionLabel: l.medsAddCourse,
            actionIcon: Icons.add_rounded,
            onAction: () => MedsActions.addCourse(context, ref),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bottomPadding),
      itemCount: courses.length,
      separatorBuilder: (_, _) => const SizedBox(height: Space.m),
      itemBuilder: (context, i) => StaggerItem(index: i, child: CourseCard(course: courses[i])),
    );
  }
}

/// One course: its medication, phases (as a chain), a segmented progress
/// bar through the phases and the next dose.
class CourseCard extends ConsumerWidget {
  const CourseCard({super.key, required this.course});

  final CourseSpec course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(medsTodayDateProvider);
    final meds = ref.watch(medsListProvider).value ?? const <MedSpec>[];
    final med = meds.where((m) => m.id == course.medicationId).firstOrNull;
    final logs = ref.watch(medLogsProvider).value ?? const [];
    final takenToday = med != null &&
        logs.any((lg) => lg.medId == med.id && lg.status == DoseStatus.taken && MedDays.same(lg.slot ?? lg.at ?? DateTime(0), today));
    final p = CourseSchedule.progress(course, today, takenToday: takenToday);
    final end = CourseSchedule.endDate(course);
    final color = medColor(med?.color, t);

    final String status;
    if (!p.started) {
      status = l.medsCourseStarts(fmt.formatDate(course.startDate, style: MadarDateStyle.weekdayDayMonth));
    } else if (p.finished) {
      status = l.medsCourseFinished(fmt.formatDate(end ?? p.last?.day ?? today, style: MadarDateStyle.medium));
    } else if (p.next != null) {
      status = MedDays.same(p.next!.day, today)
          ? l.medsCourseNext(l.medsToday)
          : l.medsCourseNext(fmt.formatDate(p.next!.day, style: MadarDateStyle.weekdayDayMonth));
    } else {
      status = '';
    }

    return ActionableItem(
      semanticLabel: '${course.name}. $status',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => showCourseSheet(context, courseId: course.id),
      actions: ItemActions(
        onEdit: () => MedsActions.editCourse(context, ref, course),
        onDelete: () => MedsActions.deleteCourse(context, ref, course),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.medsDelete,
          onPressed: () => MedsActions.deleteCourse(context, ref, course),
          tone: ActionTone.danger,
        ),
      ],
      child: GlassCard(
        borderRadius: BorderRadius.circular(t.radiusL),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.18),
                    border: Border.all(color: color.withValues(alpha: 0.7)),
                  ),
                  child: Icon(Icons.vaccines_rounded, size: 20, color: t.textPrimary),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: BidiIsolate.directionOf(course.name),
                        style: text.titleMedium,
                      ),
                      Text(
                        med == null
                            ? l.medsCourseNoMed
                            : [tx.name(med.name), if (med.dose != null) tx.dose(med.dose!)].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall!.copyWith(color: med == null ? t.warning : t.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (!course.active) MedBadge(label: l.medsCoursePaused, color: t.textTertiary, icon: Icons.pause_rounded),
              ],
            ),
            const SizedBox(height: Space.m),
            // The phases as a chain, in reading order.
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (i, ph) in course.phases.indexed) ...[
                  if (i > 0) Icon(Icons.arrow_forward_rounded, size: 14, color: t.textTertiary),
                  MedBadge(
                    label: tx.phase(ph),
                    color: i == p.phase && p.started && !p.finished ? t.accent : t.gold,
                    filled: i == p.phase && p.started && !p.finished,
                  ),
                ],
              ],
            ),
            const SizedBox(height: Space.m),
            CoursePhaseBar(course: course, progress: p),
            const SizedBox(height: Space.s),
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.started ? tx.courseProgress(course, p) : '',
                    style: text.labelMedium!.copyWith(color: t.textSecondary),
                  ),
                ),
                Text(status, style: text.labelMedium!.copyWith(color: p.finished ? t.success : t.accent)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A bar split into the course's phases (widths by their dose counts; an
/// ongoing phase gets a steady share), filled up to where the course
/// stands. Phases run in the reading direction.
class CoursePhaseBar extends StatelessWidget {
  const CoursePhaseBar({super.key, required this.course, required this.progress, this.height = 10});

  final CourseSpec course;
  final CourseProgress progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final phases = course.phases;
    if (phases.isEmpty) return SizedBox(height: height);
    int weight(CoursePhase p) => (p.count ?? 6).clamp(3, 12);
    double fill(int i) {
      if (!progress.started) return 0;
      if (progress.finished || i < progress.phase) return 1;
      if (i > progress.phase) return 0;
      final n = phases[i].count;
      if (n == null) return progress.doneInPhase > 0 ? 0.5 : 0.08;
      return (progress.doneInPhase / n).clamp(0.0, 1.0);
    }

    return Semantics(
      value: MadarFormatter.of(context).formatPercent(progress.fraction ?? 0),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < phases.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              Expanded(
                flex: weight(phases[i]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(height),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: t.glassFill),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height),
                          border: Border.all(color: t.glassBorder, width: 0.6),
                        ),
                      ),
                      SpringBuilder(
                        value: fill(i),
                        from: 0,
                        builder: (context, v, _) => FractionallySizedBox(
                          alignment: AlignmentDirectional.centerStart,
                          widthFactor: v.clamp(0.0, 1.0),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: AlignmentDirectional.centerStart,
                                end: AlignmentDirectional.centerEnd,
                                colors: [
                                  (i < progress.phase || progress.finished ? t.success : t.accent).withValues(alpha: 0.75),
                                  i < progress.phase || progress.finished ? t.success : Color.lerp(t.accent, t.starTint, 0.2)!,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
