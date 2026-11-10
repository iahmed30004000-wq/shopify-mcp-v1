import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/adhkar_providers.dart';
import '../domain/adhkar_timing.dart';
import '../domain/tasbeeh.dart';
import 'adhkar_labels.dart';
import 'widgets/tasbeeh_ring.dart';

/// The tasbeeh: a ring of beads that springs one bead on with every tap (a
/// tick and a light haptic per bead, a stronger one and a pulse of light
/// per round), selectable phrases (editable, drag to reorder), a target of
/// 33 / 99 / 100 or a custom count with rounds, long-press to reset (with a
/// confirmation) and the history of sessions. Works one-handed: the whole
/// middle of the screen is the button.
class TasbeehScreen extends ConsumerStatefulWidget {
  const TasbeehScreen({super.key});

  @override
  ConsumerState<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends ConsumerState<TasbeehScreen> {
  final GlobalKey _ringKey = GlobalKey();

  TasbeehController get _ctrl => ref.read(tasbeehControllerProvider.notifier);

  Future<void> _tap() async {
    final s = ref.read(tasbeehControllerProvider).value;
    if (s == null || s.phrase == null) {
      Fx.fire(Sfx.error);
      return;
    }
    final roundEnds = (s.counter.count + 1) % s.counter.target == 0;
    // Feedback first: a bead tick, or the round's chime with a strong haptic.
    if (roundEnds) {
      Fx.fire(Sfx.complete, haptic: Haptic.heavy);
    } else {
      Fx.fire(Sfx.countTick);
    }
    final outcome = await _ctrl.tap();
    if (outcome != TasbeehTapOutcome.round || !mounted) return;
    final ring = _ringKey.currentContext;
    if (ring != null && ring.mounted) Celebrate.burstFrom(ring, kind: CelebrationKind.orbitalRing, intensity: 0.85);
  }

  Future<void> _confirmReset() async {
    final s = ref.read(tasbeehControllerProvider).value;
    if (s == null || s.counter.count == 0) {
      Fx.fire(Sfx.tap);
      return;
    }
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final t = context.tokens;
    final ok = await showInteractionSheet<bool>(
      context,
      builder: (sheet) => InteractionSheetFrame(
        title: l.adhkarTasbeehResetTitle,
        icon: Icons.restart_alt_rounded,
        body: Text(
          l.adhkarTasbeehResetBody(fmt.formatInt(s.counter.count)),
          style: Theme.of(sheet).textTheme.bodyLarge!.copyWith(color: t.textSecondary),
        ),
        footer: Row(
          children: [
            Expanded(
              child: SheetButton(label: l.actionCancel, onPressed: () => Navigator.of(sheet).pop(false)),
            ),
            const SizedBox(width: Space.s),
            Expanded(
              child: SheetButton(
                label: l.adhkarTasbeehReset,
                icon: Icons.restart_alt_rounded,
                primary: true,
                tone: t.danger,
                sfx: Sfx.delete,
                onPressed: () => Navigator.of(sheet).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _ctrl.reset();
  }

  Future<void> _customTarget(int current) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.adhkarTasbeehCustomTitle,
      icon: Icons.tune_rounded,
      fields: [
        FieldSpec.number(
          'target',
          l.adhkarTasbeehCustomField,
          required: true,
          min: 1,
          max: TasbeehDefaults.maxTarget,
          validator: (v, _) => TasbeehCounter.parseTarget(v) == null ? l.adhkarTasbeehCustomInvalid : null,
        ),
      ],
      initial: {'target': current},
    );
    final target = TasbeehCounter.parseTarget(result?['target']);
    if (target != null) await _ctrl.setTarget(target);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final state = ref.watch(tasbeehControllerProvider);
    return MadarScaffold(
      title: l.adhkarTasbeehTitle,
      actions: [
        MadarButton.icon(
          icon: Icons.history_rounded,
          variant: MadarButtonVariant.ghost,
          semanticLabel: l.adhkarTasbeehHistory,
          sfx: Sfx.sheetOpen,
          onPressed: () => unawaited(showTasbeehHistory(context)),
        ),
        MadarButton.icon(
          icon: Icons.edit_note_rounded,
          variant: MadarButtonVariant.ghost,
          semanticLabel: l.adhkarTasbeehEditPhrases,
          sfx: Sfx.sheetOpen,
          onPressed: () => unawaited(showTasbeehPhraseEditor(context)),
        ),
      ],
      body: switch (state) {
        AsyncData(:final value) => _body(value),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.adhkarLoadError, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  Widget _body(TasbeehState s) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = s.counter;
    final phrase = s.phrase;
    final custom = !TasbeehDefaults.targets.contains(c.target);
    final round = c.count == 0 ? 1 : ((c.count - 1) ~/ c.target) + 1;
    return Column(
      children: [
        if (s.phrases.isNotEmpty)
          ChoicePills<String>.single(
            options: [for (final p in s.phrases) ChoiceOption(value: p.id, label: fmt.isolate(p.text))],
            selected: phrase?.id,
            onChanged: (id) {
              if (id != null) unawaited(_ctrl.selectPhrase(id));
            },
            scrollable: true,
            dense: true,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = math.min(box.maxWidth - Space.l, box.maxHeight - Space.s).clamp(200.0, 420.0);
              final gloss = Localizations.localeOf(context).languageCode == 'en' && phrase != null
                  ? l.adhkarPhraseGloss(phrase)
                  : null;
              return Semantics(
                button: true,
                label: phrase == null
                    ? l.adhkarTasbeehNoPhrases
                    : l.adhkarTasbeehCountSemantics(
                        phrase.text,
                        fmt.formatInt(c.inRound),
                        fmt.formatInt(c.target),
                        fmt.formatInt(round),
                      ),
                hint: l.adhkarTasbeehCountHint,
                onTap: () => unawaited(_tap()),
                onLongPress: () => unawaited(_confirmReset()),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(_tap()),
                  onLongPress: () {
                    Fx.fire(Sfx.pickUp);
                    unawaited(_confirmReset());
                  },
                  child: Center(
                    child: TasbeehBeadRing(
                      key: _ringKey,
                      counter: c,
                      size: size,
                      child: SizedBox(
                        width: size * 0.56,
                        child: phrase == null
                            ? Text(
                                l.adhkarTasbeehNoPhrases,
                                textAlign: TextAlign.center,
                                style: text.bodyLarge!.copyWith(color: t.textSecondary),
                              )
                            : _RingCenter(phrase: phrase.text, gloss: gloss, counter: c, round: round, size: size),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.xxs),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(l.adhkarTasbeehTarget, style: text.labelMedium!.copyWith(color: t.textSecondary)),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.s, Space.xs),
          child: Row(
            children: [
              Expanded(
                child: ChoicePills<int>.single(
                  options: [
                    for (final v in TasbeehDefaults.targets) ChoiceOption(value: v, label: fmt.formatInt(v)),
                    ChoiceOption(
                      value: -1,
                      label: custom ? fmt.formatInt(c.target) : l.adhkarTasbeehCustom,
                      icon: Icons.tune_rounded,
                    ),
                  ],
                  selected: custom ? -1 : c.target,
                  onChanged: (v) {
                    if (v == null) return;
                    if (v == -1) {
                      unawaited(_customTarget(c.target));
                    } else {
                      unawaited(_ctrl.setTarget(v));
                    }
                  },
                  scrollable: true,
                  dense: true,
                ),
              ),
              MadarButton.icon(
                icon: Icons.restart_alt_rounded,
                variant: MadarButtonVariant.ghost,
                semanticLabel: l.adhkarTasbeehReset,
                onPressed: c.count == 0 ? null : () => unawaited(_confirmReset()),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.l),
          child: Text(l.adhkarTasbeehTapHint, textAlign: TextAlign.center, style: text.labelSmall),
        ),
      ],
    );
  }
}

class _RingCenter extends StatelessWidget {
  const _RingCenter({
    required this.phrase,
    required this.gloss,
    required this.counter,
    required this.round,
    required this.size,
  });

  final String phrase;
  final String? gloss;
  final TasbeehCounter counter;
  final int round;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          phrase,
          // The user's own words read in their script's direction
          // ("Glory be to God!" keeps its "!" at the end in Arabic).
          textDirection: tasbeehPhraseDirection(phrase),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: MadarTypography.naskhFamily,
            fontSize: (size * 0.06).clamp(17.0, 26.0),
            height: 1.7,
            color: t.textPrimary,
          ),
        ),
        if (gloss != null)
          Text(
            gloss!,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: text.labelSmall!.copyWith(color: t.textTertiary),
          ),
        SizedBox(height: size * 0.015),
        RollingNumber(
          value: counter.inRound,
          formatter: (n) => fmt.formatInt(n.toInt()),
          style: MadarTypography.numerals(
            t,
            size: size * 0.17,
            color: counter.roundJustCompleted ? t.accent : t.textPrimary,
          ).copyWith(fontWeight: FontWeight.w600, height: 1.05),
        ),
        Text(
          l.adhkarTasbeehOf(fmt.formatInt(counter.target)),
          style: text.labelMedium!.copyWith(color: t.textSecondary),
        ),
        if (counter.count > counter.target || counter.rounds > 0) ...[
          SizedBox(height: size * 0.02),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.xxs),
            decoration: BoxDecoration(
              color: t.accentSoft,
              borderRadius: BorderRadius.circular(t.radiusS),
              border: Border.all(color: t.glassBorder),
            ),
            child: Text(
              l.adhkarJoin(
                l.adhkarTasbeehRound(fmt.formatInt(round)),
                l.adhkarTasbeehTotal(fmt.formatInt(counter.count)),
              ),
              style: text.labelSmall!.copyWith(color: t.accent),
            ),
          ),
        ],
      ],
    );
  }
}

/// The direction a tasbeeh phrase reads in: its first strong letter's
/// (a user may type English), Arabic when it has none.
TextDirection tasbeehPhraseDirection(String phrase) => BidiIsolate.directionOf(phrase) ?? TextDirection.rtl;

// ------------------------------------------------------------ phrases ----

/// Edit the tasbeeh phrases: add, edit, delete (with undo), drag to reorder.
Future<void> showTasbeehPhraseEditor(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const _PhraseEditorSheet());

class _PhraseEditorSheet extends ConsumerWidget {
  const _PhraseEditorSheet();

  Future<void> _edit(BuildContext context, WidgetRef ref, TasbeehPhrase? phrase) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: phrase == null ? l.adhkarTasbeehAddPhrase : l.adhkarTasbeehEditPhrase,
      icon: Icons.edit_note_rounded,
      fields: [FieldSpec.text('text', l.adhkarTasbeehPhraseField, required: true, maxLength: 120, autofocus: true)],
      initial: {if (phrase != null) 'text': phrase.text},
    );
    final text = (result?['text'] as String?)?.trim();
    if (text == null || text.isEmpty) return;
    final ctrl = ref.read(tasbeehControllerProvider.notifier);
    if (phrase == null) {
      await ctrl.addPhrase(text);
    } else {
      await ctrl.editPhrase(phrase.id, text);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final phrases = ref.watch(tasbeehControllerProvider).value?.phrases ?? const <TasbeehPhrase>[];
    final english = Localizations.localeOf(context).languageCode == 'en';
    final uiStart = Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    return InteractionSheetFrame(
      title: l.adhkarTasbeehPhrases,
      icon: Icons.edit_note_rounded,
      bodyPadding: const EdgeInsetsDirectional.fromSTEB(0, Space.s, 0, Space.l),
      body: phrases.isEmpty
          ? Padding(
              padding: const EdgeInsetsDirectional.all(Space.xl),
              child: Text(l.adhkarTasbeehNoPhrases, textAlign: TextAlign.center, style: text.bodyLarge),
            )
          : ReorderableGlassList<TasbeehPhrase>(
              items: phrases,
              itemKey: (p) => p.id,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (order) => unawaited(ref.read(tasbeehControllerProvider.notifier).reorderPhrases(order)),
              itemBuilder: (context, p, index, handle) {
                final gloss = english ? l.adhkarPhraseGloss(p) : null;
                return ActionableItem(
                  key: ValueKey('phrase-${p.id}'),
                  semanticLabel: p.text,
                  onTap: () => unawaited(_edit(context, ref, p)),
                  actions: ItemActions(
                    onEdit: () => _edit(context, ref, p),
                    onDelete: () async {
                      final undo = await ref.read(tasbeehControllerProvider.notifier).deletePhrase(p.id);
                      return UndoableAction(label: l.adhkarTasbeehPhraseDeleted, undo: undo);
                    },
                  ),
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xs, Space.m, Space.xs),
                    decoration: BoxDecoration(
                      color: t.glassFill,
                      borderRadius: BorderRadius.circular(t.radiusM),
                      border: Border.all(color: t.glassBorder),
                    ),
                    child: Row(
                      children: [
                        handle,
                        const SizedBox(width: Space.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.text,
                                textDirection: tasbeehPhraseDirection(p.text),
                                textAlign: uiStart,
                                style: TextStyle(
                                  fontFamily: MadarTypography.naskhFamily,
                                  fontSize: 21,
                                  height: 1.7,
                                  color: t.textPrimary,
                                ),
                              ),
                              if (gloss != null) Text(gloss, style: text.labelSmall!.copyWith(color: t.textTertiary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      footer: SheetButton(
        label: l.adhkarTasbeehAddPhrase,
        icon: Icons.add_rounded,
        primary: true,
        onPressed: () => unawaited(_edit(context, ref, null)),
      ),
    );
  }
}

// ------------------------------------------------------------ history ----

/// The tasbeeh sessions of the last 30 days, by day; delete with undo.
Future<void> showTasbeehHistory(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const _HistorySheet());

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final sessions = ref.watch(tasbeehHistoryProvider).value ?? const <TasbeehSession>[];
    final uiStart = Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    final byDay = <DateTime, List<TasbeehSession>>{};
    for (final s in sessions) {
      byDay.putIfAbsent(AdhkarTiming.dateOnly(s.at), () => []).add(s);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return InteractionSheetFrame(
      title: l.adhkarTasbeehHistory,
      icon: Icons.history_rounded,
      body: sessions.isEmpty
          ? AnimatedEmptyState(
              kind: EmptyStateKind.emptyList,
              title: l.adhkarTasbeehHistoryEmpty,
              body: '',
              illustrationSize: 112,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final day in days) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.xs),
                    child: Row(
                      children: [
                        Text(
                          fmt.formatDate(day, style: MadarDateStyle.weekdayDayMonth),
                          style: text.titleSmall!.copyWith(color: t.accent),
                        ),
                        const Spacer(),
                        Text(
                          fmt.formatInt(byDay[day]!.fold(0, (a, s) => a + s.count)),
                          style: MadarTypography.numerals(t, size: 13, color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  for (final s in byDay[day]!)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                      child: ActionableItem(
                        key: ValueKey('session-${s.id}'),
                        semanticLabel: '${s.phrase} ${fmt.formatInt(s.count)}',
                        swipeEnabled: false,
                        actions: ItemActions(
                          onDelete: () async {
                            final undo = await ref.read(tasbeehControllerProvider.notifier).deleteSession(s.id);
                            if (undo == null) return null;
                            return UndoableAction(label: l.adhkarTasbeehSessionDeleted, undo: undo);
                          },
                        ),
                        child: Container(
                          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
                          decoration: BoxDecoration(
                            color: t.glassFill,
                            borderRadius: BorderRadius.circular(t.radiusM),
                            border: Border.all(color: t.glassBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.phrase,
                                      textDirection: tasbeehPhraseDirection(s.phrase),
                                      textAlign: uiStart,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: MadarTypography.naskhFamily,
                                        fontSize: 19,
                                        height: 1.6,
                                        color: t.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      l.adhkarJoin(
                                        fmt.formatTime(s.at),
                                        fmt.localizeDigits(l.adhkarTasbeehRounds(s.rounds)),
                                      ),
                                      style: text.labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: Space.m),
                              Text(
                                fmt.formatInt(s.count),
                                style: MadarTypography.numerals(
                                  t,
                                  size: 22,
                                  color: t.accent,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
