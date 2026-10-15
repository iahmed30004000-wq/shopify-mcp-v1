/// «الحفظ» · running one method on one stretch (Part 14, step 2).
///
/// Six of the seven methods run on this phone **tonight**, because they
/// need nothing but the keyboard and the verified text:
///
/// | method | what he does | what is written |
/// |---|---|---|
/// | «اكتب من حفظك» | types the passage | [HifzPlanService.recordWriting] |
/// | «املأ الفراغ» | types the missing words | a `blanks` result |
/// | «الإخفاء التدريجي» | text → first letters → types it hidden | a `hidden` result |
/// | «الربط» | types the start of each next verse | a `link` result |
/// | «اسمع وردّد» | listens and repeats | nothing – hearing is not remembering |
/// | «التقطيع» | reads آية → مجموعة → صفحة | nothing |
///
/// The seventh, «سمّع بصوتك», needs a microphone this build does not have.
/// It is never a dead button: the screen asks [hifzMethodsProvider] first
/// and, when the answer is "not ready", says so plainly and offers the
/// methods that do run.
///
/// Nothing religious is generated anywhere here. Every word drawn in the
/// Quran face is a [WordCheck.word] the engines produced out of the app's
/// own Uthmani data, and everything he types is drawn as his own writing,
/// labelled «مكتوب منك على الكيبورد».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/quran/ayah.dart';
import '../../../../core/quran/quran_audio.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../wird/data/wird_providers.dart' show quranCatalogReadyProvider;
import '../../../recitation/application/recitation_providers.dart';
import '../../../tasmee/tasmee.dart';
import '../../data/hifz_plan_providers.dart';
import '../../data/hifz_plan_service.dart';
import '../../domain/hifz_daily_plan.dart';
import '../../domain/hifz_modes.dart';
import '../../domain/mushaf_shape.dart';
import 'hifz_plan_nav.dart';
import 'hifz_plan_texts.dart';
import 'hifz_plan_widgets.dart';

/// Runs one method on one stretch, and writes the result into Part 13's
/// log so the strength is real.
class HifzDrillScreen extends ConsumerStatefulWidget {
  const HifzDrillScreen({super.key, required this.request, this.animateBackdrop = true});

  final HifzDrillRequest request;
  final bool animateBackdrop;

  @override
  ConsumerState<HifzDrillScreen> createState() => _HifzDrillScreenState();
}

class _HifzDrillScreenState extends ConsumerState<HifzDrillScreen> {
  /// What he is running now – he may swap the method without leaving.
  late HifzMethod _method = widget.request.method;

  /// Where the hiding ladder stands.
  HidingStage? _stage;

  final TextEditingController _writing = TextEditingController();
  final List<TextEditingController> _slots = [];
  final Set<int> _peeked = <int>{};

  /// The alignment of what he typed, once he asked for it.
  RecitationCheck? _checked;
  bool _saved = false;
  bool _saving = false;

  /// Which chunk level «التقطيع» is on.
  ChunkLevel _chunkLevel = ChunkLevel.ayah;

  DateTime? _startedAt;

  @override
  void dispose() {
    _writing.dispose();
    for (final c in _slots) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetAnswers() {
    _writing.clear();
    for (final c in _slots) {
      c.clear();
    }
    _peeked.clear();
    _checked = null;
    _saved = false;
  }

  /// Keeps one controller per slot (blanks, links) without rebuilding them
  /// on every frame.
  List<TextEditingController> _slotsFor(int count) {
    while (_slots.length < count) {
      _slots.add(TextEditingController());
    }
    return _slots.take(count).toList();
  }

  void _switchMethod(HifzMethod m) {
    setState(() {
      _method = m;
      _stage = null;
      _chunkLevel = ChunkLevel.ayah;
      _resetAnswers();
    });
  }

  // ------------------------------------------------------- the answers ----

  /// The whole passage as words the aligner understands: the verified word
  /// everywhere he was only reading, and **his own** words where the drill
  /// asked him to produce them. An empty slot is left out, so it reads as
  /// a word he never said rather than as a wrong one.
  List<HeardWord> _heardFor(RecitationTarget target, Map<int, String> typed) {
    final parts = <String>[];
    for (var i = 0; i < target.wordCount; i++) {
      if (typed.containsKey(i)) {
        final answer = typed[i]!.trim();
        if (answer.isNotEmpty) parts.add(answer);
      } else {
        parts.add(target.words[i].text);
      }
    }
    return TypedWords.of(parts.join(' '));
  }

  AlignmentOptions get _options => ref.read(tasmeeAlignmentProvider);

  Future<void> _save(RecitationCheck check) async {
    if (_saving || _saved) return;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    setState(() => _saving = true);
    try {
      final service = await ref.read(hifzPlanServiceProvider.future);
      final (_, undo) = await service.recordDrill(
        check,
        method: _method,
        startedAt: _startedAt,
        seed: _method == HifzMethod.blanks ? widget.request.seed : null,
      );
      // The new portion is done, so tomorrow's «جديد» is the next stretch.
      // Its undo rides along with the result's, so one tap really puts
      // everything back.
      final cursorUndo = await _advanceCursor(service);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
      Fx.fire(Sfx.complete);
      unawaited(
        showUndoToast(
          context,
          UndoableAction(
            label: fmt.localizeDigits(l.hifzDrillSaved),
            undo: () async {
              await cursorUndo?.call();
              await undo();
              if (mounted) setState(() => _saved = false);
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Moves the new-portion cursor past what he just finished; returns the
  /// undo, or null when there was nothing to move.
  Future<HifzPlanUndo?> _advanceCursor(HifzPlanService service) async {
    if (widget.request.track != HifzTrack.fresh) return null;
    final shape = ref.read(hifzMushafShapeProvider).value;
    if (shape == null) return null;
    final next = Mushaf.next(shape, widget.request.range.last);
    if (next == null) return null;
    return service.setNewFrom(next);
  }

  // ------------------------------------------------------------- build ----

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final texts = HifzPlanTexts.of(context, catalog: ref.watch(quranCatalogReadyProvider).value);
    final states = ref.watch(hifzMethodsProvider);
    final audioReady = _audioReady();
    final state = HifzMethods.statusOf(
      _method,
      recogniser: ref.watch(tasmeeAvailabilityProvider).value ??
          const RecogniserAvailability(trouble: RecogniserTrouble.notImplemented),
      audioDownloaded: audioReady,
    );
    final target = ref.watch(hifzTargetProvider(widget.request.range));
    _startedAt ??= ref.read(hifzPlanClockProvider)();

    return MadarScaffold(
      title: texts.method(_method),
      backdropSeed: 4.4,
      animateBackdrop:
          widget.animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        MadarButton.icon(
          key: const ValueKey('hifz.drill.methods'),
          icon: Icons.swap_horiz_rounded,
          semanticLabel: l.hifzPlanPickMethod,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => _pickMethod(states, audioReady, texts),
        ),
      ],
      body: ListView(
        key: const PageStorageKey('hifz.drill'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
        children: [
          _header(texts),
          const SizedBox(height: Space.m),
          if (!state.canRun)
            HifzNotReadyCard(
              state: state,
              texts: texts,
              onPickAnother: () => _pickMethod(states, audioReady, texts),
            )
          else
            switch (target) {
              AsyncData(value: final t) => _body(t, texts, state),
              AsyncError() => AnimatedEmptyState(
                kind: EmptyStateKind.noData,
                title: l.hifzCatalogError,
                body: '',
              ),
              _ => const Padding(
                padding: EdgeInsets.only(top: Space.xxl),
                child: Center(child: OrbitLoader(size: 36)),
              ),
            },
          const HifzHonestyNote(),
        ],
      ),
    );
  }

  bool _audioReady() {
    if (_method != HifzMethod.listenRepeat) return true;
    final shape = ref.watch(hifzMushafShapeProvider).value;
    if (shape == null) return true;
    final downloaded = ref.watch(hifzAudioDownloadedProvider);
    return Mushaf.ayatIn(shape, widget.request.range).every(downloaded);
  }

  Widget _header(HifzPlanTexts texts) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme;
    final r = widget.request;
    final pages = texts.pages(r.range);
    return HifzPanel(
      key: const ValueKey('hifz.drill.header'),
      icon: texts.methodIcon(_method),
      title: texts.range(r.range),
      subtitle: [
        if (r.track != null) texts.track(r.track!),
        ?pages,
      ].join(L10n.of(context).commonFactSeparator),
      child: Text(
        _methodBlurb(L10n.of(context)),
        style: style.bodySmall?.copyWith(color: t.textSecondary),
      ),
    );
  }

  String _methodBlurb(L10n l) => switch (_method) {
    HifzMethod.writing => l.hifzWritingHint,
    HifzMethod.blanks => l.hifzBlanksTypedBody,
    HifzMethod.progressiveHiding => l.hifzHidingTypedBody,
    HifzMethod.linking => l.hifzLinkingTypedBody,
    HifzMethod.chunking => l.hifzChunkBody,
    HifzMethod.listenRepeat => l.hifzDrillNoResultMode,
    HifzMethod.reciting => l.hifzMicSoonBody,
  };

  Widget _body(RecitationTarget target, HifzPlanTexts texts, HifzMethodState state) => switch (_method) {
    HifzMethod.writing => _writingBody(target, texts),
    HifzMethod.blanks => _blanksBody(target, texts),
    HifzMethod.progressiveHiding => _hidingBody(target, texts),
    HifzMethod.linking => _linkingBody(target, texts),
    HifzMethod.chunking => _chunkingBody(target, texts),
    HifzMethod.listenRepeat => _listenBody(target, texts),
    HifzMethod.reciting => HifzNotReadyCard(state: state, texts: texts),
  };

  // ----------------------------------------------------- اكتب من حفظك ----

  Widget _writingBody(RecitationTarget target, HifzPlanTexts texts) {
    final l = L10n.of(context);
    final check = _checked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HifzPanel(
          key: const ValueKey('hifz.drill.writing'),
          title: l.hifzWritingTitle,
          icon: Icons.edit_note_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('hifz.drill.writing.field'),
                controller: _writing,
                maxLines: 6,
                minLines: 3,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: l.hifzDrillWriteHint,
                  labelText: l.hifzWritingYours,
                ),
                onChanged: (_) {
                  if (_checked != null) setState(() => _checked = null);
                },
              ),
              const SizedBox(height: Space.m),
              _checkButton(() {
                final drill = WritingDrill(target, options: _options)..write(_writing.text);
                if (drill.result.typed == 0) return null;
                return drill.result.check;
              }),
            ],
          ),
        ),
        if (check != null) ...[
          const SizedBox(height: Space.m),
          _resultPanel(check, texts, typed: _writing.text),
        ],
      ],
    );
  }

  // ------------------------------------------------------- املأ الفراغ ----

  Widget _blanksBody(RecitationTarget target, HifzPlanTexts texts) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final plan = Blanks.plan(target, seed: widget.request.seed);
    final controllers = _slotsFor(plan.blanks.length);
    final check = _checked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HifzPanel(
          key: const ValueKey('hifz.drill.blanks'),
          title: l.tasmeeBlanksTitle,
          subtitle: fmt.localizeDigits(l.tasmeeBlanksCount(plan.count)),
          icon: Icons.space_bar_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The passage with its gaps, drawn from the verified text.
              _BlankedText(plan: plan),
              const SizedBox(height: Space.m),
              for (var i = 0; i < plan.blanks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: TextField(
                    key: ValueKey('hifz.drill.blank.$i'),
                    controller: controllers[i],
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: fmt.localizeDigits(l.hifzBlankField(fmt.formatInt(i + 1))),
                    ),
                    onChanged: (_) {
                      if (_checked != null) setState(() => _checked = null);
                    },
                  ),
                ),
              Text(l.hifzDrillTypedBadge, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary)),
              const SizedBox(height: Space.m),
              _checkButton(() {
                final typed = <int, String>{
                  for (var i = 0; i < plan.blanks.length; i++) plan.blanks[i]: controllers[i].text,
                };
                if (typed.values.every((v) => v.trim().isEmpty)) return null;
                return TasmeeAligner.align(target, _heardFor(target, typed), options: _options);
              }),
            ],
          ),
        ),
        if (check != null) ...[
          const SizedBox(height: Space.m),
          _resultPanel(check, texts, only: plan.blanks.toSet()),
        ],
      ],
    );
  }

  // ------------------------------------------------- الإخفاء التدريجي ----

  Widget _hidingBody(RecitationTarget target, HifzPlanTexts texts) {
    final l = L10n.of(context);
    final stage = _stage ??= widget.request.stage ?? HidingStage.full;
    final machine = HiddenVerseMachine(target: target, options: _options);
    if (stage == HidingStage.hidden) {
      machine.hearAll(TypedWords.of(_writing.text));
      for (final i in _peeked) {
        machine.peek(i);
      }
    }
    final harder = FirstLetters.harder(stage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HifzPanel(
          key: const ValueKey('hifz.drill.hiding'),
          title: l.hifzMethodHiding,
          subtitle: l.hifzHidingStageNow(texts.stage(stage)),
          icon: Icons.visibility_off_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              switch (stage) {
                HidingStage.full => HifzVerifiedText(
                  key: const ValueKey('hifz.drill.hiding.full'),
                  words: [
                    for (final w in target.words)
                      WordCheck(word: w, verdict: WordVerdict.pending),
                  ],
                ),
                HidingStage.firstLetters => HifzFirstLettersText(
                  key: const ValueKey('hifz.drill.hiding.letters'),
                  hints: FirstLetters.ofTarget(target),
                ),
                HidingStage.hidden => HifzVerifiedText(
                  key: const ValueKey('hifz.drill.hiding.hidden'),
                  words: machine.check.words,
                  hidden: {
                    for (var i = 0; i < target.wordCount; i++)
                      if (machine.check.words[i].verdict == WordVerdict.pending && !_peeked.contains(i)) i,
                  },
                  hints: _peeked,
                ),
              },
              const SizedBox(height: Space.m),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  if (harder != null)
                    MadarButton(
                      key: const ValueKey('hifz.drill.hiding.harder'),
                      label: l.hifzHidingHarder,
                      icon: Icons.visibility_off_outlined,
                      size: MadarButtonSize.small,
                      variant: MadarButtonVariant.secondary,
                      onPressed: () => setState(() {
                        _stage = harder;
                        _checked = null;
                      }),
                    ),
                  if (stage != HidingStage.full)
                    MadarButton(
                      key: const ValueKey('hifz.drill.hiding.easier'),
                      label: l.hifzHidingEasier,
                      icon: Icons.visibility_outlined,
                      size: MadarButtonSize.small,
                      variant: MadarButtonVariant.ghost,
                      onPressed: () => setState(() {
                        _stage = stage == HidingStage.hidden ? HidingStage.firstLetters : HidingStage.full;
                        _checked = null;
                      }),
                    ),
                  if (stage == HidingStage.hidden)
                    MadarButton(
                      key: const ValueKey('hifz.drill.hiding.peek'),
                      label: l.tasmeePeek,
                      icon: Icons.lightbulb_outline_rounded,
                      size: MadarButtonSize.small,
                      variant: MadarButtonVariant.ghost,
                      onPressed: () {
                        final at = machine.check.cursor;
                        if (at == null) return;
                        setState(() {
                          _peeked.add(at);
                          _checked = null;
                        });
                      },
                    ),
                ],
              ),
              if (stage == HidingStage.hidden) ...[
                const SizedBox(height: Space.m),
                Text(
                  l.tasmeePeekCountsAsHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textTertiary),
                ),
                const SizedBox(height: Space.m),
                TextField(
                  key: const ValueKey('hifz.drill.hiding.field'),
                  controller: _writing,
                  maxLines: 6,
                  minLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: l.hifzDrillWriteHint,
                    labelText: l.hifzWritingYours,
                  ),
                  onChanged: (_) => setState(() => _checked = null),
                ),
                const SizedBox(height: Space.m),
                _checkButton(() {
                  if (TypedWords.of(_writing.text).isEmpty) return null;
                  return machine.check;
                }),
              ],
            ],
          ),
        ),
        if (_checked != null) ...[
          const SizedBox(height: Space.m),
          _resultPanel(_checked!, texts, typed: _writing.text),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ الربط ----

  Widget _linkingBody(RecitationTarget target, HifzPlanTexts texts) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final links = Linking.of(target);
    if (links.isEmpty) {
      return HifzPanel(
        key: const ValueKey('hifz.drill.linking.short'),
        title: l.hifzLinkingTitle,
        icon: Icons.link_rounded,
        child: Text(l.hifzLinkingNeedsTwo, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary)),
      );
    }
    final controllers = _slotsFor(links.length);
    final check = _checked;
    final scored = check == null ? null : Linking.score(check, links);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < links.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: HifzPanel(
              key: ValueKey('hifz.drill.link.$i'),
              title: texts.ayahRef(links[i].from),
              icon: Icons.link_rounded,
              trailing: scored == null
                  ? null
                  : Icon(
                      scored[i].isRight ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 20,
                      color: scored[i].isRight ? t.success : t.danger,
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    links[i].tail.map((w) => w.text).join(' '),
                    textAlign: TextAlign.center,
                    style: MadarTypography.quran(t, size: 22),
                  ),
                  const SizedBox(height: Space.s),
                  TextField(
                    key: ValueKey('hifz.drill.link.field.$i'),
                    controller: controllers[i],
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(labelText: l.hifzLinkingField),
                    onChanged: (_) {
                      if (_checked != null) setState(() => _checked = null);
                    },
                  ),
                  if (scored != null && !scored[i].isRight) ...[
                    const SizedBox(height: Space.s),
                    Text(
                      links[i].head.map((w) => w.text).join(' '),
                      textAlign: TextAlign.center,
                      style: MadarTypography.quran(t, size: 20).copyWith(color: t.success),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Text(l.hifzDrillTypedBadge, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary)),
        const SizedBox(height: Space.m),
        _checkButton(() {
          final typed = <int, String>{};
          for (var i = 0; i < links.length; i++) {
            for (final w in links[i].head) {
              typed[w.index] = '';
            }
            // The whole answer goes in at the head's first word.
            typed[links[i].head.first.index] = controllers[i].text;
          }
          if (controllers.every((c) => c.text.trim().isEmpty)) return null;
          return TasmeeAligner.align(target, _heardFor(target, typed), options: _options);
        }),
        if (scored != null) ...[
          const SizedBox(height: Space.m),
          HifzPanel(
            key: const ValueKey('hifz.drill.linking.score'),
            title: l.hifzLinkingTitle,
            icon: Icons.insights_rounded,
            child: Text(
              fmt.localizeDigits(
                l.hifzLinkingScore(
                  fmt.formatInt(scored.where((s) => s.isRight).length),
                  fmt.formatInt(scored.length),
                ),
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: Space.m),
          _saveRow(check!),
        ],
      ],
    );
  }

  // --------------------------------------------------------- التقطيع ----

  Widget _chunkingBody(RecitationTarget target, HifzPlanTexts texts) {
    final l = L10n.of(context);
    final t = context.tokens;
    final shape = ref.watch(hifzMushafShapeProvider).value;
    if (shape == null) return const Center(child: OrbitLoader(size: 36));
    final settings = ref.watch(hifzPlanSettingsProvider).value ?? const HifzPlanSettings();
    final ladder = ChunkLadder.build(shape, widget.request.range, groupSize: settings.groupSize);
    final step = ladder.stepOf(_chunkLevel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Space.s,
          children: [
            for (final level in ChunkLevel.values)
              MadarChip(
                key: ValueKey('hifz.drill.chunk.${level.name}'),
                label: texts.chunkLevel(level),
                selected: _chunkLevel == level,
                dense: true,
                onSelected: (_) => setState(() => _chunkLevel = level),
              ),
          ],
        ),
        const SizedBox(height: Space.m),
        Text(
          MadarFormatter.of(context).localizeDigits(l.hifzChunkCount(step.chunks.length)),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: Space.s),
        for (final chunk in step.chunks)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: HifzPanel(
              key: ValueKey('hifz.drill.chunk.${chunk.first}-${chunk.last}'),
              title: texts.range(chunk),
              icon: Icons.view_agenda_outlined,
              child: HifzVerifiedText(
                words: [
                  for (final w in _wordsOf(target, chunk)) WordCheck(word: w, verdict: WordVerdict.pending),
                ],
                size: 22,
              ),
            ),
          ),
        const SizedBox(height: Space.s),
        Text(
          l.hifzDrillNoResultMode,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
        ),
        const SizedBox(height: Space.m),
        MadarButton(
          key: const ValueKey('hifz.drill.chunk.toWriting'),
          label: l.hifzMethodWriting,
          icon: Icons.edit_note_rounded,
          variant: MadarButtonVariant.secondary,
          onPressed: () => _switchMethod(HifzMethod.writing),
        ),
      ],
    );
  }

  List<AyahWord> _wordsOf(RecitationTarget target, AyahRange chunk) {
    final inside = [
      for (final a in target.ayat)
        if (!(a.ref < chunk.first) && !(chunk.last < a.ref)) a,
    ];
    if (inside.isEmpty) return const [];
    return target.words.sublist(inside.first.firstWord, inside.last.lastWord + 1);
  }

  // ----------------------------------------------------- اسمع وردّد ----

  Widget _listenBody(RecitationTarget target, HifzPlanTexts texts) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final shape = ref.watch(hifzMushafShapeProvider).value;
    if (shape == null) return const Center(child: OrbitLoader(size: 36));
    final downloaded = ref.watch(hifzAudioDownloadedProvider);
    final plan = ListenRepeatPlan.build(
      shape,
      widget.request.range,
      reciterId: ref.watch(recitationReciterProvider).id,
      timesPerAyah: widget.request.repetitions,
      downloaded: downloaded,
    );
    final audio = ref.watch(quranAudioProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HifzPanel(
          key: const ValueKey('hifz.drill.listen'),
          title: l.hifzMethodListenRepeat,
          icon: Icons.headphones_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fmt.localizeDigits(
                  l.hifzListenPlan(texts.times(plan.timesPerAyah), texts.times(plan.passes)),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (!plan.playsOffline) ...[
                const SizedBox(height: Space.s),
                Text(
                  fmt.localizeDigits(l.hifzListenMissing(texts.ayat(plan.ayatMissingAudio.length))),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.warning),
                ),
              ],
              const SizedBox(height: Space.m),
              StreamBuilder<QuranPlayback>(
                stream: audio.playback,
                initialData: audio.value,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return MadarButton(
                    key: const ValueKey('hifz.drill.listen.play'),
                    label: playing ? l.hifzListenStop : l.hifzListen,
                    icon: playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    onPressed: () => unawaited(
                      playing
                          ? audio.stop()
                          : audio.play(plan.range, repeatAyah: plan.timesPerAyah, repeatRange: plan.passes),
                    ),
                  );
                },
              ),
              const SizedBox(height: Space.m),
              Text(
                l.hifzDrillNoResultMode,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        HifzPanel(
          title: l.tasmeeVerifiedLabel,
          icon: Icons.menu_book_rounded,
          child: HifzVerifiedText(
            words: [for (final w in target.words) WordCheck(word: w, verdict: WordVerdict.pending)],
            size: 22,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------- shared result bits ----

  Widget _checkButton(RecitationCheck? Function() build) {
    final l = L10n.of(context);
    return MadarButton(
      key: const ValueKey('hifz.drill.check'),
      label: l.hifzDrillCheck,
      icon: Icons.fact_check_outlined,
      onPressed: () {
        final check = build();
        if (check == null) {
          Fx.fire(Sfx.error);
          unawaited(
            showUndoToast(context, UndoableAction(label: l.hifzDrillNothingYet, undo: () async {})),
          );
          return;
        }
        Fx.fire(Sfx.tap);
        setState(() {
          _checked = check;
          _saved = false;
        });
      },
    );
  }

  /// The verdicts over the verified text, the counts in one line, and the
  /// one button that writes the result into the log.
  Widget _resultPanel(RecitationCheck check, HifzPlanTexts texts, {String? typed, Set<int>? only}) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final counts = check.counts;
    final shown = only == null
        ? check.words
        : [
            for (var i = 0; i < check.words.length; i++)
              if (only.contains(i)) check.words[i],
          ];
    return HifzPanel(
      key: const ValueKey('hifz.drill.result'),
      title: l.tasmeeVerifiedLabel,
      icon: Icons.rule_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HifzVerifiedText(key: const ValueKey('hifz.drill.result.text'), words: shown, size: 22),
          const SizedBox(height: Space.m),
          Text(
            fmt.localizeDigits(
              l.hifzDrillResultLine(
                fmt.formatInt(counts.right),
                fmt.formatInt(counts.wrong),
                fmt.formatInt(counts.skipped),
                fmt.formatInt(counts.extras),
              ),
            ),
            key: const ValueKey('hifz.drill.result.counts'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (typed != null && typed.trim().isNotEmpty) ...[
            const SizedBox(height: Space.m),
            HifzTypedAnswer(text: typed.trim()),
          ],
          const SizedBox(height: Space.m),
          _saveRow(check),
        ],
      ),
    );
  }

  Widget _saveRow(RecitationCheck check) {
    final l = L10n.of(context);
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        MadarButton(
          key: const ValueKey('hifz.drill.save'),
          label: _saved ? l.hifzDrillSaved : l.hifzDrillSave,
          icon: _saved ? Icons.check_rounded : Icons.save_outlined,
          loading: _saving,
          onPressed: _saved ? null : () => unawaited(_save(check)),
        ),
        MadarButton(
          key: const ValueKey('hifz.drill.again'),
          label: l.hifzDrillAgain,
          icon: Icons.refresh_rounded,
          variant: MadarButtonVariant.ghost,
          onPressed: () => setState(_resetAnswers),
        ),
      ],
    );
  }

  // ------------------------------------------------------ the method sheet ----

  Future<void> _pickMethod(List<HifzMethodState> states, bool audioReady, HifzPlanTexts texts) async {
    final picked = await showHifzMethodSheet(
      context,
      states: states,
      texts: texts,
      audioDownloaded: audioReady,
      current: _method,
    );
    if (picked != null && mounted) _switchMethod(picked);
  }
}

/// The passage with its gaps: every word of the verified text, and a line
/// where a word was taken out.
class _BlankedText extends StatelessWidget {
  const _BlankedText({required this.plan});

  final BlankPlan plan;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = MadarTypography.quran(t, size: 22);
    final spans = <InlineSpan>[];
    for (var i = 0; i < plan.target.wordCount; i++) {
      if (i > 0) spans.add(TextSpan(text: ' ', style: base));
      if (plan.isBlank(i)) {
        spans.add(
          TextSpan(
            text: '―――',
            style: base.copyWith(color: t.accent),
          ),
        );
      } else {
        spans.add(TextSpan(text: plan.target.words[i].text, style: base));
      }
    }
    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.center);
  }
}

/// «طرق الحفظ» – every method with what it can do right now. A method
/// that needs the microphone is **shown**, greyed, with the plain line
/// that says why; it is never quietly dropped.
Future<HifzMethod?> showHifzMethodSheet(
  BuildContext context, {
  required List<HifzMethodState> states,
  required HifzPlanTexts texts,
  required HifzMethod current,
  bool audioDownloaded = true,
}) {
  final l = L10n.of(context);
  return showInteractionSheet<HifzMethod>(
    context,
    builder: (sheetContext) => InteractionSheetFrame(
      title: l.hifzPlanMethodsTitle,
      icon: Icons.auto_stories_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in HifzMethod.values)
            Builder(
              builder: (context) {
                final state = states.firstWhere(
                  (s) => s.method == m,
                  orElse: () => HifzMethodState(method: m, status: HifzMethodStatus.ready),
                );
                final effective = m == HifzMethod.listenRepeat && !audioDownloaded
                    ? const HifzMethodState(
                        method: HifzMethod.listenRepeat,
                        status: HifzMethodStatus.unavailable,
                        blocker: HifzMethodBlocker.audioNotDownloaded,
                      )
                    : state;
                final line = texts.blocker(effective);
                final t = context.tokens;
                return Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: MadarPressable(
                    key: ValueKey('hifz.method.${m.name}'),
                    onTap: effective.canRun ? () => Navigator.of(sheetContext).pop(m) : null,
                    enabled: effective.canRun,
                    semanticLabel: [texts.method(m), ?line].join('. '),
                    excludeChildSemantics: true,
                    focusRadius: BorderRadius.circular(t.radiusM),
                    child: GlassCard(
                      glow: false,
                      padding: const EdgeInsetsDirectional.all(Space.m),
                      child: Row(
                        children: [
                          Icon(
                            texts.methodIcon(m),
                            size: 20,
                            color: effective.canRun ? t.accent : t.textTertiary,
                          ),
                          const SizedBox(width: Space.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  texts.method(m),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: effective.canRun ? t.textPrimary : t.textTertiary,
                                  ),
                                ),
                                if (line != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: Space.xxs),
                                    child: Text(
                                      line,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (m == current) Icon(Icons.check_rounded, size: 18, color: t.accent),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
