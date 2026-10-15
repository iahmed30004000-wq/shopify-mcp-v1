import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../ai_bridge/ai_bridge.dart' show PlanLabel, PlanLines, PlanPill;
import '../../domain/day_chat_journal.dart';
import '../../domain/day_chat_piece.dart';
import '../day_chat_texts.dart';

/// One thing the chat read out of his line, as he decides about it: what it
/// would write, **where it would land**, the words of his own sentence it
/// came from, how sure the reader is, what is still missing – and the three
/// taps that are his.
///
/// It is on purpose the twin of Part 3's `PlanItemCard`, which he already
/// knows: one card, one decision, no "file everything" in any wording, and
/// the engine's verdict decides which buttons exist at all:
///
/// * a piece it can write → **سجّلها** (plus عدّلها and لأ);
/// * a piece that still needs him ([DayChatPiece.needsHim]) → no «سجّلها»
///   anywhere, the gaps as sentences he can act on, and the one tap that
///   fixes each;
/// * a sentence it could not read → «ما فهمت هاي» and the three ways out
///   (a note, a rewording, or – only on his tap – the AI round trip);
/// * a number with no tracker → the tap that builds the tracker;
/// * a dose or a diagnosis → it says, on the card, that it can only ever
///   become his own note. Never a medical fact, never advice.
class DayChatPieceCard extends StatelessWidget {
  const DayChatPieceCard({
    super.key,
    required this.piece,
    required this.state,
    this.edited = false,
    this.focused = false,
    this.onTap,
    this.onFile,
    this.onEdit,
    this.onReject,
    this.onKeepAsNote,
    this.onReword,
    this.onAskAi,
    this.onMakeTracker,
    this.onOpenRecord,
  });

  final DayChatPiece piece;

  /// What he has already decided about it (stored, so it survives a
  /// restart).
  final DayChatState state;

  /// True when he changed it before filing it.
  final bool edited;

  /// True while his own words of this piece are lit in the bubble above.
  final bool focused;

  final VoidCallback? onTap;
  final VoidCallback? onFile;
  final VoidCallback? onEdit;
  final VoidCallback? onReject;

  /// The unread sentence's three ways out.
  final VoidCallback? onKeepAsNote;
  final VoidCallback? onReword;
  final VoidCallback? onAskAi;

  /// A number with no tracker of his.
  final VoidCallback? onMakeTracker;

  /// Opens what filing it created.
  final VoidCallback? onOpenRecord;

  bool get _filed => state == DayChatState.applied;
  bool get _rejected => state == DayChatState.rejected;
  bool get _unread => piece.kind == DayChatKind.unread;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = DayChatTexts.of(context);
    final colour = _colour(t);
    final word = _stateWord(l);
    final gaps = tx.gaps(piece);
    final flag = piece.flag;

    return GlassCard(
      key: ValueKey('dayChat.cardBody.${piece.id}'),
      padding: const EdgeInsetsDirectional.all(Space.l),
      borderColor: colour.withValues(alpha: focused ? 0.55 : 0.30),
      glowColor: colour.withValues(alpha: focused ? 0.26 : 0.16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ----------------------------------------- what, and where to --
          Semantics(
            container: true,
            label: [tx.kind(piece.kind), tx.title(piece), tx.where(piece), word].join(l.recordListSeparator),
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.xs,
                  children: [
                    PlanPill(label: tx.kind(piece.kind), color: colour, icon: _icon()),
                    PlanPill(label: word, color: _stateColour(t), icon: _stateIcon()),
                    if (!_unread)
                      PlanPill(
                        label: tx.confidence(piece.confidence),
                        color: t.textTertiary,
                        icon: Icons.insights_rounded,
                      ),
                    if (edited || (piece.edited && _filed))
                      PlanPill(label: l.dayChatEditedBadge, color: t.gold, icon: Icons.edit_rounded),
                  ],
                ),
                const SizedBox(height: Space.m),
                Text(
                  tx.title(piece),
                  textDirection: BidiIsolate.directionOf(tx.title(piece)),
                  textAlign: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                  style: text.titleMedium?.copyWith(color: t.textPrimary, height: 1.4),
                ),
                const SizedBox(height: Space.xxs),
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: colour),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(
                        tx.where(piece),
                        style: text.bodySmall?.copyWith(color: colour, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ------------------------------------------------ his own words --
          const SizedBox(height: Space.m),
          PlanLabel(l.dayChatYourWords, icon: Icons.format_quote_rounded, color: t.secondary),
          PlanLines(lines: [tx.name(piece.text)], bullet: false),

          // ------------------------------------- medicine stays his doctor's --
          if (flag != null) ...[
            const SizedBox(height: Space.m),
            _Note(text: l.dayChatGuardNote, icon: Icons.shield_rounded, color: t.gold),
          ],

          // ------------------------------------------------- what is missing --
          // A sentence it could not read has its own, better paragraph
          // below; listing «ما فهمت هاي» as a gap as well would say the
          // same thing three times on one card.
          if (gaps.isNotEmpty && !_filed && !_unread) ...[
            const SizedBox(height: Space.m),
            if (piece.needsHim) _Note(text: l.dayChatNeedsYou, icon: Icons.edit_note_rounded, color: t.warning),
            for (final gap in gaps) ...[
              const SizedBox(height: Space.s),
              _Note(
                text: gap,
                icon: Icons.help_outline_rounded,
                color: piece.needsHim ? t.warning : t.textTertiary,
              ),
            ],
          ],

          // --------------------------------- the sentence it could not read --
          if (_unread && !_filed) ...[
            const SizedBox(height: Space.m),
            _Note(text: l.dayChatUnreadBody, icon: Icons.question_mark_rounded, color: t.warning),
            const SizedBox(height: Space.s),
            _Note(text: l.dayChatAiOffline, icon: Icons.wifi_off_rounded, color: t.textTertiary),
          ],

          // ------------------------------------- a number with no tracker --
          if (piece.kind == DayChatKind.sign && !_filed) ...[
            const SizedBox(height: Space.m),
            _Note(text: l.dayChatSignBody, icon: Icons.insights_rounded, color: t.info),
          ],

          // ----------------------------------------------- his decision --
          // Filed: the pill at the top already says «سجّلتها», so the only
          // thing left to offer is the way to the row it became.
          if (_filed) ...[
            if (onOpenRecord != null) ...[
              const SizedBox(height: Space.m),
              MadarButton(
                key: ValueKey('dayChat.open.${piece.id}'),
                label: l.dayChatOpenAction,
                icon: Icons.chevron_right_rounded,
                variant: MadarButtonVariant.secondary,
                size: MadarButtonSize.small,
                expand: true,
                sfx: Sfx.navigate,
                onPressed: onOpenRecord,
              ),
            ],
          ] else
            // A refusal is not a verdict: the card keeps «سجّلها» (and the
            // edit), because the undo toast is gone in five seconds and he
            // may change his mind in five minutes.
            ..._buttons(context, l, t),
        ],
      ),
    );
  }

  /// The buttons a piece in this state really has. «سجّلها» is drawn **only**
  /// for a piece the engine would write, so the screen can never offer what
  /// the engine refuses.
  List<Widget> _buttons(BuildContext context, L10n l, MadarTokens t) {
    final id = piece.id;
    final canFile = piece.canApply && onFile != null;
    final rows = <Widget>[];

    if (_unread) {
      rows.add(
        Row(
          children: [
            if (onKeepAsNote != null)
              Expanded(
                child: MadarButton(
                  key: ValueKey('dayChat.note.$id'),
                  label: l.dayChatNoteAction,
                  icon: Icons.sticky_note_2_outlined,
                  size: MadarButtonSize.small,
                  expand: true,
                  sfx: Sfx.complete,
                  onPressed: onKeepAsNote,
                ),
              ),
            if (onReword != null) ...[
              if (onKeepAsNote != null) const SizedBox(width: Space.s),
              Expanded(
                child: MadarButton(
                  key: ValueKey('dayChat.reword.$id'),
                  label: l.dayChatCorrectAction,
                  icon: Icons.edit_rounded,
                  variant: MadarButtonVariant.secondary,
                  size: MadarButtonSize.small,
                  expand: true,
                  sfx: Sfx.sheetOpen,
                  onPressed: onReword,
                ),
              ),
            ],
          ],
        ),
      );
      if (onAskAi != null) {
        rows
          ..add(const SizedBox(height: Space.s))
          ..add(
            Row(
              children: [
                Expanded(
                  child: MadarButton(
                    key: ValueKey('dayChat.askAi.$id'),
                    label: l.dayChatAskAiAction,
                    icon: Icons.auto_awesome_rounded,
                    variant: MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    expand: true,
                    sfx: Sfx.sheetOpen,
                    onPressed: onAskAi,
                  ),
                ),
              ],
            ),
          );
      }
    } else {
      if (piece.kind == DayChatKind.sign && onMakeTracker != null) {
        rows
          ..add(
            MadarButton(
              key: ValueKey('dayChat.tracker.$id'),
              label: l.dayChatTrackerAction,
              icon: Icons.add_chart_rounded,
              size: MadarButtonSize.small,
              expand: true,
              sfx: Sfx.sheetOpen,
              onPressed: onMakeTracker,
            ),
          )
          ..add(const SizedBox(height: Space.s));
      }
      rows.add(
        Row(
          children: [
            if (canFile)
              Expanded(
                child: MadarButton(
                  key: ValueKey('dayChat.file.$id'),
                  label: l.dayChatFileAction,
                  icon: Icons.check_rounded,
                  size: MadarButtonSize.small,
                  expand: true,
                  sfx: Sfx.complete,
                  onPressed: onFile,
                ),
              ),
            if (onEdit != null) ...[
              if (canFile) const SizedBox(width: Space.s),
              Expanded(
                child: MadarButton(
                  key: ValueKey('dayChat.edit.$id'),
                  label: l.dayChatEditAction,
                  icon: Icons.edit_rounded,
                  variant: canFile ? MadarButtonVariant.secondary : MadarButtonVariant.primary,
                  size: MadarButtonSize.small,
                  expand: true,
                  sfx: Sfx.sheetOpen,
                  onPressed: onEdit,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (onReject != null && !_rejected) {
      final reject = MadarButton(
        key: ValueKey('dayChat.reject.$id'),
        label: l.dayChatRejectAction,
        icon: Icons.close_rounded,
        variant: MadarButtonVariant.ghost,
        size: MadarButtonSize.small,
        expand: true,
        sfx: Sfx.tap,
        onPressed: onReject,
      );
      // «لأ» belongs beside the other decisions, not under them: it is one
      // of three, and a row of its own would make it look like more.
      final row = rows.isEmpty ? null : rows.last;
      if (row is Row && row.children.length < 5) {
        rows[rows.length - 1] = Row(
          children: [...row.children, const SizedBox(width: Space.s), Expanded(child: reject)],
        );
      } else {
        rows
          ..add(const SizedBox(height: Space.s))
          ..add(reject);
      }
    }

    return [const SizedBox(height: Space.l), ...rows];
  }

  // ------------------------------------------------------------- the look --

  Color _colour(MadarTokens t) => switch (piece.kind) {
    DayChatKind.expense || DayChatKind.income => t.gold,
    DayChatKind.meal || DayChatKind.water || DayChatKind.workout => t.secondary,
    DayChatKind.pain || DayChatKind.mood || DayChatKind.sign => t.info,
    DayChatKind.prayer => t.accent,
    DayChatKind.contact => t.secondary,
    DayChatKind.taskDone || DayChatKind.taskTodo || DayChatKind.note || DayChatKind.moduleEntry => t.accent,
    DayChatKind.unread => t.warning,
  };

  Color _stateColour(MadarTokens t) => switch (state) {
    DayChatState.applied => t.success,
    DayChatState.rejected => t.danger,
    DayChatState.undone => t.textTertiary,
    DayChatState.pending => piece.needsHim ? t.warning : t.textSecondary,
  };

  String _stateWord(L10n l) => switch (state) {
    DayChatState.applied => l.dayChatStateApplied,
    DayChatState.rejected => l.dayChatStateRejected,
    DayChatState.undone => l.dayChatStateUndone,
    DayChatState.pending => l.dayChatStatePending,
  };

  IconData _stateIcon() => switch (state) {
    DayChatState.applied => Icons.check_rounded,
    DayChatState.rejected => Icons.block_rounded,
    DayChatState.undone => Icons.undo_rounded,
    DayChatState.pending => piece.needsHim ? Icons.edit_note_rounded : Icons.hourglass_empty_rounded,
  };

  IconData _icon() => switch (piece.kind) {
    DayChatKind.expense => Icons.north_east_rounded,
    DayChatKind.income => Icons.south_west_rounded,
    DayChatKind.meal => Icons.restaurant_rounded,
    DayChatKind.workout => Icons.fitness_center_rounded,
    DayChatKind.water => Icons.water_drop_rounded,
    DayChatKind.pain => Icons.healing_rounded,
    DayChatKind.sign => Icons.insights_rounded,
    DayChatKind.prayer => Icons.mosque_rounded,
    DayChatKind.taskDone => Icons.task_alt_rounded,
    DayChatKind.taskTodo => Icons.event_note_rounded,
    DayChatKind.mood => Icons.mood_rounded,
    DayChatKind.note => Icons.sticky_note_2_outlined,
    DayChatKind.contact => Icons.people_alt_rounded,
    DayChatKind.moduleEntry => Icons.numbers_rounded,
    DayChatKind.unread => Icons.question_mark_rounded,
  };
}

/// One plain notice inside a card (a gap, a refusal, a reassurance) – the
/// same shape Part 3's cards use, so the two read as one idiom.
class _Note extends StatelessWidget {
  const _Note({required this.text, required this.icon, required this.color});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusS),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
