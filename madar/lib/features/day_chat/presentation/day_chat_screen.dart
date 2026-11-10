import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/day_chat_providers.dart';
import '../domain/day_chat_journal.dart';
import '../domain/day_chat_piece.dart';
import 'day_chat_actions.dart';
import 'day_chat_texts.dart';
import 'widgets/day_chat_bubble.dart';
import 'widgets/day_chat_composer.dart';
import 'widgets/day_chat_piece_card.dart';
import 'widgets/day_summary_view.dart';

/// The two halves of the day.
enum DayChatTab {
  /// What he typed, and a card per thing it was read into.
  chat,

  /// «شو صار اليوم؟» – his day read back out of his own data.
  summary,
}

/// The daily chat: he types his day in one line, and every piece Madar read
/// comes back as its own card under his own words – carrying what it would
/// write, **where it would land**, and the exact stretch of his sentence it
/// came from, underlined in his bubble.
///
/// The three rules of this screen:
///
/// * **nothing is written without his tap on that one piece.** There is one
///   «سجّلها» per card and no "file everything" in any wording – the same
///   promise Part 3's plan review makes, on purpose;
/// * **nothing leaves the phone.** Reading, filing and «شو صار اليوم؟» are
///   all offline. The only door out is the «اسأل الذكاء» tap on a sentence
///   it could not read, which opens Part 3's export sheet with that one
///   sentence as his question – and even there he is the one who shares it;
/// * **it is still here tomorrow.** His lines are stored; the pieces are
///   read again from his own words (same ids), so the decision he made on
///   each card survives a restart.
class DayChatScreen extends ConsumerStatefulWidget {
  const DayChatScreen({
    super.key,
    this.day,
    this.initialTab = DayChatTab.chat,
    this.initialDraft,
    this.animateBackdrop = true,
    this.onOpenRecord,
    this.onOpenDay,
  });

  /// The day to show (null: the prayer day he is in now).
  final DateTime? day;
  final DayChatTab initialTab;

  /// Text already in the box – **never sent**: he still taps «ابعت».
  final String? initialDraft;
  final bool animateBackdrop;

  /// Opens the record a filed card created (`refTable` / `refId`).
  final void Function(String refTable, String refId)? onOpenRecord;

  /// Opens another day of the chat (the router replaces this page).
  final ValueChanged<DateTime>? onOpenDay;

  @override
  ConsumerState<DayChatScreen> createState() => _DayChatScreenState();
}

class _DayChatScreenState extends ConsumerState<DayChatScreen> {
  late DayChatTab _tab = widget.initialTab;

  /// What he settled on a card before filing it, by piece id. It lives on
  /// the screen only: an edit writes nothing until he taps «سجّلها».
  final Map<String, DayChatPiece> _edits = {};

  /// The card whose words are lit in the bubble above it.
  String? _focused;

  final ScrollController _scroll = ScrollController();

  /// Height the undo toast keeps clear above the box he types into – the
  /// same courtesy home's quick-add bar gets, for the same reason: an undo
  /// that covers the input is an undo he cannot use and a line he cannot
  /// send.
  static const double composerClearance = 84;

  @override
  void initState() {
    super.initState();
    UndoToast.bottomInset = composerClearance;
  }

  @override
  void dispose() {
    if (UndoToast.bottomInset == composerClearance) UndoToast.bottomInset = 0;
    _scroll.dispose();
    super.dispose();
  }

  DateTime get _day => widget.day ?? ref.read(dayChatTodayProvider);

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final day = _day;

    return MadarScaffold(
      title: l.dayChatTitle,
      backdropSeed: 7.1,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          key: const ValueKey('dayChat.days'),
          icon: Icons.calendar_month_rounded,
          semanticLabel: l.dayChatDaysAction,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => unawaited(_pickDay(context)),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            // A Wrap, not a Row: at text scale 1.3 (and in English) the two
            // labels no longer fit on one line, and a clipped tab is worse
            // than a second row.
            child: Wrap(
              spacing: Space.s,
              runSpacing: Space.xs,
              children: [
                for (final tab in DayChatTab.values)
                  MadarChip(
                    key: ValueKey('dayChat.tab.${tab.name}'),
                    label: tab == DayChatTab.chat ? l.dayChatTabChat : l.dayChatTabSummary,
                    icon: tab == DayChatTab.chat ? Icons.forum_rounded : Icons.wb_twilight_rounded,
                    selected: _tab == tab,
                    onSelected: (_) {
                      if (_tab != tab) setState(() => _tab = tab);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: MadarFadeStack(
              index: _tab.index,
              children: [
                _ChatView(
                  key: const ValueKey('dayChat.chat'),
                  day: day,
                  scroll: _scroll,
                  edits: _edits,
                  focused: _focused,
                  initialDraft: widget.initialDraft,
                  onFocus: (id) => setState(() => _focused = _focused == id ? null : id),
                  onEdited: (id, piece) => setState(() {
                    if (piece == null) {
                      _edits.remove(id);
                    } else {
                      _edits[id] = piece;
                    }
                  }),
                  onOpenRecord: widget.onOpenRecord,
                ),
                DaySummaryView(key: const ValueKey('dayChat.summaryView'), day: day),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The days that already have a chat, newest first – so yesterday is one
  /// tap away and nothing is lost behind "today".
  Future<void> _pickDay(BuildContext context) async {
    final l = L10n.of(context);
    final fmt = context.formatter;
    final today = ref.read(dayChatTodayProvider);
    final days = ref.read(dayChatDaysProvider).value ?? const <DateTime>[];
    final all = [
      if (!days.any((d) => _sameDay(d, today))) today,
      ...days,
    ];
    final values = await showEditSheet(
      context,
      title: l.dayChatDaysTitle,
      icon: Icons.calendar_month_rounded,
      fields: [
        FieldSpec.singleSelect(
          'day',
          l.dayChatDaysTitle,
          required: true,
          options: [
            for (final d in all)
              SelectOption(
                id: DayChatDay.keyOf(d),
                label: _sameDay(d, today) ? l.dayChatTodayLabel : fmt.formatDate(d, style: MadarDateStyle.medium),
                icon: Icons.event_rounded,
              ),
          ],
          icon: Icons.event_rounded,
        ),
      ],
      initial: {'day': DayChatDay.keyOf(_day)},
    );
    final key = values?['day'] as String?;
    final picked = key == null ? null : DayChatDay.dayOfKey(key);
    if (picked == null || !context.mounted || _sameDay(picked, _day)) return;
    widget.onOpenDay?.call(picked);
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

/// His lines, their cards, and the box he types into.
class _ChatView extends ConsumerWidget {
  const _ChatView({
    super.key,
    required this.day,
    required this.scroll,
    required this.edits,
    required this.focused,
    required this.onFocus,
    required this.onEdited,
    this.initialDraft,
    this.onOpenRecord,
  });

  final DateTime day;
  final ScrollController scroll;
  final Map<String, DayChatPiece> edits;
  final String? focused;
  final ValueChanged<String> onFocus;
  final void Function(String id, DayChatPiece? piece) onEdited;
  final String? initialDraft;
  final void Function(String refTable, String refId)? onOpenRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final readings = ref.watch(dayChatReadingsProvider(day));
    final stored = ref.watch(dayChatDayProvider(day)).value;
    final lines = ref.watch(dayChatLinesProvider(day)).value ?? const <DayChatLine>[];
    // While a new line is being read the previous reading is still there,
    // so the chat never blanks out under him; only the very first read of
    // a day shows the loader.
    final list = readings.value;

    final body = list == null
        ? const Center(child: OrbitLoader())
        : list.isEmpty
        ? const _Invitation(key: ValueKey('dayChat.empty'))
        : _Lines(
            key: const ValueKey('dayChat.lines'),
            day: day,
            scroll: scroll,
            readings: list,
            lines: lines,
            stored: stored,
            edits: edits,
            focused: focused,
            onFocus: onFocus,
            onEdited: onEdited,
            onOpenRecord: onOpenRecord,
          );

    return Column(
      children: [
        Expanded(child: body),
        if (readings.isLoading && lines.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
            child: Semantics(
              liveRegion: true,
              child: Text(
                l.dayChatReadingLine,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textTertiary),
              ),
            ),
          ),
        DayChatComposer(day: day, initialText: initialDraft, scroll: scroll),
      ],
    );
  }
}

/// The chat itself: his line, then one card per piece under it, oldest
/// first – the way a conversation reads.
class _Lines extends ConsumerWidget {
  const _Lines({
    super.key,
    required this.day,
    required this.scroll,
    required this.readings,
    required this.lines,
    required this.stored,
    required this.edits,
    required this.focused,
    required this.onFocus,
    required this.onEdited,
    this.onOpenRecord,
  });

  final DateTime day;
  final ScrollController scroll;
  final List<DayChatReading> readings;
  final List<DayChatLine> lines;
  final DayChatDay? stored;
  final Map<String, DayChatPiece> edits;
  final String? focused;
  final ValueChanged<String> onFocus;
  final void Function(String id, DayChatPiece? piece) onEdited;
  final void Function(String refTable, String refId)? onOpenRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final children = <Widget>[];

    for (var i = 0; i < readings.length; i++) {
      final reading = readings[i];
      final line = i < lines.length ? lines[i] : null;
      // His own words, with every piece's stretch underlined inside them.
      final shown = [
        for (final p in reading.pieces) edits[p.id] ?? p,
      ];
      children
        ..add(
          DayChatBubble(
            key: ValueKey('dayChat.bubble.${line?.id ?? i}'),
            raw: reading.raw,
            pieces: shown,
            focusedPieceId: focused,
            at: line?.at,
          ),
        )
        ..add(const SizedBox(height: Space.m));

      if (reading.pieces.isEmpty) {
        children
          ..add(
            Text(
              l.dayChatNothingRead,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
            ),
          )
          ..add(const SizedBox(height: Space.m));
        continue;
      }

      for (final original in reading.pieces) {
        final piece = edits[original.id] ?? original;
        final decision = stored?.decision(original.id);
        children
          ..add(
            DayChatPieceCard(
              key: ValueKey('dayChat.card.${original.id}'),
              piece: piece,
              state: decision?.state ?? DayChatState.pending,
              edited: edits.containsKey(original.id) || (decision?.edited ?? false),
              focused: focused == original.id,
              onTap: () => onFocus(original.id),
              onFile: () => unawaited(_file(context, ref, piece, original.id)),
              onEdit: () => unawaited(_edit(context, ref, piece, original.id)),
              onReject: () => unawaited(DayChatActions.reject(context, ref, piece, day: day)),
              onKeepAsNote: piece.kind == DayChatKind.unread
                  ? () => unawaited(_note(context, ref, piece, original.id))
                  : null,
              onReword: piece.kind == DayChatKind.unread
                  ? () => unawaited(DayChatActions.reword(context, ref, piece, day: day))
                  : null,
              onAskAi: piece.kind == DayChatKind.unread
                  ? () => unawaited(DayChatActions.askAi(context, piece))
                  : null,
              onMakeTracker: piece.kind == DayChatKind.sign
                  ? () => unawaited(_tracker(context, ref, piece, original.id))
                  : null,
              onOpenRecord: _opener(decision),
            ),
          )
          ..add(const SizedBox(height: Space.m));
      }
    }

    return EntranceChoreo(
      id: ('dayChat', day, readings.length),
      child: ListView.builder(
        key: const ValueKey('dayChat.list'),
        controller: scroll,
        // Room under the last card for the undo toasts that rise over the
        // box he types into: without it the newest card – the one he is
        // most likely to be deciding – sits under them and cannot be
        // tapped at all.
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 140),
        itemCount: children.length,
        itemBuilder: (context, i) => children[i],
      ),
    );
  }

  /// Where a filed card's own record lives, when there is a screen for it.
  VoidCallback? _opener(DayChatDecision? decision) {
    final open = onOpenRecord;
    final table = decision?.refTable;
    final id = decision?.refId;
    if (open == null || decision == null || !decision.isApplied || table == null || id == null) return null;
    return () => open(table, id);
  }

  Future<void> _file(BuildContext context, WidgetRef ref, DayChatPiece piece, String id) async {
    final filed = await DayChatActions.file(context, ref, piece, day: day);
    // Stored now: the screen stops carrying his edit.
    if (filed == DayChatFiled.written || filed == DayChatFiled.alreadyThere) onEdited(id, null);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, DayChatPiece piece, String id) async {
    final before = edits[id];
    final edited = await DayChatActions.edit(context, ref, piece);
    if (edited == null) return;
    onEdited(id, edited);
    if (!context.mounted) return;
    // An edit writes nothing of his, so its undo is simply the card as it
    // was before.
    unawaited(
      showUndoToast(
        context,
        UndoableAction(
          label: L10n.of(context).dayChatEditedToast(DayChatTexts.of(context).title(edited)),
          undo: () async => onEdited(id, before),
        ),
      ),
    );
  }

  Future<void> _note(BuildContext context, WidgetRef ref, DayChatPiece piece, String id) async {
    final filed = await DayChatActions.keepAsNote(context, ref, piece, day: day);
    if (filed == DayChatFiled.written) onEdited(id, null);
  }

  Future<void> _tracker(BuildContext context, WidgetRef ref, DayChatPiece piece, String id) async {
    final filed = await DayChatActions.makeTracker(context, ref, piece, day: day);
    if (filed == DayChatFiled.written) onEdited(id, null);
  }
}

/// A fresh install's chat: a warm invitation and nothing else. No sample
/// conversation, no made-up day – there is nothing of his here yet.
class _Invitation extends StatelessWidget {
  const _Invitation({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(Space.gutter),
              child: AnimatedEmptyState(
                kind: EmptyStateKind.emptyList,
                title: l.dayChatEmptyTitle,
                body: l.dayChatEmptyBody,
                illustrationSize: box.maxHeight < 320 ? 72 : 104,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
