import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration, PickerButton;
import '../../../core/motion/motion_kit.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_catalog.dart';
import '../../../core/sound/sound_api.dart';
import '../../home/widgets/window_chips.dart' show windowIcon;
import '../data/wird_providers.dart';
import '../data/wird_service.dart';
import '../domain/calendar_days.dart';
import '../domain/quran_axis.dart';
import '../domain/wird_plan.dart';
import 'surah_picker_sheet.dart';
import 'wird_labels.dart';

/// Creates or edits a plan; returns the draft (null when dismissed).
Future<WirdDraft?> showWirdPlanSheet(BuildContext context, {WirdPlan? plan}) =>
    showInteractionSheet<WirdDraft>(context, builder: (_) => WirdPlanSheet(plan: plan));

IconData wirdTemplateIcon(WirdTemplate t) => switch (t) {
  WirdTemplate.khatma => Icons.auto_stories_rounded,
  WirdTemplate.pages => Icons.menu_book_rounded,
  WirdTemplate.juz => Icons.layers_rounded,
  WirdTemplate.hizb => Icons.view_agenda_rounded,
  WirdTemplate.ayat => Icons.format_list_numbered_rtl_rounded,
};

/// The plan editor: type (khatma in N days, or pages / juz / hizb / ayat a
/// day), amount, start position and date, prayer window and reminder,
/// catch-up mode and name – with a live preview of the finish date or daily
/// amount.
class WirdPlanSheet extends ConsumerStatefulWidget {
  const WirdPlanSheet({super.key, this.plan});

  final WirdPlan? plan;

  @override
  ConsumerState<WirdPlanSheet> createState() => _WirdPlanSheetState();
}

class _WirdPlanSheetState extends ConsumerState<WirdPlanSheet> {
  static const khatmaPresets = [15, 30, 60, 90, 120, 240];
  static const Map<WirdTemplate, List<double>> amountPresets = {
    WirdTemplate.pages: [1, 2, 4, 5, 10, 20],
    WirdTemplate.juz: [0.5, 1, 2, 3],
    WirdTemplate.hizb: [1, 2, 3, 4],
    WirdTemplate.ayat: [5, 10, 20, 50, 100],
  };
  static const Map<WirdTemplate, double> steps = {
    WirdTemplate.pages: 1,
    WirdTemplate.juz: 0.5,
    WirdTemplate.hizb: 1,
    WirdTemplate.ayat: 5,
  };
  static const Map<WirdTemplate, double> defaults = {
    WirdTemplate.pages: 2,
    WirdTemplate.juz: 1,
    WirdTemplate.hizb: 1,
    WirdTemplate.ayat: 10,
  };

  late WirdDraft _d;
  late final TextEditingController _name;
  bool _nameEdited = false;
  bool _nameError = false;

  bool get _editing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final today = ref.read(wirdTodayProvider);
    _d = widget.plan == null
        ? WirdDraft(name: '', template: WirdTemplate.khatma, startDate: today, window: PrayerWindow.fajr)
        : WirdDraft.of(widget.plan!);
    _nameEdited = _editing;
    _name = TextEditingController(text: _d.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _update(WirdDraft d, WirdTexts texts) {
    setState(() {
      _d = d;
      if (!_nameEdited) {
        _name.text = texts.defaultName(d.template, khatmaDays: d.khatmaDays, amount: d.amount);
      }
    });
  }

  void _save(WirdTexts texts) {
    final name = _name.text.trim();
    if (name.isEmpty) {
      Fx.fire(Sfx.error);
      setState(() => _nameError = true);
      return;
    }
    Navigator.of(context).pop(_d.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final catalog = ref.watch(quranCatalogReadyProvider);
    return switch (catalog) {
      AsyncData(:final value) => _form(context, l, value),
      AsyncError() => InteractionSheetFrame(
        title: _editing ? l.wirdEditPlanTitle : l.wirdNewPlanTitle,
        icon: Icons.auto_stories_rounded,
        body: Text(l.wirdCatalogError),
      ),
      _ => InteractionSheetFrame(
        title: _editing ? l.wirdEditPlanTitle : l.wirdNewPlanTitle,
        icon: Icons.auto_stories_rounded,
        body: const Padding(
          padding: EdgeInsets.all(Space.xl),
          child: Center(child: OrbitLoader(size: 36)),
        ),
      ),
    };
  }

  Widget _form(BuildContext context, L10n l, QuranCatalog catalog) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final texts = WirdTexts(l, fmt, catalog);
    if (!_nameEdited && _name.text.isEmpty) {
      _name.text = texts.defaultName(_d.template, khatmaDays: _d.khatmaDays, amount: _d.amount);
    }
    final today = ref.read(wirdTodayProvider);
    final pagesAxis = QuranAxis.of(catalog, WirdUnit.pages);

    Widget label(String s, {IconData? icon}) => Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.s),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: t.brass), const SizedBox(width: Space.xs)],
          Text(s, style: text.titleSmall),
        ],
      ),
    );

    final preview = _d.isKhatma
        ? '${l.wirdFinishesOn(fmt.formatDate(_d.targetDate!, style: MadarDateStyle.weekdayDayMonth))}${l.wirdSep}'
              '${l.wirdPerDayPreview(texts.amount(WirdUnit.pages, _d.amountPerDay(pagesAxis)))}'
        : l.wirdSummaryDaily(texts.amount(_d.unit, _d.amount));

    return InteractionSheetFrame(
      title: _editing ? l.wirdEditPlanTitle : l.wirdNewPlanTitle,
      subtitle: l.wirdPlanSheetSubtitle,
      icon: Icons.auto_stories_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(l.wirdFieldType),
          ChoicePills<WirdTemplate>.single(
            options: [
              for (final tp in WirdTemplate.values)
                ChoiceOption(value: tp, label: texts.template(tp), icon: wirdTemplateIcon(tp)),
            ],
            selected: _d.template,
            scrollable: true,
            onChanged: (tp) {
              if (tp == null || tp == _d.template) return;
              _update(_d.copyWith(template: tp, amount: defaults[tp] ?? _d.amount), texts);
            },
          ),
          if (_d.isKhatma) ...[
            label(l.wirdFieldDays),
            ChoicePills<int>.single(
              options: [for (final n in khatmaPresets) ChoiceOption(value: n, label: texts.days(n))],
              selected: khatmaPresets.contains(_d.khatmaDays) ? _d.khatmaDays : null,
              onChanged: (n) => n == null ? null : _update(_d.copyWith(khatmaDays: n), texts),
              scrollable: true,
            ),
            const SizedBox(height: Space.s),
            _Stepper(
              value: texts.days(_d.khatmaDays),
              onMinus: _d.khatmaDays > 1 ? () => _update(_d.copyWith(khatmaDays: _d.khatmaDays - 1), texts) : null,
              onPlus: _d.khatmaDays < 1000 ? () => _update(_d.copyWith(khatmaDays: _d.khatmaDays + 1), texts) : null,
            ),
          ] else ...[
            label(l.wirdFieldAmount),
            ChoicePills<double>.single(
              options: [
                for (final a in amountPresets[_d.template]!) ChoiceOption(value: a, label: texts.amount(_d.unit, a)),
              ],
              selected: amountPresets[_d.template]!.contains(_d.amount) ? _d.amount : null,
              onChanged: (a) => a == null ? null : _update(_d.copyWith(amount: a), texts),
              scrollable: true,
            ),
            const SizedBox(height: Space.s),
            _Stepper(
              value: texts.amount(_d.unit, _d.amount),
              onMinus: _d.amount - steps[_d.template]! > 0
                  ? () => _update(_d.copyWith(amount: _d.amount - steps[_d.template]!), texts)
                  : null,
              onPlus: () => _update(_d.copyWith(amount: _d.amount + steps[_d.template]!), texts),
            ),
          ],
          const SizedBox(height: Space.s),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            child: Text(
              preview,
              key: ValueKey(preview),
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: t.accent),
            ),
          ),
          label(l.wirdFieldStart, icon: Icons.flag_rounded),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: PickerButton(
                  icon: Icons.menu_book_rounded,
                  text: '${texts.number(_d.start.surah)}. ${texts.surah(_d.start.surah)}',
                  semanticLabel: l.wirdSurah,
                  onTap: () async {
                    final s = await showSurahPicker(context, catalog: catalog, selected: _d.start.surah);
                    if (s != null) _update(_d.copyWith(start: AyahRef(s, 1)), texts);
                  },
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                flex: 2,
                child: _Stepper(
                  compact: true,
                  value: '${l.wirdAyah} ${texts.number(_d.start.ayah)}',
                  onMinus: _d.start.ayah > 1
                      ? () => _update(_d.copyWith(start: AyahRef(_d.start.surah, _d.start.ayah - 1)), texts)
                      : null,
                  onPlus: _d.start.ayah < catalog.ayahCount(_d.start.surah)
                      ? () => _update(_d.copyWith(start: AyahRef(_d.start.surah, _d.start.ayah + 1)), texts)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(l.wirdStartJuzShortcut, style: text.labelMedium),
          const SizedBox(height: Space.xs),
          ChoicePills<int>.single(
            dense: true,
            scrollable: true,
            options: [for (var j = 1; j <= 30; j++) ChoiceOption(value: j, label: texts.number(j))],
            selected: _juzAt(catalog, _d.start),
            onChanged: (j) => j == null ? null : _update(_d.copyWith(start: catalog.juzStart(j)), texts),
          ),
          label(l.wirdFieldStartDate, icon: Icons.event_rounded),
          ChoicePills<int>.single(
            options: [
              ChoiceOption(value: 0, label: l.wirdStartToday),
              ChoiceOption(value: 1, label: l.wirdStartTomorrow),
              ChoiceOption(
                value: 2,
                label: [0, 1].contains(CalendarDays.between(today, _d.startDate))
                    ? l.wirdFieldCustom
                    : fmt.formatDate(_d.startDate, style: MadarDateStyle.dayMonth),
                icon: Icons.calendar_month_rounded,
              ),
            ],
            selected: switch (CalendarDays.between(today, _d.startDate)) {
              0 => 0,
              1 => 1,
              _ => 2,
            },
            onChanged: (v) async {
              if (v == 0) _update(_d.copyWith(startDate: today), texts);
              if (v == 1) _update(_d.copyWith(startDate: CalendarDays.add(today, 1)), texts);
              if (v == 2) {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _d.startDate,
                  firstDate: CalendarDays.add(today, -365),
                  lastDate: CalendarDays.add(today, 365),
                );
                if (picked != null) _update(_d.copyWith(startDate: CalendarDays.dateOnly(picked)), texts);
              }
            },
          ),
          label(l.wirdFieldWindow, icon: Icons.schedule_rounded),
          ChoicePills<PrayerWindow>.single(
            scrollable: true,
            options: [
              for (final w in PrayerWindow.values) ChoiceOption(value: w, label: texts.window(w), icon: windowIcon(w)),
            ],
            selected: _d.window ?? PrayerWindow.anytime,
            onChanged: (w) => w == null ? null : _update(_d.copyWith(window: w), texts),
          ),
          if (_d.window != null && _d.window != PrayerWindow.anytime) ...[
            const SizedBox(height: Space.m),
            Row(
              children: [
                Icon(Icons.notifications_active_rounded, size: 18, color: t.textSecondary),
                const SizedBox(width: Space.s),
                Expanded(child: Text(l.wirdFieldRemind, style: text.bodyMedium)),
                MadarSwitch(
                  value: _d.remind,
                  semanticLabel: l.wirdFieldRemind,
                  onChanged: (v) => _update(_d.copyWith(remind: v), texts),
                ),
              ],
            ),
            AnimatedReveal(
              visible: _d.remind,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.s),
                child: ChoicePills<int>.single(
                  dense: true,
                  scrollable: true,
                  options: [
                    for (final m in WirdPlanMeta.offsets.where((m) => m > 0))
                      ChoiceOption(value: m, label: l.wirdRemindAfter(fmt.localizeDigits(l.wirdMinutes(m)))),
                  ],
                  selected: _d.remindOffsetMin,
                  onChanged: (m) => m == null ? null : _update(_d.copyWith(remindOffsetMin: m), texts),
                ),
              ),
            ),
          ],
          label(l.wirdFieldCatchUp, icon: Icons.sync_alt_rounded),
          for (final c in WirdCatchUp.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: _OptionCard(
                selected: _d.catchUp == c,
                icon: c == WirdCatchUp.spread ? Icons.waves_rounded : Icons.bolt_rounded,
                title: c == WirdCatchUp.spread ? l.wirdCatchUpSpread : l.wirdCatchUpAll,
                hint: c == WirdCatchUp.spread ? l.wirdCatchUpSpreadHint : l.wirdCatchUpAllHint,
                onTap: () => _update(_d.copyWith(catchUp: c), texts),
              ),
            ),
          label(l.wirdFieldName, icon: Icons.edit_rounded),
          TextField(
            controller: _name,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              _nameEdited = true;
              _nameError = false;
            }),
            decoration: kitInputDecoration(context, error: _nameError, hint: l.wirdNameRequired),
          ),
        ],
      ),
      footer: SheetButton(
        label: _editing ? l.wirdSave : l.wirdCreate,
        primary: true,
        icon: _editing ? Icons.check_rounded : Icons.auto_awesome_rounded,
        sfx: Sfx.complete,
        onPressed: () => _save(texts),
      ),
    );
  }

  int? _juzAt(QuranCatalog c, AyahRef a) {
    final j = c.juzOf(a);
    return c.juzStart(j) == a ? j : null;
  }
}

/// − value + (the − sits on the reading side).
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, this.onMinus, this.onPlus, this.compact = false});

  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = L10n.of(context);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: t.glassFill,
        borderRadius: BorderRadius.circular(t.radiusM),
        border: Border.all(color: t.glassBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: Space.xxs),
      child: Row(
        children: [
          MadarButton.icon(
            icon: Icons.remove_rounded,
            onPressed: onMinus,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.ghost,
            semanticLabel: l.wirdDecrease,
            sfx: Sfx.countTick,
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (compact ? text.labelLarge : text.titleMedium)!.copyWith(color: t.textPrimary),
            ),
          ),
          MadarButton.icon(
            icon: Icons.add_rounded,
            onPressed: onPlus,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.ghost,
            semanticLabel: l.wirdIncrease,
            sfx: Sfx.countTick,
          ),
        ],
      ),
    );
  }
}

/// A selectable option with an explanation (catch-up modes).
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: selected ? null : onTap,
      sfx: Sfx.toggleOn,
      selected: selected,
      semanticLabel: '$title. $hint',
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        decoration: BoxDecoration(
          color: selected ? t.accentSoft : t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: selected ? t.accent : t.glassBorder, width: selected ? 1.4 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: selected ? t.accent : t.textSecondary),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall!.copyWith(color: selected ? t.accent : t.textPrimary)),
                  const SizedBox(height: Space.xxs),
                  Text(hint, style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? t.accent : t.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
