import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/work_models.dart';
import '../data/work_providers.dart';
import '../domain/card_filter.dart';
import '../domain/top3.dart';
import 'widgets/work_widgets.dart';
import 'work_labels.dart';

/// Opens the card editor for a new card on [board] (in [columnId]) or for
/// [card]; returns the edited draft (null when dismissed). Saving is the
/// caller's (see `WorkActions.newCard` / `WorkActions.editCard`).
Future<CardDraft?> showCardSheet(
  BuildContext context, {
  required WorkBoard board,
  BoardCardRow? card,
  String? columnId,
  DateTime? windowDay,
}) => showInteractionSheet<CardDraft>(
  context,
  builder: (_) => CardSheet(board: board, card: card, columnId: columnId, windowDay: windowDay),
);

/// Card editor: title, notes, assignee (free text with suggestions from
/// past assignees), due date, column, prayer-window placement (and its day)
/// and the Top 3 flag.
class CardSheet extends ConsumerStatefulWidget {
  const CardSheet({super.key, required this.board, this.card, this.columnId, this.windowDay});

  final WorkBoard board;
  final BoardCardRow? card;
  final String? columnId;

  /// Day of the card's current placement (its task's day).
  final DateTime? windowDay;

  @override
  ConsumerState<CardSheet> createState() => _CardSheetState();
}

class _CardSheetState extends ConsumerState<CardSheet> {
  late final BoardCardRow? _card = widget.card;
  late final TextEditingController _title = TextEditingController(text: _card?.title ?? '');
  late final TextEditingController _notes = TextEditingController(text: _card?.notes ?? '');
  late final TextEditingController _assignee = TextEditingController(text: _card?.assignee ?? '');
  late DateTime? _due = _card?.dueDate;
  late String _column = _card == null
      ? (widget.columnId ?? widget.board.columns.first.id)
      : widget.board.columnOf(_card);
  late PrayerWindow? _window = _card?.window;
  late DateTime? _windowDay = widget.windowDay;
  late bool _top3 = _card?.isTop3 ?? false;
  bool _tried = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _assignee.dispose();
    super.dispose();
  }

  void _save(DateTime today) {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _tried = true);
      Fx.fire(Sfx.error);
      return;
    }
    Navigator.of(context).pop(
      CardDraft(
        title: title,
        notes: _notes.text,
        assignee: _assignee.text,
        dueDate: _due,
        columnId: _column,
        window: _window,
        windowDay: _window == null ? null : (_windowDay ?? today),
        isTop3: _top3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final today = ref.watch(workTodayProvider);
    final uses = ref.watch(workAssigneeUsesProvider).value ?? const <AssigneeUse>[];
    final suggestions = AssigneeSuggestions.rank(uses, query: _assignee.text, now: ref.read(workClockProvider)());
    final top3 = ref.watch(workTop3Provider).value;
    final alreadyIn = _card != null && _card.isTop3;
    final full = top3 != null && top3.items.length >= Top3Rules.max && !alreadyIn;
    final editing = _card != null;
    final titleError = _tried && _title.text.trim().isEmpty;

    return InteractionSheetFrame(
      title: editing ? l.workEditCard : l.workNewCard,
      subtitle: texts.name(widget.board.name),
      icon: Icons.sticky_note_2_rounded,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(label: l.actionCancel, onPressed: () => Navigator.of(context).maybePop(), sfx: Sfx.sheetClose),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            flex: 2,
            child: SheetButton(
              label: editing ? l.workSave : l.workCreate,
              primary: true,
              icon: Icons.check_rounded,
              onPressed: () => _save(today),
              sfx: Sfx.complete,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetSectionLabel(l.workCardTitle, icon: Icons.title_rounded),
          TextField(
            controller: _title,
            autofocus: !editing,
            maxLength: 140,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: kitInputDecoration(context, hint: l.workCardTitleHint, error: titleError),
          ),
          if (titleError)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.xs, start: Space.xs),
              child: Text(l.fieldRequired, style: text.labelSmall!.copyWith(color: t.danger)),
            ),
          SheetSectionLabel(l.workCardAssignee, icon: Icons.person_rounded),
          TextField(
            controller: _assignee,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: kitInputDecoration(
              context,
              hint: l.workCardAssigneeHint,
              suffixIcon: _assignee.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.workClear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        Fx.fire(Sfx.tap);
                        setState(_assignee.clear);
                      },
                    ),
            ),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            alignment: AlignmentDirectional.topStart,
            child: suggestions.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.only(top: Space.s),
                    child: Wrap(
                      spacing: Space.s,
                      runSpacing: Space.s,
                      children: [
                        for (final s in suggestions.take(6))
                          MadarChip(
                            label: s,
                            icon: Icons.person_outline_rounded,
                            dense: true,
                            onSelected: (_) => setState(() {
                              _assignee.text = s;
                              _assignee.selection = TextSelection.collapsed(offset: s.length);
                            }),
                          ),
                      ],
                    ),
                  ),
          ),
          SheetSectionLabel(l.workCardDue, icon: Icons.event_rounded),
          DayChoice(value: _due, today: today, onChanged: (d) => setState(() => _due = d)),
          if (widget.board.columns.length > 1) ...[
            SheetSectionLabel(l.workCardColumn, icon: Icons.view_column_rounded),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final c in widget.board.columns)
                  MadarChip(
                    label: texts.column(c),
                    icon: c.isDone ? Icons.check_circle_outline_rounded : null,
                    selected: _column == c.id,
                    dense: true,
                    onSelected: (_) => setState(() => _column = c.id),
                  ),
              ],
            ),
          ],
          SheetSectionLabel(l.workCardWindow, icon: Icons.mosque_rounded),
          WindowChoice(value: _window, onChanged: (w) => setState(() => _window = w)),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            alignment: AlignmentDirectional.topStart,
            child: _window == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.only(top: Space.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DayChoice(
                          value: _windowDay ?? today,
                          today: today,
                          allowNone: false,
                          onChanged: (d) => setState(() => _windowDay = d),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(l.workCardWindowHint, style: text.labelSmall),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: Space.l),
          GlassCard(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.m, Space.s),
            child: Row(
              children: [
                IslamicStar(size: 18, color: _top3 ? t.gold : t.textTertiary, glow: _top3),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.workTop3Toggle, style: text.titleSmall),
                      if (full && !_top3) Text(l.workTop3FullShort, style: text.labelSmall!.copyWith(color: t.warning)),
                    ],
                  ),
                ),
                MadarSwitch(
                  value: _top3,
                  activeColor: t.gold,
                  semanticLabel: l.workTop3Toggle,
                  onChanged: full && !_top3
                      ? null
                      : (v) => setState(() => _top3 = v),
                ),
              ],
            ),
          ),
          SheetSectionLabel(l.workCardNotes, icon: Icons.notes_rounded),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 6,
            maxLength: 2000,
            decoration: kitInputDecoration(context),
          ),
        ],
      ),
    );
  }
}
