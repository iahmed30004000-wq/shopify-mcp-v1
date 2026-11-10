import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show InlineDatePicker, PickerButton, kitInputDecoration;
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/record_providers.dart' show LabTestView;
import '../data/record_service.dart' show LabVisitEntry;
import '../domain/lab_flags.dart';
import '../domain/lab_series.dart';
import 'record_ui.dart';
import 'widgets/lab_bits.dart';

/// A lab visit: one date, a result field per test (grouped by category),
/// each with a live neutral flag preview. Returns the date and the filled
/// entries, or null when dismissed.
Future<({DateTime date, List<LabVisitEntry> entries})?> showLabVisitSheet(
  BuildContext context, {
  required List<LabTestView> tests,
  required DateTime today,
}) {
  return showInteractionSheet<({DateTime date, List<LabVisitEntry> entries})>(
    context,
    builder: (_) => LabVisitSheet(tests: tests, today: today),
  );
}

class LabVisitSheet extends StatefulWidget {
  const LabVisitSheet({super.key, required this.tests, required this.today});

  final List<LabTestView> tests;
  final DateTime today;

  @override
  State<LabVisitSheet> createState() => _LabVisitSheetState();
}

class _LabVisitSheetState extends State<LabVisitSheet> {
  late DateTime _date = widget.today;
  bool _pickingDate = false;
  final Map<String, TextEditingController> _controllers = {};

  TextEditingController _controller(String id) => _controllers[id] ??= TextEditingController()..addListener(_changed);

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<LabVisitEntry> get _entries => [
    for (final v in widget.tests)
      if (LabValueInput.parse(_controllers[v.test.id]?.text) case final input when !input.isEmpty)
        (testId: v.test.id, input: input, note: null),
  ];

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final count = _entries.length;

    // Categories in first-seen order; uncategorised last.
    final groups = <String?, List<LabTestView>>{};
    for (final v in widget.tests) {
      final c = v.test.category?.trim();
      (groups[c == null || c.isEmpty ? null : c] ??= []).add(v);
    }
    final keys = [...groups.keys.whereType<String>(), if (groups.containsKey(null)) null];

    return InteractionSheetFrame(
      title: l.recordLabVisit,
      subtitle: l.recordLabVisitSubtitle,
      icon: RecordIcons.visit,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerButton(
            icon: Icons.event_outlined,
            text: fmt.formatDate(_date, style: MadarDateStyle.weekdayDayMonth),
            active: _pickingDate,
            semanticLabel: l.recordLabVisitDate,
            onTap: () => setState(() => _pickingDate = !_pickingDate),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.medium),
            curve: MadarMotion.standard,
            alignment: AlignmentDirectional.topStart,
            child: _pickingDate
                ? Padding(
                    padding: const EdgeInsets.only(top: Space.s),
                    child: InlineDatePicker(
                      value: _date,
                      allowClear: false,
                      lastDate: widget.today,
                      now: widget.today,
                      onChanged: (d) => setState(() {
                        if (d != null) _date = d;
                        _pickingDate = false;
                      }),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          for (final k in keys) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.xs),
              child: Text(k ?? l.recordLabUncategorized, style: text.titleSmall!.copyWith(color: t.accent)),
            ),
            for (final v in groups[k]!) _VisitRow(view: v, controller: _controller(v.test.id)),
          ],
        ],
      ),
      footer: SheetButton(
        label: count == 0 ? l.recordLabVisitSaveNone : l.recordLabVisitSave(count, fmt.formatInt(count)),
        primary: true,
        enabled: count > 0,
        icon: Icons.check_rounded,
        sfx: Sfx.complete,
        onPressed: () => Navigator.of(context).pop((date: _date, entries: _entries)),
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.view, required this.controller});

  final LabTestView view;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final texts = context.recordTexts;
    final test = view.test;
    final input = LabValueInput.parse(controller.text);
    final flag = input.value == null ? null : LabFlags.classify(input.value, view.range, margin: view.margin);
    final range = texts.range(view.range, decimals: view.decimals);
    final numeric = !view.range.isEmpty || view.points.any((p) => p.isNumeric) || view.points.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  test.name,
                  style: text.titleSmall!.copyWith(color: t.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: context.motion(MadarMotion.short),
                  child: flag != null
                      ? Align(
                          key: ValueKey(flag),
                          alignment: AlignmentDirectional.centerStart,
                          child: LabFlagChip(flag: flag, dense: true),
                        )
                      : Text(
                          range ?? texts.l.recordLabNoRange,
                          key: const ValueKey('range'),
                          style: text.bodySmall!.copyWith(color: t.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          SizedBox(
            width: 132,
            child: TextField(
              controller: controller,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                  : TextInputType.text,
              textInputAction: TextInputAction.next,
              textAlign: TextAlign.center,
              style: text.titleMedium!.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              decoration: kitInputDecoration(context, hint: '—', suffix: test.unit),
            ),
          ),
        ],
      ),
    );
  }
}
