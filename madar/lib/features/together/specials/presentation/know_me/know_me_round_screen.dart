import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../../data/together_providers.dart';
import '../../../domain/player_profile.dart';
import '../../../domain/trophies.dart';
import '../../../presentation/hall_of_fame_screen.dart';
import '../../../presentation/handoff/hand_off.dart';
import '../../../presentation/together_texts.dart';
import '../../../presentation/widgets/together_visuals.dart';
import '../../data/specials_providers.dart';
import '../../data/specials_repository.dart';
import '../../domain/know_me_round.dart';
import '../../domain/specials_bounds.dart';
import '../specials_texts.dart';

/// One round of "How well do you know me?" on a shared phone:
///
/// 1. Each player in turn, behind the pass-and-play gate, answers every
///    question about themselves and guesses the other's answers. The gate
///    builds only the current player's own inputs – the other's never exist
///    on screen – and hides them whenever the phone is handed over or the
///    app leaves the foreground. The keyboard is asked not to learn or
///    suggest what was typed (no suggestion bar gives an answer away).
/// 2. Together: each answer is revealed beside the other's guess and the
///    player it is about judges it (spot on 2, close 1, not quite 0).
/// 3. The better guesser wins; the round goes into the head-to-head history
///    and the Hall of Fame.
class KnowMeRoundScreen extends ConsumerStatefulWidget {
  const KnowMeRoundScreen({super.key, required this.round, this.random});

  final KnowMeRound round;

  /// For the next round's draw (tests pass a seeded one).
  final math.Random? random;

  @override
  ConsumerState<KnowMeRoundScreen> createState() => _KnowMeRoundScreenState();
}

class _KnowMeRoundScreenState extends ConsumerState<KnowMeRoundScreen> {
  KnowMeRound get _round => widget.round;
  final HandOffController _handOff = HandOffController();

  /// Unsubmitted answers of a player whose private view was hidden (the app
  /// went to the background): given back when they reveal again.
  final Map<PlayerSlot, List<KnowMeAnswer>> _drafts = {};

  /// Reveal: the question on screen and the guesses already turned over.
  int _question = 0;
  final Set<KnowMeItem> _shown = {};

  bool _recording = false;
  KnowMeRecorded? _recorded;
  final GlobalKey _heroKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final turn = _round.turn;
    if (turn != null) _handOff.passTo(turn.index);
  }

  @override
  void dispose() {
    _handOff.dispose();
    super.dispose();
  }

  void _submit(PlayerSlot slot, List<KnowMeAnswer> answers) {
    if (_round.turn != slot) return;
    _round.submit(slot, answers);
    _drafts.remove(slot);
    FocusManager.instance.primaryFocus?.unfocus();
    final next = _round.turn;
    if (next != null) {
      _handOff.passTo(next.index);
    } else {
      _handOff.hideAll();
      Fx.fire(Sfx.sparkle);
    }
    setState(() {});
  }

  bool get _hasInput =>
      _round.phase != KnowMePhase.answering ||
      _round.hasAnswered(_round.first) ||
      _drafts.values.any((list) => list.any((a) => a.own.isNotEmpty || a.guess.isNotEmpty));

  Future<void> _leave() async {
    if (_round.phase == KnowMePhase.finished || !_hasInput) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final l = SpecialsTexts.of(context).l;
    final leave = await showInteractionSheet<bool>(
      context,
      builder: (context) => InteractionSheetFrame(
        title: l.togetherKnowMeLeaveTitle,
        icon: Icons.logout_rounded,
        body: Text(l.togetherKnowMeLeaveBody, style: Theme.of(context).textTheme.bodyMedium),
        footer: Row(
          children: [
            Expanded(
              child: SheetButton(
                key: const ValueKey('knowme-stay'),
                label: l.togetherKnowMeStay,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: SheetButton(
                key: const ValueKey('knowme-leave'),
                label: l.togetherKnowMeLeave,
                primary: true,
                tone: context.tokens.danger,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_recording || _recorded != null || !_round.allJudged) return;
    setState(() => _recording = true);
    final repo = ref.read(specialsRepositoryProvider);
    final now = ref.read(togetherClockProvider)();
    KnowMeRecorded recorded;
    try {
      recorded = await repo.recordKnowMe(_round, now);
    } on Object catch (e) {
      debugPrint('Know-me round not recorded: $e');
      _round.finish();
      recorded = const KnowMeRecorded(recorded: false, newTrophies: []);
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recorded = recorded;
    });
    Fx.fire(Sfx.levelUp);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final hero = _heroKey.currentContext;
      if (hero != null && hero.mounted && recorded.newTrophies.isEmpty) {
        Celebrate.burstFrom(hero, kind: CelebrationKind.stardust);
      }
      await celebrateTrophies(context, recorded.newTrophies);
    });
  }

  /// A new round with the other player answering first. Bank and prefs are
  /// read from storage (not the streams): the questions just asked are
  /// already marked, so they are not drawn again straight away.
  Future<void> _playAgain() async {
    final repo = ref.read(specialsRepositoryProvider);
    final lang = SpecialsTexts.of(context).lang;
    final bank = await repo.bank();
    final prefs = await repo.prefs();
    if (!mounted) return;
    if (bank.questionsInAny(prefs.categories).isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final next = KnowMeRound.draw(
      bank: bank,
      prefs: prefs,
      languageCode: lang,
      first: _round.first.other,
      now: ref.read(togetherClockProvider)(),
      random: widget.random,
    );
    Fx.fire(Sfx.navigate);
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => KnowMeRoundScreen(round: next, random: widget.random),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(togetherProfilesProvider).value ?? TogetherProfiles.defaults();
    final phase = _round.phase;
    return PopScope(
      canPop: phase == KnowMePhase.finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: switch (phase) {
        KnowMePhase.answering => _answering(context, profiles),
        KnowMePhase.reveal => _reveal(context, profiles),
        KnowMePhase.finished => _results(context, profiles),
      },
    );
  }

  // ------------------------------------------------------------ answering

  Widget _answering(BuildContext context, TogetherProfiles profiles) {
    final t = context.tokens;
    final l = SpecialsTexts.of(context).l;
    return Scaffold(
      backgroundColor: t.space0,
      body: Stack(
        children: [
          Positioned.fill(
            child: HandOffGate(
              controller: _handOff,
              profileOf: (p) => profiles.of(PlayerSlot.values[p]),
              privateBuilder: (context, p) {
                final slot = PlayerSlot.values[p];
                return _PrivateAnswers(
                  key: ValueKey('knowme-private-${slot.name}'),
                  round: _round,
                  me: profiles.of(slot),
                  partner: profiles.of(slot.other),
                  initial: _drafts[slot],
                  lastToAnswer: _round.hasAnswered(slot.other),
                  onChanged: (answers) => _drafts[slot] = answers,
                  onDone: (answers) => _submit(slot, answers),
                );
              },
            ),
          ),
          PositionedDirectional(
            top: 0,
            start: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Space.s),
                child: MadarButton.icon(
                  key: const ValueKey('knowme-close'),
                  icon: Icons.close_rounded,
                  onPressed: () => unawaited(_leave()),
                  semanticLabel: l.togetherKnowMeLeave,
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  sfx: Sfx.back,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- reveal

  Widget _reveal(BuildContext context, TogetherProfiles profiles) {
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final q = _question.clamp(0, _round.questions.length - 1);
    final items = [KnowMeItem(q, _round.first), KnowMeItem(q, _round.first.other)];
    final questionDone = items.every((i) => _shown.contains(i) && (_round.isVoid(i) || _round.verdictOf(i) != null));
    final last = q == _round.questions.length - 1;
    return MadarScaffold(
      title: l.togetherKnowMeRevealTitle,
      backdropSeed: 3.3,
      animateBackdrop: false,
      onBack: () => unawaited(_leave()),
      body: TogetherPrivateSurface(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
              child: _Scoreboard(round: _round, profiles: profiles, revealed: _shown),
            ),
            Expanded(
              child: ListView(
                key: ValueKey('knowme-reveal-$q'),
                padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.l),
                children: [
                  _QuestionHeader(index: q, total: _round.questions.length, text: _round.questions[q].text),
                  const SizedBox(height: Space.m),
                  for (final item in items) ...[
                    _RevealCard(
                      key: ValueKey('knowme-item-${item.index}-${item.subject.name}'),
                      round: _round,
                      item: item,
                      profiles: profiles,
                      shown: _shown.contains(item),
                      onReveal: () => setState(() {
                        _shown.add(item);
                        Fx.fire(Sfx.swipe);
                      }),
                      onJudge: (v) => setState(() => _round.judge(item, v)),
                    ),
                    const SizedBox(height: Space.m),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.m),
                child: MadarButton(
                  key: const ValueKey('knowme-next'),
                  label: questionDone
                      ? (last ? l.togetherKnowMeSeeResults : l.togetherKnowMeNextQuestion)
                      : l.togetherKnowMeJudgeFirst,
                  icon: last ? Icons.emoji_events_rounded : Icons.arrow_forward_rounded,
                  size: MadarButtonSize.large,
                  expand: true,
                  loading: _recording,
                  onPressed: !questionDone
                      ? null
                      : last
                      ? () => unawaited(_finish())
                      : () => setState(() => _question = q + 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- results

  Widget _results(BuildContext context, TogetherProfiles profiles) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final tx = st.tx;
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final r = _round.result!;
    final winner = r.outcome.winner;
    final recorded = _recorded;

    Widget playerRow(TogetherProfile p) {
      final score = r.scoreOf(p.slot), max = r.maxOf(p.slot);
      final fraction = max == 0 ? 0.0 : score / max;
      final color = TogetherLook.colorOf(p);
      return GlassCard(
        key: ValueKey('knowme-result-${p.slot.name}'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        child: Row(
          children: [
            TogetherAvatarView(profile: p, displayName: tx.rawName(p), size: 44, glow: winner == p.slot),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tx.rawName(p),
                          style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        l.togetherKnowMeScoreOf(tx.n(score), tx.n(max)),
                        style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(color: t.glassBorder),
                          FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: fraction,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [color, Color.lerp(color, t.gold, 0.5)!]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    l.togetherKnowMeAccuracy(st.percent(fraction)),
                    style: text.labelSmall?.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            if (r.perfect.contains(p.slot)) ...[
              const SizedBox(width: Space.s),
              Tooltip(
                message: tx.trophy(TrophyId.mindReader),
                child: const TrophyMedal(id: TrophyId.mindReader, size: 40),
              ),
            ],
          ],
        ),
      );
    }

    final heroProfile = winner == null ? null : profiles.of(winner);
    return MadarScaffold(
      title: l.togetherKnowMeResultsTitle,
      backdropSeed: 5.2,
      animateBackdrop: false,
      // The recap shows every answer: kept out of the recents thumbnail too.
      body: TogetherPrivateSurface(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
          children: [
            GlassPanel(
              key: _heroKey,
              seed: 4,
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xl, Space.l, Space.xl),
              child: Column(
                children: [
                  if (heroProfile != null)
                    TogetherAvatarView(
                      profile: heroProfile,
                      displayName: tx.rawName(heroProfile),
                      size: 104,
                      glow: true,
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final p in profiles.both)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                            child: TogetherAvatarView(profile: p, displayName: tx.rawName(p), size: 72, glow: true),
                          ),
                      ],
                    ),
                  const SizedBox(height: Space.m),
                  Semantics(
                    header: true,
                    child: Text(
                      heroProfile == null ? l.togetherKnowMeDrawText : l.togetherResultWon(tx.name(heroProfile)),
                      style: text.headlineSmall?.copyWith(color: t.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    tx.score(r.scoreOne, r.scoreTwo),
                    style: text.titleLarge?.copyWith(color: t.gold, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.l),
            for (final p in profiles.both) ...[playerRow(p), const SizedBox(height: Space.s)],
            if (recorded != null && !recorded.recorded) ...[
              const SizedBox(height: Space.s),
              Text(
                l.togetherKnowMeNotRecorded,
                key: const ValueKey('knowme-not-recorded'),
                style: text.bodySmall?.copyWith(color: t.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: Space.xl),
            MadarButton(
              key: const ValueKey('knowme-again'),
              label: l.togetherKnowMePlayAgain,
              icon: Icons.replay_rounded,
              size: MadarButtonSize.large,
              expand: true,
              onPressed: _recording ? null : () => unawaited(_playAgain()),
            ),
            const SizedBox(height: Space.s),
            MadarButton(
              key: const ValueKey('knowme-done'),
              label: l.togetherKnowMeFinish,
              variant: MadarButtonVariant.ghost,
              expand: true,
              sfx: Sfx.back,
              onPressed: () => Navigator.of(context).pop(),
            ),
            SectionHeader(
              title: l.togetherKnowMeRecap,
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
            ),
            for (var i = 0; i < _round.questions.length; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                child: _RecapCard(round: _round, index: i, profiles: profiles),
              ),
          ],
        ),
      ),
    );
  }
}

/// One question of the finished round: each player's answer, the other's
/// guess and how it was judged – a little keepsake of the round.
class _RecapCard extends StatelessWidget {
  const _RecapCard({required this.round, required this.index, required this.profiles});

  final KnowMeRound round;
  final int index;
  final TogetherProfiles profiles;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final tx = st.tx;
    final l = st.l;
    final text = Theme.of(context).textTheme;

    Widget entry(PlayerSlot subject) {
      final item = KnowMeItem(index, subject);
      final p = profiles.of(subject);
      final guesser = profiles.of(subject.other);
      final isVoid = round.isVoid(item);
      final verdict = round.verdictOf(item);
      final guess = round.guessOf(item);
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: Space.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TogetherAvatarView(profile: p, displayName: tx.rawName(p), size: 26, ring: false),
            const SizedBox(width: Space.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVoid ? l.togetherKnowMeSkipped : round.ownAnswer(item),
                    style: (isVoid ? text.bodySmall : text.bodyLarge)?.copyWith(
                      color: isVoid ? t.textTertiary : t.textPrimary,
                      fontWeight: isVoid ? null : FontWeight.w600,
                    ),
                  ),
                  if (!isVoid)
                    Text(
                      '${l.togetherKnowMeGuessOf(tx.name(guesser))}: ${guess.isEmpty ? l.togetherKnowMeNoGuess : guess}',
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                ],
              ),
            ),
            if (verdict != null) ...[
              const SizedBox(width: Space.s),
              Tooltip(
                message: st.verdict(verdict),
                child: Icon(
                  switch (verdict) {
                    KnowMeVerdict.exact => Icons.check_circle_rounded,
                    KnowMeVerdict.close => Icons.adjust_rounded,
                    KnowMeVerdict.miss => Icons.cancel_rounded,
                  },
                  size: 20,
                  color: _verdictColor(t, verdict),
                  semanticLabel: st.verdict(verdict),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(round.questions[index].text, style: text.titleSmall?.copyWith(color: t.gold)),
          entry(round.first),
          entry(round.first.other),
        ],
      ),
    );
  }
}

// -------------------------------------------------------- private answers

/// One player's private inputs: a page per question with their own answer
/// and their guess of the other's.
class _PrivateAnswers extends StatefulWidget {
  const _PrivateAnswers({
    super.key,
    required this.round,
    required this.me,
    required this.partner,
    required this.initial,
    required this.lastToAnswer,
    required this.onChanged,
    required this.onDone,
  });

  final KnowMeRound round;
  final TogetherProfile me;
  final TogetherProfile partner;
  final List<KnowMeAnswer>? initial;
  final bool lastToAnswer;
  final ValueChanged<List<KnowMeAnswer>> onChanged;
  final ValueChanged<List<KnowMeAnswer>> onDone;

  @override
  State<_PrivateAnswers> createState() => _PrivateAnswersState();
}

class _PrivateAnswersState extends State<_PrivateAnswers> {
  late final int _count = widget.round.questions.length;
  late final List<TextEditingController> _own = [
    for (var i = 0; i < _count; i++) TextEditingController(text: widget.initial?.elementAtOrNull(i)?.own ?? ''),
  ];
  late final List<TextEditingController> _guess = [
    for (var i = 0; i < _count; i++) TextEditingController(text: widget.initial?.elementAtOrNull(i)?.guess ?? ''),
  ];
  final PageController _pages = PageController();
  int _page = 0;

  List<KnowMeAnswer> get _answers => [
    for (var i = 0; i < _count; i++) KnowMeAnswer(own: _own[i].text, guess: _guess[i].text),
  ];

  @override
  void dispose() {
    for (final c in [..._own, ..._guess]) {
      c.dispose();
    }
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _page = page);
    if (_pages.hasClients) {
      unawaited(_pages.animateToPage(page, duration: context.motion(MadarMotion.medium), curve: MadarMotion.standard));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final tx = st.tx;
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final color = TogetherLook.colorOf(widget.me);
    final last = _page == _count - 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.1),
          radius: 1.3,
          colors: [Color.lerp(color, t.space0, 0.7)!, t.space0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(56, Space.s, Space.gutter, Space.s),
              child: Row(
                children: [
                  TogetherAvatarView(profile: widget.me, displayName: tx.rawName(widget.me), size: 34),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      tx.rawName(widget.me),
                      style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    l.togetherKnowMeQuestionOf(tx.n(_page + 1), tx.n(_count)),
                    style: text.labelMedium?.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: _Dots(count: _count, index: _page, color: color),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _count,
                itemBuilder: (context, i) => SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.l),
                  child: GlassPanel(
                    seed: i.toDouble(),
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xl, Space.l, Space.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.favorite_rounded, color: t.gold, size: 22),
                        const SizedBox(height: Space.s),
                        Text(
                          widget.round.questions[i].text,
                          key: ValueKey('knowme-question-$i'),
                          style: text.headlineSmall?.copyWith(color: t.textPrimary, height: 1.35),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Space.xl),
                        FieldShell(
                          label: l.togetherKnowMeYourAnswer,
                          icon: Icons.person_rounded,
                          child: _AnswerField(
                            key: ValueKey('knowme-own-$i'),
                            controller: _own[i],
                            hint: l.togetherKnowMeYourAnswerHint,
                            onChanged: () => widget.onChanged(_answers),
                          ),
                        ),
                        const SizedBox(height: Space.l),
                        FieldShell(
                          label: l.togetherKnowMeYourGuess(tx.name(widget.partner)),
                          icon: Icons.psychology_alt_rounded,
                          child: _AnswerField(
                            key: ValueKey('knowme-guess-$i'),
                            controller: _guess[i],
                            hint: l.togetherKnowMeGuessHint,
                            last: true,
                            onChanged: () => widget.onChanged(_answers),
                            onSubmitted: last ? null : () => _go(i + 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_off_rounded, size: 16, color: t.textTertiary),
                  const SizedBox(width: Space.xs),
                  Flexible(
                    child: Text(
                      l.togetherKnowMeHiddenNote,
                      style: text.labelSmall?.copyWith(color: t.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.m),
              child: Row(
                children: [
                  if (_page > 0) ...[
                    MadarButton(
                      key: const ValueKey('knowme-prev'),
                      label: l.togetherKnowMeBack,
                      variant: MadarButtonVariant.ghost,
                      sfx: Sfx.back,
                      onPressed: () => _go(_page - 1),
                    ),
                    const SizedBox(width: Space.s),
                  ],
                  Expanded(
                    child: MadarButton(
                      key: ValueKey(last ? 'knowme-submit' : 'knowme-page-next'),
                      label: last
                          ? (widget.lastToAnswer ? l.togetherKnowMeDoneReveal : l.togetherKnowMeDonePass)
                          : l.togetherKnowMeNext,
                      icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      size: MadarButtonSize.large,
                      expand: true,
                      sfx: last ? Sfx.complete : Sfx.tap,
                      onPressed: last ? () => widget.onDone(_answers) : () => _go(_page + 1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A private answer field: the keyboard is asked not to learn, correct or
/// suggest (Android's incognito input), so the next player's suggestion
/// bar never shows what was typed.
class _AnswerField extends StatelessWidget {
  const _AnswerField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.last = false,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final VoidCallback? onSubmitted;
  final bool last;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    enableSuggestions: false,
    autocorrect: false,
    enableIMEPersonalizedLearning: false,
    keyboardType: TextInputType.text,
    textCapitalization: TextCapitalization.sentences,
    textInputAction: last && onSubmitted == null ? TextInputAction.done : TextInputAction.next,
    minLines: 1,
    maxLines: 2,
    inputFormatters: [LengthLimitingTextInputFormatter(SpecialsBounds.maxAnswerLength)],
    decoration: kitInputDecoration(context, hint: hint),
    onChanged: (_) => onChanged(),
    onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.color});

  final int count;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i <= index ? color : t.glassBorder,
                  boxShadow: i == index ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)] : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- reveal

/// Live scores of the reveal – only from guesses already turned over.
class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.round, required this.profiles, required this.revealed});

  final KnowMeRound round;
  final TogetherProfiles profiles;
  final Set<KnowMeItem> revealed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    Widget side(TogetherProfile p, {required bool start}) {
      final children = [
        TogetherAvatarView(profile: p, displayName: tx.rawName(p), size: 36, ring: false),
        const SizedBox(width: Space.s),
        Flexible(
          child: Text(
            tx.rawName(p),
            style: text.labelLarge?.copyWith(color: t.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Space.s),
        RollingNumber(
          value: round.revealedScoreOf(p.slot, revealed),
          formatter: (v) => tx.n(v.round()),
          style: text.titleLarge?.copyWith(color: TogetherLook.colorOf(p), fontWeight: FontWeight.w700),
        ),
      ];
      return Expanded(
        child: Row(
          mainAxisAlignment: start ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: start ? children : children.reversed.toList(),
        ),
      );
    }

    return Semantics(
      container: true,
      label:
          '${tx.name(profiles.one)} ${tx.n(round.revealedScoreOf(PlayerSlot.one, revealed))}, '
          '${tx.name(profiles.two)} ${tx.n(round.revealedScoreOf(PlayerSlot.two, revealed))}',
      excludeSemantics: true,
      child: GlassCard(
        key: const ValueKey('knowme-scoreboard'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
        child: Row(
          children: [
            side(profiles.one, start: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s),
              child: Icon(Icons.favorite_rounded, size: 16, color: t.gold),
            ),
            side(profiles.two, start: false),
          ],
        ),
      ),
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader({required this.index, required this.total, required this.text});

  final int index;
  final int total;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final style = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          st.l.togetherKnowMeQuestionOf(st.n(index + 1), st.n(total)),
          style: style.labelMedium?.copyWith(color: t.gold, letterSpacing: st.tx.arabic ? 0 : 1),
        ),
        const SizedBox(height: Space.xs),
        Text(
          text,
          key: const ValueKey('knowme-reveal-question'),
          style: style.headlineSmall?.copyWith(color: t.textPrimary, height: 1.35),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// One guess: the subject's answer and the guesser's guess, face down until
/// revealed; then the subject's verdict.
class _RevealCard extends StatelessWidget {
  const _RevealCard({
    super.key,
    required this.round,
    required this.item,
    required this.profiles,
    required this.shown,
    required this.onReveal,
    required this.onJudge,
  });

  final KnowMeRound round;
  final KnowMeItem item;
  final TogetherProfiles profiles;
  final bool shown;
  final VoidCallback onReveal;
  final ValueChanged<KnowMeVerdict> onJudge;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final tx = st.tx;
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final subject = profiles.of(item.subject);
    final guesser = profiles.of(item.guesser);
    final isVoid = round.isVoid(item);
    final own = round.ownAnswer(item);
    final guess = round.guessOf(item);
    final verdict = round.verdictOf(item);
    final suggestion = round.suggestion(item);

    Widget line(TogetherProfile p, String label, String value, {required bool empty, required int flip}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TogetherAvatarView(profile: p, displayName: tx.rawName(p), size: 28, ring: false),
        const SizedBox(width: Space.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelSmall?.copyWith(color: t.textTertiary)),
              const SizedBox(height: 2),
              AnimatedSwitcher(
                duration: context.motion(MadarMotion.medium),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child),
                ),
                child: shown
                    ? Text(
                        value,
                        key: ValueKey('shown-$flip'),
                        style: (empty ? text.bodyMedium : text.titleMedium)?.copyWith(
                          color: empty ? t.textTertiary : t.textPrimary,
                          fontWeight: empty ? FontWeight.w400 : FontWeight.w700,
                          fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                        ),
                      )
                    : Container(
                        key: ValueKey('hidden-$flip'),
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.xxs),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(t.radiusS),
                          color: t.glassBorder.withValues(alpha: 0.35),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 14, color: t.textTertiary),
                            const SizedBox(width: Space.xs),
                            Flexible(
                              child: Text(
                                l.togetherKnowMeHiddenAnswer,
                                style: text.bodySmall?.copyWith(color: t.textTertiary),
                              ),
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

    return GlassCard(
      borderColor: shown && verdict != null ? _verdictColor(t, verdict).withValues(alpha: 0.7) : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(
            subject,
            l.togetherKnowMeAnswerOf(tx.name(subject)),
            isVoid ? l.togetherKnowMeSkipped : own,
            empty: isVoid,
            flip: 0,
          ),
          const SizedBox(height: Space.m),
          line(
            guesser,
            l.togetherKnowMeGuessOf(tx.name(guesser)),
            guess.isEmpty ? l.togetherKnowMeNoGuess : guess,
            empty: guess.isEmpty,
            flip: 1,
          ),
          const SizedBox(height: Space.m),
          if (!shown)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: MadarButton(
                key: ValueKey('knowme-reveal-${item.index}-${item.subject.name}'),
                label: l.togetherKnowMeRevealButton,
                icon: Icons.visibility_rounded,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.secondary,
                sfx: Sfx.swipe,
                onPressed: onReveal,
              ),
            )
          else if (!isVoid) ...[
            Text(
              l.togetherKnowMeJudgePrompt(tx.name(subject)),
              style: text.labelLarge?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: Space.s),
            Row(
              children: [
                for (final v in KnowMeVerdict.values) ...[
                  if (v != KnowMeVerdict.exact) const SizedBox(width: Space.s),
                  Expanded(
                    child: _VerdictButton(
                      key: ValueKey('knowme-judge-${item.index}-${item.subject.name}-${v.name}'),
                      verdict: v,
                      selected: verdict == v,
                      suggested: suggestion == v && !round.isJudged(item),
                      // A blank guess has nothing to judge.
                      enabled: guess.isNotEmpty,
                      onTap: () => onJudge(v),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Color _verdictColor(MadarTokens t, KnowMeVerdict v) => switch (v) {
  KnowMeVerdict.exact => t.success,
  KnowMeVerdict.close => t.warning,
  KnowMeVerdict.miss => t.textTertiary,
};

class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    super.key,
    required this.verdict,
    required this.selected,
    required this.suggested,
    required this.enabled,
    required this.onTap,
  });

  final KnowMeVerdict verdict;
  final bool selected;
  final bool suggested;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final text = Theme.of(context).textTheme;
    final color = _verdictColor(t, verdict);
    final label = st.verdict(verdict);
    final points = '+${st.n(verdict.points)}';
    return MadarPressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      selected: selected,
      sfx: verdict == KnowMeVerdict.exact ? Sfx.sparkle : Sfx.tap,
      semanticLabel: '$label $points${suggested ? ' (${st.l.togetherKnowMeSuggested})' : ''}',
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.xs, vertical: Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          color: selected ? color.withValues(alpha: t.isDark ? 0.28 : 0.18) : t.glassFill,
          border: Border.all(
            color: selected
                ? color
                : suggested
                ? color.withValues(alpha: 0.7)
                : t.glassBorder,
            width: selected || suggested ? 1.4 : 1,
          ),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12)] : null,
        ),
        child: Opacity(
          opacity: enabled || selected ? 1 : 0.45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: text.labelLarge?.copyWith(
                    color: selected ? t.textPrimary : t.textSecondary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                ),
              ),
              Text(points, style: text.labelSmall?.copyWith(color: selected ? color : t.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }
}
