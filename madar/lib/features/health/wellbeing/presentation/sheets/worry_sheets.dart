import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart' show TimeWheel;
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/wellbeing_data.dart';
import '../../domain/wellbeing_settings.dart';
import '../../domain/worry_window.dart';
import '../wellbeing_texts.dart';
import '../widgets/wb_widgets.dart';

/// Reviews the parked worries one by one: resolved, keep for next time, or
/// add a reflection. Logs the review on the Health planet.
Future<void> showWorryReviewSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const WorryReviewSheet());

class WorryReviewSheet extends ConsumerStatefulWidget {
  const WorryReviewSheet({super.key});

  @override
  ConsumerState<WorryReviewSheet> createState() => _WorryReviewSheetState();
}

class _WorryReviewSheetState extends ConsumerState<WorryReviewSheet> {
  late final List<WorryRow> _queue = List.of(ref.read(parkedWorriesProvider));
  final TextEditingController _reflection = TextEditingController();
  int _index = 0;
  int _resolved = 0;
  bool _reflecting = false;
  bool _logged = false;

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  bool get _done => _index >= _queue.length;

  Future<void> _answer({required bool resolved}) async {
    final w = _queue[_index];
    final service = ref.read(wellbeingServiceProvider);
    final note = _reflection.text;
    if (resolved) {
      await service.resolveWorry(w.id, reflection: note);
      _resolved++;
      Fx.fire(Sfx.complete);
    } else {
      await service.keepWorry(w.id, reflection: note);
      Fx.fire(Sfx.drop);
    }
    _reflection.clear();
    setState(() {
      _index++;
      _reflecting = false;
    });
    if (_done && !_logged) {
      _logged = true;
      await service.logWorryReview(reviewed: _queue.length, resolved: _resolved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final total = _queue.length;
    Widget body;
    Widget? footer;
    if (total == 0) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.l),
        child: WbHint(l.wbWorryReviewEmpty),
      );
      footer = SheetButton(label: l.wbClose, primary: true, onPressed: () => Navigator.of(context).maybePop());
    } else if (_done) {
      body = Column(
        children: [
          const SizedBox(height: Space.l),
          ProgressRing(
            value: 1,
            size: 88,
            color: t.success,
            child: Icon(Icons.check_rounded, color: t.success, size: 36),
          ),
          const SizedBox(height: Space.l),
          Text(l.wbWorryReviewDoneTitle, style: text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: Space.s),
          Text(
            fmt.localizeDigits(l.wbWorryReviewDoneBody(total, fmt.formatInt(total), fmt.formatInt(_resolved))),
            style: text.bodyMedium?.copyWith(color: t.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.l),
        ],
      );
      footer = SheetButton(label: l.wbClose, primary: true, onPressed: () => Navigator.of(context).maybePop());
    } else {
      final w = _queue[_index];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fmt.localizeDigits(l.wbWorryReviewProgress(fmt.formatInt(_index + 1), fmt.formatInt(total))),
                  style: text.labelLarge?.copyWith(color: t.textSecondary),
                ),
              ),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_index + 1) / total),
                    duration: context.motion(MadarMotion.medium),
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 5,
                      color: t.gold,
                      backgroundColor: t.glassBorder.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.medium),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(
                  begin: Offset(Directionality.of(context) == TextDirection.rtl ? -0.12 : 0.12, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: a, curve: MadarMotion.decelerate)),
                child: child,
              ),
            ),
            layoutBuilder: (current, previous) =>
                Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
            child: GlassCard(
              key: ValueKey(w.id),
              width: double.infinity,
              padding: const EdgeInsets.all(Space.l),
              borderRadius: BorderRadius.circular(t.radiusL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded, color: t.gold.withValues(alpha: 0.7)),
                  const SizedBox(height: Space.xs),
                  Text(w.body, style: text.titleMedium?.copyWith(height: 1.55)),
                  const SizedBox(height: Space.s),
                  Text(
                    l.wbWorryParkedOn(
                      WbTexts.of(context).relativeDay(WbDays.dateOf(w.createdAt), ref.read(wellbeingTodayProvider)),
                    ),
                    style: text.labelSmall?.copyWith(color: t.textTertiary),
                  ),
                  if (w.reflection != null) ...[
                    const SizedBox(height: Space.s),
                    Text(
                      l.wbWorryEarlierReflection(w.reflection!),
                      style: text.bodySmall?.copyWith(color: t.textSecondary, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          Text(l.wbWorryReviewQuestion, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
          const SizedBox(height: Space.s),
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            alignment: AlignmentDirectional.topStart,
            child: _reflecting
                ? TextField(
                    controller: _reflection,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: l.wbWorryReflection, hintText: l.wbWorryReflectionHint),
                  )
                : Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: MadarButton(
                      label: l.wbWorryAddReflection,
                      icon: Icons.edit_note_rounded,
                      variant: MadarButtonVariant.ghost,
                      size: MadarButtonSize.small,
                      onPressed: () => setState(() => _reflecting = true),
                    ),
                  ),
          ),
        ],
      );
      footer = Row(
        children: [
          Expanded(
            child: SheetButton(
              label: l.wbWorryKeep,
              icon: Icons.inventory_2_outlined,
              sfx: null,
              onPressed: () => _answer(resolved: false),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: SheetButton(
              label: l.wbWorryResolved,
              icon: Icons.check_circle_outline_rounded,
              primary: true,
              sfx: null,
              onPressed: () => _answer(resolved: true),
            ),
          ),
        ],
      );
    }
    return InteractionSheetFrame(
      title: l.wbWorryReviewTitle,
      subtitle: l.wbWorryReviewSubtitle,
      icon: Icons.hourglass_bottom_rounded,
      footer: footer,
      body: body,
    );
  }
}

/// Sets the daily worry window: on/off, start time, length, reminder.
Future<void> showWorryWindowSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const WorryWindowSheet());

class WorryWindowSheet extends ConsumerStatefulWidget {
  const WorryWindowSheet({super.key});

  @override
  ConsumerState<WorryWindowSheet> createState() => _WorryWindowSheetState();
}

class _WorryWindowSheetState extends ConsumerState<WorryWindowSheet> {
  late WorryWindowSettings _s = () {
    final current = (ref.read(wellbeingSettingsProvider).value ?? const WellbeingSettings()).worry;
    // Opening the sheet to set a window means "on".
    return current.enabled ? current : current.copyWith(enabled: true);
  }();

  Future<void> _save() async {
    await ref.read(wellbeingServiceProvider).updateSettings((s) => s.copyWith(worry: _s));
    Fx.fire(Sfx.complete);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    return InteractionSheetFrame(
      title: l.wbWorryWindowTitle,
      subtitle: l.wbWorryWindowExplain,
      icon: Icons.hourglass_empty_rounded,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(label: l.wbCancel, onPressed: () => Navigator.of(context).maybePop()),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            flex: 2,
            child: SheetButton(label: l.wbSave, primary: true, icon: Icons.check_rounded, sfx: null, onPressed: _save),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwitchRow(
            label: l.wbWorryWindowEnabled,
            value: _s.enabled,
            onChanged: (v) => setState(() => _s = _s.copyWith(enabled: v)),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            alignment: AlignmentDirectional.topStart,
            child: !_s.enabled
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: Space.m),
                      Text(l.wbWorryWindowStart, style: text.titleSmall),
                      const SizedBox(height: Space.s),
                      TimeWheel(
                        value: _s.hhmm,
                        minuteStep: 5,
                        onChanged: (v) {
                          final m = WorryWindowSettings.parseHhmm(v);
                          if (m != null) setState(() => _s = _s.copyWith(minuteOfDay: m));
                        },
                      ),
                      const SizedBox(height: Space.l),
                      Text(l.wbWorryWindowLength, style: text.titleSmall),
                      const SizedBox(height: Space.s),
                      ChoicePills<int>.single(
                        options: [
                          for (final d in WorryWindowSettings.durations)
                            ChoiceOption(value: d, label: fmt.localizeDigits(l.wbMinutes(d, fmt.formatInt(d)))),
                        ],
                        selected: _s.durationMinutes,
                        onChanged: (v) {
                          if (v != null) setState(() => _s = _s.copyWith(durationMinutes: v));
                        },
                      ),
                      const SizedBox(height: Space.m),
                      _SwitchRow(
                        label: l.wbWorryWindowRemind,
                        hint: l.wbWorryWindowRemindHint,
                        value: _s.remind,
                        onChanged: (v) => setState(() => _s = _s.copyWith(remind: v)),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: Space.m),
          WbHint(l.wbWorryWindowAbout, icon: Icons.info_outline_rounded),
          SizedBox(height: t.radiusS),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged, this.hint});

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.titleSmall),
              if (hint != null) Text(hint!, style: text.bodySmall?.copyWith(color: t.textSecondary)),
            ],
          ),
        ),
        MadarSwitch(value: value, onChanged: onChanged, semanticLabel: label),
      ],
    );
  }
}

/// Wellbeing settings: the support number (other countries), breathing
/// sound and the worry window.
Future<void> showWellbeingSettingsSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const WellbeingSettingsSheet());

class WellbeingSettingsSheet extends ConsumerStatefulWidget {
  const WellbeingSettingsSheet({super.key});

  @override
  ConsumerState<WellbeingSettingsSheet> createState() => _WellbeingSettingsSheetState();
}

class _WellbeingSettingsSheetState extends ConsumerState<WellbeingSettingsSheet> {
  late WellbeingSettings _s = ref.read(wellbeingSettingsProvider).value ?? const WellbeingSettings();
  late final TextEditingController _number = TextEditingController(text: _s.supportNumber);

  @override
  void initState() {
    super.initState();
    _number.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  bool get _valid => WellbeingSettings.normalizeNumber(_number.text) != null;

  Future<void> _save() async {
    if (!_valid) {
      Fx.fire(Sfx.error);
      return;
    }
    final next = _s.copyWith(supportNumber: _number.text.trim());
    await ref.read(wellbeingServiceProvider).updateSettings((s) => next.copyWith(worry: s.worry));
    Fx.fire(Sfx.complete);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final worry = (ref.watch(wellbeingSettingsProvider).value ?? _s).worry;
    return InteractionSheetFrame(
      title: l.wbSettingsTitle,
      icon: Icons.tune_rounded,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(label: l.wbCancel, onPressed: () => Navigator.of(context).maybePop()),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            flex: 2,
            child: SheetButton(
              label: l.wbSave,
              primary: true,
              icon: Icons.check_rounded,
              sfx: null,
              enabled: _valid,
              onDisabledTap: () => Fx.fire(Sfx.error),
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.wbSettingsSupportNumber, style: text.titleSmall),
          const SizedBox(height: Space.xs),
          Text(
            l.wbSettingsSupportNumberHint(BidiIsolate.ltr(fmt.localizeDigits(WellbeingSettings.defaultSupportNumber))),
            style: text.bodySmall?.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _number,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.call_outlined),
                    errorText: _valid ? null : l.wbSettingsNumberInvalid,
                  ),
                ),
              ),
              const SizedBox(width: Space.s),
              MadarButton(
                label: fmt.localizeDigits(WellbeingSettings.defaultSupportNumber),
                icon: Icons.restart_alt_rounded,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                semanticLabel: l.wbSettingsResetNumber(fmt.localizeDigits(WellbeingSettings.defaultSupportNumber)),
                onPressed: () => _number.text = WellbeingSettings.defaultSupportNumber,
              ),
            ],
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          _SwitchRow(
            label: l.wbSettingsBreathingSound,
            hint: l.wbSettingsBreathingSoundHint,
            value: _s.breathingSound,
            onChanged: (v) => setState(() => _s = _s.copyWith(breathingSound: v)),
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          GlassCard(
            padding: const EdgeInsets.all(Space.m),
            onTap: () => showWorryWindowSheet(context),
            semanticLabel: l.wbWorryWindowTitle,
            child: Row(
              children: [
                Icon(Icons.hourglass_empty_rounded, color: t.gold, size: 20),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.wbWorryWindowTitle, style: text.titleSmall),
                      Text(
                        worry.enabled
                            ? fmt.localizeDigits(
                                l.wbWorryWindowSummary(
                                  fmt.formatClock(worry.hour, worry.minute),
                                  l.wbMinutes(worry.durationMinutes, fmt.formatInt(worry.durationMinutes)),
                                ),
                              )
                            : l.wbWorryWindowOff,
                        style: text.bodySmall?.copyWith(color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(wbForwardChevron(context), color: t.textTertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
