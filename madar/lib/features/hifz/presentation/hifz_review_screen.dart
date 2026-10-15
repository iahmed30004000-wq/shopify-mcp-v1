import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/quran/quran_audio.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../../wird/data/wird_providers.dart';
import '../../wird/domain/calendar_days.dart';
import '../data/hifz_providers.dart';
import '../data/hifz_service.dart';
import '../domain/hifz_models.dart';
import '../domain/hifz_reveal.dart';
import 'hifz_labels.dart';
import 'widgets/hifz_grade_bar.dart';
import 'widgets/hifz_reveal_text.dart';

/// The review session: one card at a time – recite from memory, reveal
/// (first letters → word by word → all; tap the text for the next word),
/// listen to a reciter repeat the ayat, grade yourself 0–5 (SM-2), undo the
/// last grade; cards graded below "good" come back once more at the end.
/// Ends with a summary; the session is logged as `quran.hifz`.
///
/// Reviews today's queue, or only [only].
class HifzReviewScreen extends ConsumerStatefulWidget {
  const HifzReviewScreen({super.key, this.only, this.animateBackdrop = true});

  final HifzCard? only;
  final bool animateBackdrop;

  @override
  ConsumerState<HifzReviewScreen> createState() => _HifzReviewScreenState();
}

class _HifzReviewScreenState extends ConsumerState<HifzReviewScreen> {
  HifzReviewController? _controller;
  HifzReveal? _reveal;
  String? _revealFor;
  bool _celebrated = false;
  QuranAudio? _audio;

  @override
  void dispose() {
    final c = _controller;
    if (c != null) {
      unawaited(c.finish());
      c.dispose();
    }
    unawaited(_audio?.stop());
    super.dispose();
  }

  HifzReviewController? _ensureController() {
    if (_controller != null) return _controller;
    final queue = widget.only != null ? [widget.only!] : ref.read(hifzQueueProvider).value;
    if (queue == null) return null;
    final c = HifzReviewController(
      service: ref.read(hifzServiceProvider),
      queue: queue,
      clock: ref.read(wirdClockProvider),
    );
    c.addListener(() {
      if (mounted) setState(() {});
    });
    return _controller = c;
  }

  Future<void> _grade(int q) async {
    final c = _controller;
    if (c == null) return;
    unawaited(_audio?.stop());
    await c.grade(q);
    if (!mounted) return;
    if (c.session.isComplete && !_celebrated) {
      _celebrated = true;
      Fx.fire(Sfx.levelUp);
      Celebrate.burst(context, MediaQuery.sizeOf(context).center(Offset.zero), kind: CelebrationKind.orbitalRing);
    }
  }

  Future<void> _undo() async {
    final c = _controller;
    if (c == null) return;
    final o = await c.undo();
    if (o != null && mounted) {
      Fx.fire(Sfx.undo);
      setState(() {
        _celebrated = false;
        _revealFor = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    _audio ??= ref.read(quranAudioProvider);
    // Wait for the queue once; after that the session owns its cards.
    if (_controller == null && widget.only == null) {
      ref.watch(hifzQueueProvider);
    }
    final c = _ensureController();
    return MadarScaffold(
      title: l.hifzReviewTitle,
      backdropSeed: 11.2,
      animateBackdrop:
          widget.animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        if (c != null && !c.session.isComplete)
          MadarButton.icon(
            icon: Icons.undo_rounded,
            onPressed: c.session.canUndo && !c.busy ? _undo : null,
            semanticLabel: l.hifzUndoGrade,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.undo,
          ),
      ],
      body: c == null
          ? const Center(child: OrbitLoader(size: 40))
          : c.session.length == 0
          ? Center(
              child: AnimatedEmptyState(
                kind: EmptyStateKind.noResults,
                title: l.hifzEmptySession,
                body: l.hifzAllCaughtUp,
              ),
            )
          : c.session.isComplete
          ? _Summary(controller: c)
          : _card(context, c),
    );
  }

  Widget _card(BuildContext context, HifzReviewController c) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final item = c.session.current!;
    final card = item.card;
    final today = ref.watch(wirdTodayProvider);
    final texts = HifzTexts(
      l,
      fmt,
      catalog: ref.watch(quranCatalogReadyProvider).value,
      hadith: ref.watch(hadithCollectionProvider).value,
    );
    final tokens = ref.watch(hifzTokensProvider(card)).value;
    final key = '${card.id}#${c.session.position}';
    if (_revealFor != key && tokens != null) {
      _revealFor = key;
      _reveal = HifzReveal(words: tokens.where((t) => !t.marker).length);
    }
    final reveal = _reveal;
    final settings = ref.watch(hifzSettingsProvider).value ?? const HifzSettings();
    final entry = texts.entryOf(card);
    final quran = card.kind == HifzKind.ayat;
    final style = quran
        ? MadarTypography.quran(t, size: 26).copyWith(height: 2.05)
        : TextStyle(fontFamily: MadarTypography.naskhFamily, fontSize: 21, height: 1.95, color: t.textPrimary);
    final last = c.last;

    void setReveal(HifzReveal r) {
      Fx.fire(r.isFull ? Sfx.sparkle : Sfx.tap);
      setState(() => _reveal = r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.s),
          child: _ProgressHeader(
            position: c.session.position,
            length: c.session.length,
            note: last == null || last.after == null
                ? null
                : l.hifzNextReview(fmt.localizeDigits(l.hifzDueIn(CalendarDays.between(today, last.after!.due!)))),
          ),
        ),
        Expanded(
          child: ShaderMask(
            // Soft edges where the card scrolls under the header and the
            // controls.
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
              stops: [0, (10 / rect.height).clamp(0.0, 0.5), (1 - 24 / rect.height).clamp(0.5, 1.0), 1],
            ).createShader(rect),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.l),
              child: AnimatedSwitcher(
                duration: context.motion(MadarMotion.medium),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
                    child: child,
                  ),
                ),
                child: GlassPanel(
                  key: ValueKey(key),
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(hifzKindIcon(card.kind), size: 16, color: t.brass),
                          const SizedBox(width: Space.xs),
                          Text(texts.kind(card.kind), style: text.labelMedium!.copyWith(color: t.brass)),
                          const Spacer(),
                          if (item.redrill)
                            _Chip(label: l.hifzRedrill, color: t.warning)
                          else if (card.isNew)
                            _Chip(label: l.hifzNewItem, color: t.info),
                        ],
                      ),
                      const SizedBox(height: Space.s),
                      Text(texts.title(card), style: text.headlineSmall, textAlign: TextAlign.center),
                      Text(texts.subtitle(card), style: text.bodySmall, textAlign: TextAlign.center),
                      const MadarDivider(),
                      if (tokens == null || reveal == null)
                        const Padding(
                          padding: EdgeInsets.all(Space.xl),
                          child: Center(child: OrbitLoader(size: 32)),
                        )
                      else
                        HifzRevealText(
                          tokens: tokens,
                          reveal: reveal,
                          style: style,
                          markerStyle: quran ? style.copyWith(color: t.brass) : null,
                          semanticsLabel: l.hifzRecitePrompt,
                          onTap: reveal.isFull ? null : () => setReveal(reveal.nextWord()),
                        ),
                      if (entry != null && entry.takhrij.isNotEmpty && (reveal?.isFull ?? false)) ...[
                        const SizedBox(height: Space.m),
                        Text(
                          entry.takhrij,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: text.bodySmall!.copyWith(
                            fontFamily: MadarTypography.naskhFamily,
                            color: t.textTertiary,
                          ),
                        ),
                      ],
                      if (!(reveal?.isFull ?? false)) ...[
                        const SizedBox(height: Space.m),
                        Text(
                          l.hifzRecitePrompt,
                          textAlign: TextAlign.center,
                          style: text.labelSmall!.copyWith(color: t.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.s),
          // Wraps onto two lines when the labels are long (large text,
          // English).
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Space.s,
            runSpacing: Space.xs,
            children: [
              if (quran && card.range != null)
                _ListenButton(
                  audio: _audio!,
                  repeat: settings.listenRepeat,
                  onPlay: () => _audio!.play(card.range!, repeatAyah: settings.listenRepeat),
                )
              else
                const SizedBox.shrink(),
              if (reveal != null && !reveal.isFull)
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    if (!reveal.showsFirstLetters)
                      MadarButton(
                        label: l.hifzRevealFirstLetters,
                        size: MadarButtonSize.small,
                        variant: MadarButtonVariant.ghost,
                        onPressed: () => setReveal(reveal.firstLetters()),
                      )
                    else
                      MadarButton(
                        label: l.hifzRevealNextWord,
                        size: MadarButtonSize.small,
                        variant: MadarButtonVariant.ghost,
                        onPressed: () => setReveal(reveal.nextWord()),
                      ),
                    MadarButton(
                      label: l.hifzRevealAll,
                      icon: Icons.visibility_rounded,
                      size: MadarButtonSize.small,
                      variant: MadarButtonVariant.secondary,
                      onPressed: () => setReveal(reveal.all()),
                    ),
                  ],
                )
              else if (reveal != null)
                MadarButton(
                  label: l.hifzRevealHide,
                  icon: Icons.visibility_off_rounded,
                  size: MadarButtonSize.small,
                  variant: MadarButtonVariant.ghost,
                  onPressed: () => setReveal(reveal.hide()),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.hifzGradePrompt, style: text.titleSmall, textAlign: TextAlign.center),
              const SizedBox(height: Space.s),
              HifzGradeBar(onGrade: _grade, enabled: !c.busy),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.position, required this.length, this.note});

  final int position;
  final int length;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: length == 0 ? 0 : position / length),
                  duration: context.motion(MadarMotion.medium),
                  curve: MadarMotion.standard,
                  builder: (context, v, _) =>
                      LinearProgressIndicator(value: v, minHeight: 5, color: t.accent, backgroundColor: t.glassBorder),
                ),
              ),
            ),
            const SizedBox(width: Space.m),
            Text(
              l.hifzReviewProgress(fmt.formatInt(position + 1), fmt.formatInt(length)),
              style: text.labelMedium!.copyWith(color: t.textSecondary),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: context.motion(MadarMotion.short),
          child: note == null
              ? const SizedBox(height: 18)
              : Padding(
                  key: ValueKey(note),
                  padding: const EdgeInsetsDirectional.only(top: Space.xxs),
                  child: Text(note!, style: text.labelSmall!.copyWith(color: t.success)),
                ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: color)),
  );
}

/// Plays the item's ayat with the user's reciter, each repeated N times.
class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.audio, required this.repeat, required this.onPlay});

  final QuranAudio audio;
  final int repeat;
  final Future<void> Function() onPlay;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    return StreamBuilder<QuranPlayback>(
      stream: audio.playback,
      initialData: audio.value,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;
        return MadarButton(
          label: playing ? l.hifzListenStop : '${l.hifzListen} ×${fmt.formatInt(repeat)}',
          icon: playing ? Icons.stop_rounded : Icons.headphones_rounded,
          size: MadarButtonSize.small,
          variant: MadarButtonVariant.secondary,
          sfx: playing ? Sfx.toggleOff : Sfx.toggleOn,
          semanticLabel: playing
              ? l.hifzListenStop
              : '${l.hifzListen}, ${fmt.localizeDigits(l.hifzRepeatTimes(repeat))}',
          onPressed: () => playing ? audio.stop() : onPlay(),
        );
      },
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.controller});

  final HifzReviewController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final s = controller.session.summary;
    final cards = ref.watch(hifzCardsProvider).value ?? const <HifzCard>[];
    final tomorrow = controller.dueTomorrow(cards, ref.watch(wirdTodayProvider));
    Widget stat(String value, String label, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: MadarTypography.numerals(t, size: 26, color: color).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: Space.xxs),
          Text(label, style: text.labelMedium, textAlign: TextAlign.center),
        ],
      ),
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.gutter),
        child: StaggerIn(
          id: 'hifz-summary',
          children: [
            Center(child: GirihRosette(size: 120, rotation: 0.2)),
            const SizedBox(height: Space.l),
            Text(l.hifzSummaryTitle, style: text.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: Space.xs),
            Text(
              l.hifzSummarySubtitle,
              style: text.bodyMedium!.copyWith(color: t.textSecondary, fontFamily: MadarTypography.naskhFamily),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.xl),
            GlassPanel(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.l, Space.m, Space.l),
              child: Row(
                children: [
                  stat(fmt.formatInt(s.reviewed), l.hifzSummaryReviewed, t.accent),
                  stat(fmt.formatInt(s.learnedNew), l.hifzSummaryNew, t.info),
                  stat(fmt.formatInt(s.redrills), l.hifzSummaryAgain, t.warning),
                  stat(s.recalled == null ? '—' : fmt.formatPercent(s.recalled!), l.hifzSummaryRecall, t.success),
                ],
              ),
            ),
            const SizedBox(height: Space.m),
            Text(l.hifzSummaryTomorrow(fmt.formatInt(tomorrow)), textAlign: TextAlign.center, style: text.bodySmall),
            const SizedBox(height: Space.xl),
            MadarButton(
              label: l.hifzSummaryDone,
              icon: Icons.check_rounded,
              expand: true,
              sfx: Sfx.back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
