import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../src/labels.dart';
import 'field_inputs.dart';
import 'reminder_rule.dart';
import 'sheet.dart';

/// Result of [showReminderSheet] when the user tapped "Remove reminder"
/// (only offered with `allowRemove: true`). Check with `result.isEmpty`.
const Map<String, Object?> kReminderRemoved = <String, Object?>{};

/// Opens the reminder sheet and resolves with a rule JSON in the exact shape
/// of `Reminders.rule` (see [ReminderRule]), or null when dismissed.
///
/// * [initial] – an existing rule to edit.
/// * [allowPrayerRelative] – offer "with prayer" reminders (window + offset).
/// * [dueDate] – enables "before due" reminders and makes them the default.
/// * [allowRemove] – adds a "Remove reminder" action resolving with
///   [kReminderRemoved].
Future<Map<String, Object?>?> showReminderSheet(
  BuildContext context, {
  Map<String, Object?>? initial,
  bool allowPrayerRelative = true,
  DateTime? dueDate,
  bool allowRemove = false,
  String? title,
  DateTime? now,
}) {
  return showInteractionSheet<Map<String, Object?>>(
    context,
    builder: (_) => ReminderSheet(
      initial: initial,
      allowPrayerRelative: allowPrayerRelative,
      dueDate: dueDate,
      allowRemove: allowRemove,
      title: title,
      now: now,
    ),
  );
}

/// Human description of a stored rule ("Tomorrow at 9:00 AM", "10 minutes
/// after Asr" …) for rows and chips; null when [rule] is malformed.
String? describeReminder(BuildContext context, Map<String, Object?>? rule, {DateTime? now}) {
  final r = ReminderRule.fromJson(rule);
  return r == null ? null : describeReminderRule(context, r, now: now);
}

/// [describeReminder] for a parsed [ReminderRule].
String describeReminderRule(BuildContext context, ReminderRule rule, {DateTime? now}) {
  final l = L10n.of(context);
  switch (rule) {
    case OnceReminder(:final at):
      return l.interactionReminderOnce(
        KitLabels.date(context, at, now: now),
        KitLabels.time(context, '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'),
      );
    case DailyReminder(:final time):
      return l.interactionReminderDaily(KitLabels.time(context, time));
    case WeeklyReminder(:final time, :final weekdays):
      if (weekdays.length == 7) return l.interactionReminderDaily(KitLabels.time(context, time));
      final ordered = orderedWeekdays(context).where(weekdays.contains);
      return l.interactionReminderWeekly(
        ordered.map((d) => KitLabels.weekday(l, d)).join(l.interactionListSeparator),
        KitLabels.time(context, time),
      );
    case PrayerReminder(:final window, :final offsetMin):
      final prayer = KitLabels.prayer(l, window);
      if (offsetMin == 0) return l.interactionReminderPrayerAt(prayer);
      final d = KitLabels.duration(l, offsetMin.abs());
      return offsetMin < 0 ? l.interactionReminderPrayerBefore(prayer, d) : l.interactionReminderPrayerAfter(prayer, d);
    case BeforeDueReminder(:final minutes):
      return l.interactionReminderBefore(KitLabels.duration(l, minutes));
  }
}

/// Dart weekdays (1 = Monday … 7 = Sunday) starting from the locale's first
/// day of the week (Saturday in Arabic, Sunday in English).
List<int> orderedWeekdays(BuildContext context) {
  // MaterialLocalizations: 0 = Sunday … 6 = Saturday.
  final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  final firstDart = first == 0 ? DateTime.sunday : first;
  return [for (var i = 0; i < 7; i++) (firstDart - 1 + i) % 7 + 1];
}

/// The sheet body (public for embedding / tests).
class ReminderSheet extends StatefulWidget {
  const ReminderSheet({
    super.key,
    this.initial,
    this.allowPrayerRelative = true,
    this.dueDate,
    this.allowRemove = false,
    this.title,
    this.now,
  });

  final Map<String, Object?>? initial;
  final bool allowPrayerRelative;
  final DateTime? dueDate;
  final bool allowRemove;
  final String? title;

  /// Clock override (tests).
  final DateTime? now;

  @override
  State<ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<ReminderSheet> {
  late final ReminderDraft _draft = ReminderDraft(
    now: widget.now ?? DateTime.now(),
    dueDate: widget.dueDate,
    allowPrayerRelative: widget.allowPrayerRelative,
    initial: widget.initial,
  );
  bool _revealed = false;

  /// Workdays in the region: Sunday–Thursday.
  static const List<int> _workdays = [
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
  ];

  @override
  void initState() {
    super.initState();
    _draft.addListener(_onDraft);
  }

  void _onDraft() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _draft.removeListener(_onDraft);
    _draft.dispose();
    super.dispose();
  }

  void _save() {
    final rule = _draft.build();
    if (rule == null) {
      Fx.fire(Sfx.error);
      setState(() => _revealed = true);
      return;
    }
    Fx.fire(Sfx.complete);
    Navigator.of(context).pop(rule.toJson());
  }

  static IconData _kindIcon(ReminderKind k) => switch (k) {
    ReminderKind.once => Icons.event_rounded,
    ReminderKind.daily => Icons.repeat_rounded,
    ReminderKind.weekly => Icons.date_range_rounded,
    ReminderKind.prayer => Icons.mosque_rounded,
    ReminderKind.beforeDue => Icons.hourglass_bottom_rounded,
  };

  static String _kindLabel(L10n l, ReminderKind k) => switch (k) {
    ReminderKind.once => l.interactionReminderKindOnce,
    ReminderKind.daily => l.interactionReminderKindDaily,
    ReminderKind.weekly => l.interactionReminderKindWeekly,
    ReminderKind.prayer => l.interactionReminderKindPrayer,
    ReminderKind.beforeDue => l.interactionReminderKindBeforeDue,
  };

  String? _issueText(L10n l, ReminderIssue? issue) => switch (issue) {
    ReminderIssue.inPast => l.interactionReminderPast,
    ReminderIssue.noWeekdays => l.interactionReminderNoDays,
    ReminderIssue.noDueDate => l.interactionReminderNoDue,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final issue = _draft.issue;
    // Past-time errors show at once (the user just picked it); a missing day
    // only after an attempt to save.
    final visibleIssue = issue == ReminderIssue.inPast || _revealed ? _issueText(l10n, issue) : null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Summary(rule: _draft.build(), now: _draft.now),
        const SizedBox(height: Space.l),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final k in _draft.availableKinds)
              KitChip(
                key: ValueKey('kind-${k.name}'),
                label: _kindLabel(l10n, k),
                icon: _kindIcon(k),
                selected: _draft.kind == k,
                sfx: Sfx.tap,
                onTap: () {
                  _draft.kind = k;
                  _revealed = false;
                },
              ),
          ],
        ),
        const SizedBox(height: Space.xl),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.emphasized,
          alignment: AlignmentDirectional.topStart,
          child: AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) =>
                Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
            child: KeyedSubtree(key: ValueKey(_draft.kind), child: _panel(context, l10n, visibleIssue)),
          ),
        ),
      ],
    );

    return InteractionSheetFrame(
      title: widget.title ?? l10n.interactionReminderTitle,
      icon: Icons.notifications_active_rounded,
      body: body,
      footer: Row(
        children: [
          if (widget.allowRemove) ...[
            Expanded(
              flex: 3,
              child: SheetButton(
                label: l10n.interactionReminderRemove,
                icon: Icons.notifications_off_rounded,
                tone: context.tokens.danger,
                sfx: Sfx.delete,
                onPressed: () => Navigator.of(context).pop(kReminderRemoved),
              ),
            ),
            const SizedBox(width: Space.m),
          ] else ...[
            Expanded(
              flex: 2,
              child: SheetButton(label: l10n.actionCancel, onPressed: () => Navigator.of(context).maybePop()),
            ),
            const SizedBox(width: Space.m),
          ],
          Expanded(
            flex: 3,
            child: SheetButton(
              label: l10n.actionSave,
              icon: Icons.check_rounded,
              primary: true,
              enabled: _draft.isValid,
              sfx: null,
              onPressed: _save,
              onDisabledTap: _save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, L10n l10n, String? error) {
    final today = DateTime(_draft.now.year, _draft.now.month, _draft.now.day);
    Widget timeField({String? error}) => FieldShell(
      label: l10n.interactionReminderTime,
      icon: Icons.schedule_rounded,
      error: error,
      child: TimeWheel(value: _draft.time, onChanged: (v) => _draft.time = v),
    );
    switch (_draft.kind) {
      case ReminderKind.once:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldShell(
              label: l10n.interactionReminderDate,
              icon: Icons.event_rounded,
              child: InlineDatePicker(
                value: _draft.date,
                firstDate: today,
                allowClear: false,
                now: _draft.now,
                onChanged: (d) {
                  if (d != null) _draft.date = d;
                },
              ),
            ),
            const SizedBox(height: Space.l),
            timeField(error: error),
          ],
        );
      case ReminderKind.daily:
        return timeField();
      case ReminderKind.weekly:
        final selected = _draft.weekdays;
        final all = selected.length == 7;
        final work = selected.length == _workdays.length && _workdays.every(selected.contains);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldShell(
              label: l10n.interactionReminderDays,
              icon: Icons.date_range_rounded,
              error: error,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: Space.xs + 2,
                    runSpacing: Space.s,
                    children: [
                      for (final d in orderedWeekdays(context))
                        KitChip(
                          key: ValueKey('day-$d'),
                          dense: true,
                          label: KitLabels.weekday(l10n, d),
                          selected: selected.contains(d),
                          onTap: () => _draft.toggleWeekday(d),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.s),
                  Wrap(
                    spacing: Space.s,
                    runSpacing: Space.s,
                    children: [
                      KitChip(
                        dense: true,
                        icon: Icons.work_outline_rounded,
                        label: l10n.interactionReminderWorkdays,
                        selected: work,
                        sfx: Sfx.tap,
                        onTap: () => _draft.weekdays = _workdays,
                      ),
                      KitChip(
                        dense: true,
                        icon: Icons.all_inclusive_rounded,
                        label: l10n.interactionReminderEveryDay,
                        selected: all,
                        sfx: Sfx.tap,
                        onTap: () => _draft.weekdays = const [1, 2, 3, 4, 5, 6, 7],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.l),
            timeField(),
          ],
        );
      case ReminderKind.prayer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldShell(
              label: l10n.interactionReminderPrayer,
              icon: Icons.mosque_rounded,
              child: PrayerWindowPicker(
                value: _draft.window,
                includeAnytime: false,
                allowClear: false,
                usePrayerNames: true,
                onChanged: (w) {
                  if (w != null) _draft.window = w;
                },
              ),
            ),
            const SizedBox(height: Space.l),
            FieldShell(
              label: l10n.interactionReminderOffset,
              icon: Icons.av_timer_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: Space.s,
                    runSpacing: Space.s,
                    children: [
                      for (final (r, label) in [
                        (PrayerRelation.before, l10n.interactionReminderRelBefore),
                        (PrayerRelation.at, l10n.interactionReminderRelAt),
                        (PrayerRelation.after, l10n.interactionReminderRelAfter),
                      ])
                        KitChip(
                          key: ValueKey('rel-${r.name}'),
                          label: label,
                          selected: _draft.relation == r,
                          sfx: Sfx.tap,
                          onTap: () => _draft.relation = r,
                        ),
                    ],
                  ),
                  AnimatedSize(
                    duration: context.motion(MadarMotion.medium),
                    curve: MadarMotion.emphasized,
                    alignment: AlignmentDirectional.topStart,
                    child: _draft.relation == PrayerRelation.at
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsetsDirectional.only(top: Space.m),
                            child: Wrap(
                              spacing: Space.s,
                              runSpacing: Space.s,
                              children: [
                                for (final m in ReminderDraft.offsetChoices)
                                  KitChip(
                                    key: ValueKey('offset-$m'),
                                    dense: true,
                                    label: KitLabels.duration(l10n, m),
                                    selected: _draft.offsetMinutes == m,
                                    sfx: Sfx.tap,
                                    onTap: () => _draft.offsetMinutes = m,
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      case ReminderKind.beforeDue:
        return FieldShell(
          label: l10n.interactionReminderLead,
          icon: Icons.hourglass_bottom_rounded,
          error: error,
          child: Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final m in ReminderDraft.leadChoices)
                KitChip(
                  key: ValueKey('lead-$m'),
                  label: KitLabels.duration(l10n, m),
                  selected: _draft.leadMinutes == m,
                  sfx: Sfx.tap,
                  onTap: () => _draft.leadMinutes = m,
                ),
            ],
          ),
        );
    }
  }
}

/// The glowing "when" line at the top of the sheet.
class _Summary extends StatelessWidget {
  const _Summary({required this.rule, required this.now});

  final ReminderRule? rule;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final r = rule;
    final label = r == null ? '—' : describeReminderRule(context, r, now: now);
    final icon = switch (r) {
      PrayerReminder(:final window) => KitLabels.windowIcon(window),
      null => Icons.notifications_paused_rounded,
      _ => Icons.notifications_active_rounded,
    };
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusL),
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [t.accentSoft, t.accentSoft.withValues(alpha: 0)],
        ),
        border: Border.all(color: t.accent.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            transitionBuilder: (child, a) => ScaleTransition(
              scale: a,
              child: FadeTransition(opacity: a, child: child),
            ),
            child: Icon(icon, key: ValueKey(icon), color: r == null ? t.warning : t.accent, size: 24),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: context.motion(MadarMotion.short),
                layoutBuilder: (current, previous) =>
                    Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                child: Text(
                  label,
                  key: ValueKey(label),
                  style: text.titleMedium?.copyWith(color: r == null ? t.textTertiary : t.textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
