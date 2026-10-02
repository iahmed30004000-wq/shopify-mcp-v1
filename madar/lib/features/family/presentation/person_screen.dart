import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../data/contact_launcher.dart';
import '../data/family_providers.dart';
import '../domain/birthdays.dart';
import '../domain/contact_stats.dart';
import '../domain/family_models.dart';
import '../domain/rhythm.dart';
import '../family_texts.dart';
import 'family_actions.dart';
import 'widgets/family_widgets.dart';

/// A person's page: their orb, where they stand against the rhythm and the
/// big "contacted" button (with call / SMS / WhatsApp when there is a
/// number); rhythm statistics (average gap vs rhythm, share on rhythm, the
/// last 90 days, the longest gap, the recent gaps as bars); the birthday
/// countdown; notes; and the contact history (tap to edit, swipe or
/// long-press to delete – with undo).
class PersonScreen extends ConsumerWidget {
  const PersonScreen({super.key, required this.personId, this.animateBackdrop = true});

  final String personId;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = FamilyTexts.of(context);
    final l = tx.l;
    final row = ref.watch(familyPersonProvider(personId));
    final person = ref.watch(familyPersonViewProvider(personId));
    final stats = ref.watch(familyPersonStatsProvider(personId));
    final logs = ref.watch(familyPersonLogsProvider(personId)).value ?? const <ContactLogRow>[];
    final gone = row is AsyncData<PersonRow?> && row.value == null;
    return MadarScaffold(
      title: person == null ? l.familyTitle : tx.name(person.name),
      backdropSeed: 2.7,
      animateBackdrop:
          animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        if (person != null) ...[
          MadarButton.icon(
            icon: Icons.edit_rounded,
            onPressed: () => FamilyActions.editPerson(context, ref, person.row),
            semanticLabel: l.familyEdit,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.sheetOpen,
          ),
          MadarButton.icon(
            icon: Icons.delete_outline_rounded,
            onPressed: () async {
              final nav = Navigator.of(context);
              await FamilyActions.deletePerson(context, ref, person.row, toast: true);
              if (nav.canPop()) nav.pop();
            },
            semanticLabel: l.familyDelete,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.delete,
          ),
        ],
      ],
      body: gone
          ? const Center(child: AnimatedEmptyState(kind: EmptyStateKind.noData))
          : person == null || stats == null
          ? const Center(child: OrbitLoader(size: 40))
          : _Body(person: person, stats: stats, logs: logs),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.person, required this.stats, required this.logs});

  final PersonView person;
  final ContactStats stats;
  final List<ContactLogRow> logs;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  static const _historyPage = 20;
  bool _allHistory = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final logs = widget.logs;
    final shown = _allHistory ? logs : logs.take(_historyPage).toList();
    final l = FamilyTexts.of(context).l;
    var i = 0;
    return EntranceChoreo(
      id: 'family/person/${p.id}',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          StaggerItem(
            index: i++,
            child: _Header(person: p),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: _RhythmCard(person: p, stats: widget.stats),
          ),
          if (p.birthday != null) ...[
            const SizedBox(height: Space.m),
            StaggerItem(
              index: i++,
              child: _BirthdayCard(info: p.birthday!),
            ),
          ],
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: _NotesCard(person: p),
          ),
          StaggerItem(
            index: i++,
            child: SectionHeader(
              title: l.familyHistoryTitle,
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.s),
            ),
          ),
          if (logs.isEmpty)
            StaggerItem(
              index: i++,
              child: _HistoryEmpty(text: l.familyHistoryEmpty),
            ),
          for (var k = 0; k < shown.length; k++)
            StaggerItem(
              index: i++,
              child: _HistoryRow(
                key: ValueKey(shown[k].id),
                log: shown[k],
                personName: p.name,
                first: k == 0,
                last: k == shown.length - 1,
              ),
            ),
          if (!_allHistory && logs.length > _historyPage)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.s),
              child: MadarButton(
                label: l.familyOpenAll,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                icon: Icons.expand_more_rounded,
                onPressed: () => setState(() => _allHistory = true),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.person});

  final PersonView person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final r = person.rhythm;
    final relation = tx.relationBeside(person.name, person.relation);
    final statusColor = familyStatusColor(r.status, t);
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusXL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xl, Space.l, Space.l),
      child: Column(
        children: [
          PersonAvatar(person: person, size: 104),
          const SizedBox(height: Space.m),
          Text(
            tx.name(person.name),
            textAlign: TextAlign.center,
            style: text.headlineSmall!.copyWith(color: t.textPrimary),
          ),
          if (relation != null) Text(tx.name(relation), style: text.bodyMedium!.copyWith(color: t.textSecondary)),
          const SizedBox(height: Space.s),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              if (r.hasRhythm)
                FamilyBadge(
                  label: tx.status(r),
                  color: r.status == RhythmStatus.ok ? t.success : statusColor,
                  icon: r.status == RhythmStatus.overdue ? Icons.priority_high_rounded : Icons.schedule_rounded,
                  filled: true,
                ),
              FamilyBadge(label: tx.lastContact(r), color: t.textSecondary, icon: Icons.history_rounded),
              if (!person.row.showAsMoon)
                FamilyBadge(label: l.familyMoonShow, color: t.textTertiary, icon: Icons.brightness_3_outlined),
            ],
          ),
          const SizedBox(height: Space.l),
          Builder(
            builder: (buttonContext) => MadarButton(
              label: l.familyContacted,
              icon: Icons.favorite_rounded,
              expand: true,
              size: MadarButtonSize.large,
              sfx: Sfx.sparkle,
              onPressed: () => unawaited(FamilyActions.contacted(buttonContext, ref, person)),
            ),
          ),
          const SizedBox(height: Space.s),
          MadarButton(
            label: l.familyContactedDetails,
            icon: Icons.edit_calendar_rounded,
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            sfx: Sfx.tap,
            onPressed: () => unawaited(FamilyActions.contactedWithDetails(context, ref, person)),
          ),
          if (person.hasPhone) ...[
            const SizedBox(height: Space.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FamilyRoundAction(
                  icon: Icons.call_rounded,
                  label: l.familyCall,
                  color: t.success,
                  onTap: () => FamilyActions.launch(context, ref, person, ContactLaunch.call),
                ),
                FamilyRoundAction(
                  icon: Icons.sms_rounded,
                  label: l.familySms,
                  color: t.info,
                  onTap: () => FamilyActions.launch(context, ref, person, ContactLaunch.sms),
                ),
                FamilyRoundAction(
                  icon: Icons.chat_rounded,
                  label: l.familyWhatsApp,
                  color: t.accent,
                  onTap: () => FamilyActions.launch(context, ref, person, ContactLaunch.whatsapp),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RhythmCard extends StatelessWidget {
  const _RhythmCard({required this.person, required this.stats});

  final PersonView person;
  final ContactStats stats;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final rhythm = person.rhythm.rhythmDays;
    final avg = stats.averageInterval;
    final chart = ContactStatsMath.chart(stats);
    Widget tile(String label, String value, {String? unit, IconData? icon, Color? color, String? caption}) => Expanded(
      child: StatTile(label: label, value: value, unit: unit, icon: icon, color: color, caption: caption),
    );
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.autorenew_rounded, size: 18, color: t.accent),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.familyRhythmCardTitle, style: text.titleMedium)),
              Text(tx.rhythm(rhythm), style: text.labelLarge!.copyWith(color: t.accent)),
            ],
          ),
          const SizedBox(height: Space.m),
          if (!stats.hasIntervals && stats.total < 2)
            Text(l.familyStatsEmpty, style: text.bodySmall!.copyWith(color: t.textSecondary))
          else ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tile(
                    l.familyStatAverage,
                    avg == null ? '—' : tx.decimal(avg),
                    unit: avg == null ? null : l.familyUnitDays,
                    icon: Icons.timelapse_rounded,
                    color: avg == null || rhythm == null ? t.accent : (avg <= rhythm ? t.success : t.warning),
                    caption: rhythm == null ? null : l.familyVsRhythm(tx.rhythm(rhythm)),
                  ),
                  const SizedBox(width: Space.s),
                  tile(
                    l.familyStatOnRhythm,
                    stats.onRhythmShare == null ? '—' : tx.percent(stats.onRhythmShare!),
                    icon: Icons.verified_rounded,
                    color: t.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.s),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tile(
                    l.familyStatRecent,
                    tx.fmt.localizeDigits(l.familyStatTimes(stats.recent)),
                    icon: Icons.favorite_rounded,
                    color: t.accent,
                  ),
                  const SizedBox(width: Space.s),
                  tile(
                    l.familyStatLongestGap,
                    stats.longestGap == null ? '—' : tx.days(stats.longestGap!),
                    icon: Icons.hourglass_bottom_rounded,
                    color: t.gold,
                  ),
                ],
              ),
            ),
            if (chart.length >= 2) ...[
              const SizedBox(height: Space.l),
              IntervalBars(intervals: chart, rhythmDays: rhythm),
              const SizedBox(height: Space.xs),
              Text(
                l.familyChartCaption,
                textAlign: TextAlign.center,
                style: text.labelSmall!.copyWith(color: t.textTertiary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The recent gaps between contacts as bars (oldest at the reading start),
/// with the rhythm as a dashed line: green within the rhythm, amber past it,
/// red past twice the rhythm.
class IntervalBars extends StatelessWidget {
  const IntervalBars({super.key, required this.intervals, this.rhythmDays, this.height = 96});

  final List<int> intervals;
  final int? rhythmDays;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final rhythm = rhythmDays;
    final top = math.max(intervals.fold<int>(1, math.max), rhythm ?? 1) * 1.15;
    Color colorOf(int g) {
      if (rhythm == null) return t.accent;
      if (g <= rhythm) return t.success;
      if (g <= rhythm * 2) return t.warning;
      return t.danger;
    }

    return SizedBox(
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: context.motion(MadarMotion.long),
        curve: MadarMotion.decelerate,
        builder: (context, grow, _) => Stack(
          children: [
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final g in intervals)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(tx.count(g), style: text.labelSmall!.copyWith(color: t.textTertiary, fontSize: 10)),
                            const SizedBox(height: 2),
                            Container(
                              height: math.max(3, (height - 18) * g / top * grow),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(5),
                                  bottom: Radius.circular(2),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [colorOf(g), colorOf(g).withValues(alpha: 0.35)],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (rhythm != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: (height - 18) * rhythm / top,
                child: CustomPaint(size: const Size.fromHeight(1.4), painter: _DashPainter(t.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 5, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

class _BirthdayCard extends StatelessWidget {
  const _BirthdayCard({required this.info});

  final BirthdayInfo info;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final age = tx.age(info.turning);
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      borderColor: info.daysUntil <= 1 ? t.gold.withValues(alpha: 0.6) : null,
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.gold.withValues(alpha: t.isDark ? 0.16 : 0.12),
              border: Border.all(color: t.gold.withValues(alpha: 0.55)),
            ),
            child: Icon(Icons.cake_rounded, color: t.gold, size: 26),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.familyBirthdayTitle, style: text.labelMedium!.copyWith(color: t.textSecondary)),
                Text(tx.birthdayDate(info.birthday), style: text.titleMedium),
                if (age != null) Text(age, style: text.bodySmall!.copyWith(color: t.textTertiary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.xs + 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: t.gold.withValues(alpha: info.daysUntil <= 1 ? (t.isDark ? 0.22 : 0.14) : 0),
              border: Border.all(color: t.gold.withValues(alpha: 0.55)),
            ),
            child: Text(tx.birthdayWhen(info), style: text.titleSmall!.copyWith(color: t.gold)),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends ConsumerWidget {
  const _NotesCard({required this.person});

  final PersonView person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = FamilyTexts.of(context).l;
    final text = Theme.of(context).textTheme;
    final notes = person.row.notes;
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.all(Space.l),
      onTap: () => FamilyActions.editNotes(context, ref, person.row),
      semanticLabel: notes == null ? l.familyNotesAdd : '${l.familyNotesTitle}: $notes',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_rounded, size: 18, color: t.accent),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.familyNotesTitle, style: text.titleMedium),
                const SizedBox(height: Space.xs),
                Text(
                  notes ?? l.familyNotesAdd,
                  textDirection: notes == null ? null : BidiIsolate.directionOf(notes),
                  style: text.bodyMedium!.copyWith(color: notes == null ? t.textTertiary : t.textPrimary),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_rounded, size: 16, color: t.textTertiary),
        ],
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Row(
        children: [
          Icon(Icons.favorite_border_rounded, color: t.textTertiary),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({super.key, required this.log, required this.personName, required this.first, required this.last});

  final ContactLogRow log;
  final String personName;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final now = ref.watch(familyClockProvider)();
    final when = tx.when(log.at, now);
    final ago = tx.daysAgo(math.max(0, CalendarDays.between(log.at, now)));
    final c = switch (log.channel) {
      _ when first => t.accent,
      _ => t.textSecondary,
    };
    // The rail runs behind the bubbles (a Stack, not IntrinsicHeight: the
    // row's ActionableItem lays out with a LayoutBuilder).
    return Stack(
      children: [
        PositionedDirectional(
          start: 16.3,
          top: first ? 22 : 0,
          bottom: last ? null : 0,
          height: last ? 22 : null,
          child: Container(width: 1.4, color: t.glassBorder),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: 7),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.alphaBlend(c.withValues(alpha: t.isDark ? 0.18 : 0.12), t.space1),
                    border: Border.all(color: c.withValues(alpha: 0.6)),
                  ),
                  child: Icon(channelIcon(log.channel), size: 15, color: c),
                ),
              ),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                child: ActionableItem(
                  semanticLabel: [tx.channel(log.channel), when, ?log.note].join(l.familyDot),
                  borderRadius: BorderRadius.circular(t.radiusM),
                  onTap: () => FamilyActions.editContact(context, ref, log, personName),
                  swipeEnabled: true,
                  actions: ItemActions(
                    onEdit: () => FamilyActions.editContact(context, ref, log, personName),
                    onDelete: () => FamilyActions.deleteContact(context, ref, log),
                  ),
                  quickActions: [
                    QuickAction(
                      icon: Icons.delete_outline_rounded,
                      label: l.familyDelete,
                      tone: ActionTone.danger,
                      onPressed: () {
                        Fx.fire(Sfx.delete);
                        return FamilyActions.deleteContact(context, ref, log);
                      },
                    ),
                  ],
                  child: GlassCard(
                    borderRadius: BorderRadius.circular(t.radiusM),
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tx.channel(log.channel),
                                style: text.titleSmall!.copyWith(color: t.textPrimary),
                              ),
                            ),
                            Text(ago, style: text.labelSmall!.copyWith(color: t.textTertiary)),
                          ],
                        ),
                        Text(when, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                        if (log.note != null) ...[
                          const SizedBox(height: Space.xs),
                          Text(
                            log.note!,
                            textDirection: BidiIsolate.directionOf(log.note!),
                            style: text.bodyMedium!.copyWith(color: t.textPrimary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
