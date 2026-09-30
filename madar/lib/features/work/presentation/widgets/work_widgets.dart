import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../home/widgets/window_chips.dart' show windowIcon;
import '../../domain/countdown.dart';
import '../../domain/work_days.dart';
import '../work_labels.dart';

/// A glowing colour orb (board / project / planet colour).
class ColorOrb extends StatelessWidget {
  const ColorOrb({super.key, required this.color, this.size = 12, this.glow = true});

  final Color color;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Colors.black, 0.25)!],
          stops: const [0, 0.55, 1],
        ),
        boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: size * 0.8)] : null,
      ),
    );
  }
}

/// Small pill with an optional icon: due badges, window chips, assignees.
class WorkPill extends StatelessWidget {
  const WorkPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = false,
    this.leading,
    this.dense = true,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final bool filled;
  final Widget? leading;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.textSecondary;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsetsDirectional.symmetric(horizontal: dense ? Space.s : Space.m, vertical: dense ? 2 : Space.xs),
      decoration: BoxDecoration(
        // 0.14: the filled danger pill kept its text at AA on the planet
        // pages' tinted glass (0.18 measured 4.36 : 1 on Lapis).
        color: filled ? c.withValues(alpha: 0.14) : c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: filled ? 0.5 : 0.28), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Space.xs)],
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: c), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? text.labelSmall : text.labelMedium)!.copyWith(color: c, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// Due date badge (overdue / today / tomorrow / date).
class DueBadge extends StatelessWidget {
  const DueBadge({super.key, required this.due, required this.today, this.done = false});

  final DateTime due;
  final DateTime today;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final status = DueRules.of(due, today, done: done);
    final urgent = status == DueStatus.overdue || status == DueStatus.today;
    return WorkPill(
      label: texts.due(due, today),
      icon: status == DueStatus.overdue ? Icons.error_outline_rounded : Icons.event_rounded,
      color: done ? t.textTertiary : dueColor(t, status),
      filled: urgent && !done,
    );
  }
}

/// A prayer-window chip ("Dhuhr → Asr", with the day when not today).
class WindowPill extends StatelessWidget {
  const WindowPill({super.key, required this.window, this.day, required this.today});

  final PrayerWindow window;
  final DateTime? day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final d = day;
    final label = d == null || WorkDays.same(d, today)
        ? texts.window(window)
        : texts.l.workWindowOnDay(texts.window(window), texts.day(d, today));
    return WorkPill(label: label, icon: windowIcon(window), color: t.highlight);
  }
}

/// A person's initial in a small disc + name.
class AssigneePill extends StatelessWidget {
  const AssigneePill({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : String.fromCharCode(trimmed.runes.first);
    return WorkPill(
      label: trimmed,
      color: t.secondary,
      leading: Container(
        width: 14,
        height: 14,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.secondary.withValues(alpha: 0.35), shape: BoxShape.circle),
        child: Text(
          initial.toUpperCase(),
          style: TextStyle(fontSize: 8.5, height: 1, fontWeight: FontWeight.w700, color: t.textPrimary),
        ),
      ),
    );
  }
}

/// A round count pill (column headers, tabs).
class CountPill extends StatelessWidget {
  const CountPill({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.textSecondary;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Label above a group of controls in a sheet.
class SheetSectionLabel extends StatelessWidget {
  const SheetSectionLabel(this.text, {super.key, this.icon, this.trailing});

  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.s, start: Space.xxs),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: t.accent), const SizedBox(width: Space.xs + 2)],
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.textSecondary)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Day choice: none / today / tomorrow / pick a date. [value] is a day.
class DayChoice extends StatelessWidget {
  const DayChoice({
    super.key,
    required this.value,
    required this.today,
    required this.onChanged,
    this.allowNone = true,
    this.noneLabel,
  });

  final DateTime? value;
  final DateTime today;
  final ValueChanged<DateTime?> onChanged;
  final bool allowNone;
  final String? noneLabel;

  @override
  Widget build(BuildContext context) {
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final v = value;
    final tomorrow = WorkDays.add(today, 1);
    final isToday = WorkDays.same(v, today), isTomorrow = WorkDays.same(v, tomorrow);
    final other = v != null && !isToday && !isTomorrow;
    Future<void> pick() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: v ?? today,
        firstDate: WorkDays.add(today, -365 * 3),
        lastDate: WorkDays.add(today, 365 * 5),
      );
      if (picked != null) onChanged(WorkDays.dateOnly(picked));
    }

    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        if (allowNone)
          MadarChip(
            label: noneLabel ?? l.workNoDate,
            selected: v == null,
            dense: true,
            onSelected: (_) => onChanged(null),
          ),
        MadarChip(label: l.workToday, selected: isToday, dense: true, onSelected: (_) => onChanged(today)),
        MadarChip(label: l.workTomorrow, selected: isTomorrow, dense: true, onSelected: (_) => onChanged(tomorrow)),
        MadarChip(
          label: other ? texts.fmt.formatDate(v, style: MadarDateStyle.dayMonth) : l.workPickDate,
          icon: Icons.calendar_month_rounded,
          selected: other,
          dense: true,
          sfx: Sfx.sheetOpen,
          onSelected: (_) => pick(),
        ),
      ],
    );
  }
}

/// Prayer-window choice (six windows + "anytime", optionally "not placed").
class WindowChoice extends StatelessWidget {
  const WindowChoice({super.key, required this.value, required this.onChanged, this.allowNone = true, this.includeAnytime = true});

  final PrayerWindow? value;
  final ValueChanged<PrayerWindow?> onChanged;
  final bool allowNone;
  final bool includeAnytime;

  @override
  Widget build(BuildContext context) {
    final texts = WorkTexts.of(context);
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        if (allowNone)
          MadarChip(
            label: texts.l.workNotPlaced,
            selected: value == null,
            dense: true,
            onSelected: (_) => onChanged(null),
          ),
        for (final w in PrayerWindow.values)
          if (includeAnytime || w != PrayerWindow.anytime)
            MadarChip(
              label: texts.window(w),
              icon: windowIcon(w),
              selected: value == w,
              dense: true,
              onSelected: (_) => onChanged(w),
            ),
      ],
    );
  }
}

/// Fades / slides content in when it first appears (honours reduced motion).
class WorkReveal extends StatelessWidget {
  const WorkReveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => StaggerItem(index: index, child: child);
}
