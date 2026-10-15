import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/adhkar_providers.dart';
import '../data/dhikr_audio.dart';
import '../data/dhikr_playback.dart';
import '../domain/adhkar_models.dart';
import '../domain/adhkar_session.dart';
import '../domain/adhkar_timing.dart';
import 'adhkar_labels.dart';
import 'widgets/dhikr_text.dart';
import 'widgets/reader_sheets.dart';
import 'widgets/reader_widgets.dart';

/// The focused reader of one adhkar set: one dhikr per page in large Amiri,
/// a counter ring (tap it, or anywhere on the page) with a tick and haptic
/// per repetition, a chime and gentle sparks when a dhikr is complete and a
/// glide to the next one, progress across the set, and today's progress
/// resumed where it was left.
///
/// [prayer] picks the after-prayer set's prayer (default: the prayer most
/// recently due); it is ignored for the other sets. [onDone] runs from the
/// completion card's "Done" (default: pops the route).
class AdhkarReaderScreen extends ConsumerStatefulWidget {
  const AdhkarReaderScreen({super.key, required this.category, this.prayer, this.onDone});

  final AdhkarCategoryId category;
  final Prayer? prayer;
  final VoidCallback? onDone;

  @override
  ConsumerState<AdhkarReaderScreen> createState() => _AdhkarReaderScreenState();
}

class _AdhkarReaderScreenState extends ConsumerState<AdhkarReaderScreen> {
  Prayer? _prayer;
  PageController? _pages;
  AdhkarSetKey? _pagesFor;
  Timer? _advanceTimer;
  Timer? _overlayTimer;
  bool _overlay = false;
  bool _animating = false;
  final GlobalKey _ringKey = GlobalKey();

  bool get _afterPrayer => widget.category == AdhkarCategoryId.afterPrayer;

  AdhkarSetKey get _key => AdhkarSetKey(widget.category, _afterPrayer ? _prayer : null);

  AdhkarSessionController get _ctrl => ref.read(adhkarSessionProvider(_key).notifier);

  AdhkarSession? get _session => ref.read(adhkarSessionProvider(_key)).value;

  @override
  void initState() {
    super.initState();
    if (_afterPrayer) _prayer = widget.prayer ?? AdhkarTiming.lastPrayer(ref.read(adhkarWindowProvider));
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _overlayTimer?.cancel();
    _pages?.dispose();
    super.dispose();
  }

  PageController _controllerFor(AdhkarSession s) {
    if (_pages == null || _pagesFor != s.key) {
      final old = _pages;
      if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      _pages = PageController(initialPage: s.index);
      _pagesFor = s.key;
      _overlay = s.isComplete;
    }
    return _pages!;
  }

  Future<void> _animateTo(int index) async {
    final pages = _pages;
    if (pages == null || !pages.hasClients) return;
    if ((pages.page ?? pages.initialPage.toDouble()).round() == index) return;
    _animating = true;
    try {
      if (context.reducedMotion) {
        pages.jumpToPage(index);
      } else {
        await pages.animateToPage(index, duration: MadarMotion.long, curve: MadarMotion.emphasized);
      }
    } finally {
      _animating = false;
    }
  }

  void _burst(CelebrationKind kind, double intensity) {
    final ctx = _ringKey.currentContext;
    if (ctx != null) Celebrate.burstFrom(ctx, kind: kind, intensity: intensity);
  }

  /// One tap on the counter or the page.
  Future<void> _count() async {
    final s = _session;
    if (s == null || _overlay || s.length == 0) return;
    if (s.isDoneAt(s.index)) {
      if (s.nextIncompleteAfter(s.index) != null) {
        Fx.fire(Sfx.swipe);
        await _advanceNow();
      } else {
        Fx.fire(Sfx.tap);
      }
      return;
    }
    // Sound first (no await before it): a tick, the chime on the last
    // repetition, the rising "level" sound when the whole set completes.
    final last = s.remainingAt(s.index) == 1;
    // (nextIncompleteAfter would wrap round to this still-open dhikr.)
    final setEnds = last && s.doneCount == s.length - 1;
    Fx.fire(last ? (setEnds ? Sfx.levelUp : Sfx.complete) : Sfx.countTick);
    final outcome = await _ctrl.tap();
    if (!mounted) return;
    switch (outcome) {
      case AdhkarTapOutcome.dhikrCompleted:
        _burst(CelebrationKind.lanternSparks, 0.5);
        _advanceTimer?.cancel();
        _advanceTimer = Timer(
          context.reducedMotion ? const Duration(milliseconds: 260) : const Duration(milliseconds: 720),
          () => unawaited(_advanceNow()),
        );
      case AdhkarTapOutcome.setCompleted:
        _burst(CelebrationKind.orbitalRing, 1);
        _overlayTimer?.cancel();
        _overlayTimer = Timer(context.motion(const Duration(milliseconds: 650)), () {
          if (mounted) setState(() => _overlay = true);
        });
      case AdhkarTapOutcome.counted || AdhkarTapOutcome.alreadyDone:
        break;
    }
  }

  Future<void> _advanceNow() async {
    _advanceTimer?.cancel();
    await _ctrl.advance();
    final s = _session;
    if (s != null && mounted) await _animateTo(s.index);
  }

  Future<void> _goTo(int index) async {
    _advanceTimer?.cancel();
    await _ctrl.goTo(index);
    if (mounted) await _animateTo(index);
  }

  void _onPageChanged(int index) {
    if (_animating) return;
    _advanceTimer?.cancel();
    Fx.fire(Sfx.swipe);
    unawaited(_ctrl.goTo(index));
  }

  Future<void> _options(AdhkarSession s) async {
    final l = L10n.of(context);
    final name = l.adhkarCategoryName(widget.category);
    final action = await showAdhkarReaderOptions(context, current: s.current, complete: s.isComplete);
    if (action == null || !mounted) return;
    switch (action) {
      case AdhkarReaderAction.audio:
        await showDhikrAudioSheet(context, dhikr: s.current);
      case AdhkarReaderAction.recount:
        Fx.fire(Sfx.undo);
        await _ctrl.resetCurrent();
        if (mounted) setState(() => _overlay = false);
      case AdhkarReaderAction.restart:
        final before = s.index;
        Fx.fire(Sfx.delete);
        final undo = await _ctrl.resetAll();
        if (!mounted) return;
        setState(() => _overlay = false);
        await _animateTo(0);
        if (!mounted) return;
        unawaited(
          showUndoToast(
            context,
            UndoableAction(
              label: l.adhkarRestarted(name),
              undo: () async {
                await undo();
                if (!mounted) return;
                setState(() => _overlay = _session?.isComplete ?? false);
                await _animateTo(before);
              },
            ),
          ),
        );
      case AdhkarReaderAction.markDone:
        Fx.fire(Sfx.levelUp);
        final undo = await _ctrl.markDone();
        if (!mounted) return;
        _burst(CelebrationKind.orbitalRing, 1);
        setState(() => _overlay = true);
        unawaited(
          showUndoToast(
            context,
            UndoableAction(
              label: l.adhkarMarkedDone(name),
              undo: () async {
                await undo();
                if (mounted) setState(() => _overlay = false);
              },
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final session = ref.watch(adhkarSessionProvider(_key));
    final s = session.value;
    return MadarScaffold(
      title: l.adhkarCategoryName(widget.category),
      actions: [
        if (s != null)
          MadarButton.icon(
            icon: Icons.tune_rounded,
            variant: MadarButtonVariant.ghost,
            semanticLabel: l.adhkarOptionsTitle,
            onPressed: () => unawaited(_options(s)),
          ),
      ],
      body: Column(
        children: [
          if (_afterPrayer)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: ChoicePills<Prayer>.single(
                options: [for (final p in kObligatoryPrayers) ChoiceOption(value: p, label: l.adhkarPrayerName(p))],
                selected: _prayer,
                onChanged: (p) {
                  if (p == null || p == _prayer) return;
                  _advanceTimer?.cancel();
                  ref.read(dhikrPlaybackProvider.notifier).stop();
                  setState(() => _prayer = p);
                },
                scrollable: true,
                dense: true,
                padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
              ),
            ),
          Expanded(
            child: switch (session) {
              AsyncData(:final value) => _Reader(
                key: ValueKey(value.key),
                session: value,
                pages: _controllerFor(value),
                overlay: _overlay,
                ringKey: _ringKey,
                onCount: () => unawaited(_count()),
                onPageChanged: _onPageChanged,
                onJump: (i) => unawaited(_goTo(i)),
                onReview: () => setState(() => _overlay = false),
                onDone: widget.onDone ?? () => Navigator.of(context).maybePop(),
              ),
              AsyncError() => Center(
                child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.adhkarLoadError, body: ''),
              ),
              _ => const Center(child: OrbitLoader(size: 40)),
            },
          ),
        ],
      ),
    );
  }
}

/// The reader body for one loaded session.
class _Reader extends ConsumerWidget {
  const _Reader({
    super.key,
    required this.session,
    required this.pages,
    required this.overlay,
    required this.ringKey,
    required this.onCount,
    required this.onPageChanged,
    required this.onJump,
    required this.onReview,
    required this.onDone,
  });

  final AdhkarSession session;
  final PageController pages;
  final bool overlay;
  final GlobalKey ringKey;
  final VoidCallback onCount;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onJump;
  final VoidCallback onReview;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final prefs = ref.watch(adhkarReaderPrefsProvider).value ?? const AdhkarReaderPrefs();
    final audio = ref.watch(dhikrAudioInfoProvider).value ?? const <String, DhikrAudioInfo>{};
    final playing = ref.watch(dhikrPlaybackProvider);
    final s = session;
    final i = s.index;
    final target = s.targetAt(i);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
          child: Row(
            children: [
              Text(
                l.adhkarReaderPosition(fmt.formatInt(i + 1), fmt.formatInt(s.length)),
                style: text.labelLarge!.copyWith(color: t.textSecondary),
              ),
              const Spacer(),
              if (s.current.kind == DhikrKind.recite)
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.xxs),
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(t.radiusS),
                    border: Border.all(color: t.glassBorder),
                  ),
                  child: Text(
                    fmt.localizeDigits(l.adhkarRepeat(target)),
                    style: text.labelMedium!.copyWith(color: t.accent),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
          child: AdhkarSetProgressBar(session: s, onJump: onJump),
        ),
        Expanded(
          child: Stack(
            children: [
              // The page recedes while the completion card is up.
              AnimatedOpacity(
                opacity: overlay ? 0.12 : 1,
                duration: context.motion(MadarMotion.medium),
                child: PageView.builder(
                  controller: pages,
                  itemCount: s.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (context, p) => _DhikrPage(
                    dhikr: s.items[p],
                    prefs: prefs,
                    audio: audio[s.items[p].id],
                    playing: playing == s.items[p].id,
                    onCount: onCount,
                    onAudio: () async {
                      final ok = await ref.read(dhikrPlaybackProvider.notifier).toggle(s.items[p].id);
                      if (!ok) Fx.fire(Sfx.error);
                    },
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !overlay,
                  child: AnimatedOpacity(
                    opacity: overlay ? 1 : 0,
                    duration: context.motion(MadarMotion.medium),
                    child: overlay
                        ? DecoratedBox(
                            // A soft veil so the card never competes with the page behind it.
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                radius: 0.9,
                                colors: [
                                  context.tokens.space0.withValues(alpha: 0.7),
                                  context.tokens.space0.withValues(alpha: 0),
                                ],
                              ),
                            ),
                            child: _CompletionCard(session: s, onReview: onReview, onDone: onDone),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedOpacity(
          opacity: overlay ? 0.35 : 1,
          duration: context.motion(MadarMotion.medium),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    MadarButton.icon(
                      icon: Icons.chevron_left_rounded,
                      variant: MadarButtonVariant.ghost,
                      semanticLabel: l.adhkarPrevious,
                      onPressed: i > 0 && !overlay ? () => onJump(i - 1) : null,
                    ),
                    KeyedSubtree(
                      key: ringKey,
                      child: AdhkarCounterRing(
                        count: s.countAt(i),
                        target: target,
                        reading: s.current.kind == DhikrKind.reading,
                        onTap: overlay ? null : onCount,
                      ),
                    ),
                    MadarButton.icon(
                      icon: Icons.chevron_right_rounded,
                      variant: MadarButtonVariant.ghost,
                      semanticLabel: l.adhkarNext,
                      onPressed: i < s.length - 1 && !overlay ? () => onJump(i + 1) : null,
                    ),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Text(l.adhkarCounterHint, style: text.labelSmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One dhikr on its page. A tap anywhere counts.
class _DhikrPage extends StatelessWidget {
  const _DhikrPage({
    required this.dhikr,
    required this.prefs,
    required this.audio,
    required this.playing,
    required this.onCount,
    required this.onAudio,
  });

  final Dhikr dhikr;
  final AdhkarReaderPrefs prefs;
  final DhikrAudioInfo? audio;
  final bool playing;
  final VoidCallback onCount;
  final VoidCallback onAudio;

  static TextDirection _dirOf(String s) => Bidi.detectRtlDirectionality(s) ? TextDirection.rtl : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final note = dhikr.note?.of(lang);
    final virtue = prefs.showVirtue ? dhikr.virtue?.of(lang) : null;
    final translation = lang == 'en' && prefs.showTranslation ? dhikr.translationEn : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onCount,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xs),
        child: GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(t.radiusXL),
          seed: dhikr.id.hashCode % 97 / 97,
          child: LayoutBuilder(
            builder: (context, c) => _EdgeFade(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.l, Space.xl, Space.xl),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: (c.maxHeight - Space.l - Space.xl).clamp(0, double.infinity)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (note != null || audio != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: Space.m),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (note != null)
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsetsDirectional.only(top: 3),
                                        child: Icon(Icons.info_outline_rounded, size: 16, color: t.accent),
                                      ),
                                      const SizedBox(width: Space.xs),
                                      Expanded(
                                        child: Text(
                                          note,
                                          textDirection: _dirOf(note),
                                          style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const Spacer(),
                              if (audio != null) ...[
                                const SizedBox(width: Space.s),
                                MadarButton.icon(
                                  icon: playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                  size: MadarButtonSize.small,
                                  variant: playing ? MadarButtonVariant.primary : MadarButtonVariant.secondary,
                                  semanticLabel: playing ? l.adhkarAudioStop : l.adhkarAudioPlay,
                                  onPressed: onAudio,
                                ),
                              ],
                            ],
                          ),
                        ),
                      DhikrText(dhikr: dhikr, scale: prefs.textScale),
                      for (final q in dhikr.quranSegments)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: Space.xs),
                          child: Text(
                            l.adhkarQuranReference(q, fmt),
                            textAlign: TextAlign.center,
                            style: text.labelMedium!.copyWith(color: t.accent),
                          ),
                        ),
                      if (translation != null) ...[
                        const MadarDivider(height: 32),
                        Text(
                          translation,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: text.bodyLarge!.copyWith(color: t.textSecondary, height: 1.55),
                        ),
                      ],
                      if (virtue != null) ...[
                        const SizedBox(height: Space.l),
                        Container(
                          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
                          decoration: BoxDecoration(
                            color: t.accentSoft.withValues(alpha: t.accentSoft.a * 0.7),
                            borderRadius: BorderRadius.circular(t.radiusM),
                            border: BorderDirectional(start: BorderSide(color: t.accent, width: 2.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.adhkarVirtue, style: text.labelMedium!.copyWith(color: t.accent)),
                              const SizedBox(height: Space.xxs),
                              Text(
                                virtue,
                                textDirection: _dirOf(virtue),
                                style: text.bodyMedium!.copyWith(color: t.textPrimary, height: 1.6),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (prefs.showVirtue) ...[
                        const SizedBox(height: Space.m),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${l.adhkarReference}: ',
                                style: TextStyle(color: t.textSecondary),
                              ),
                              TextSpan(
                                // Page and hadith numbers follow the digit setting
                                // in either language.
                                text: fmt.isolate(
                                  fmt.localizeDigits(lang == 'ar' ? dhikr.reference.ar : dhikr.reference.of(lang)),
                                ),
                              ),
                            ],
                          ),
                          style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades the top and bottom edges of a scrolling page so text visibly
/// continues under the card's rim.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) {
      final f = rect.height <= 0 ? 0.0 : (22 / rect.height).clamp(0.0, 0.2);
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
        stops: [0, f, 1 - f, 1],
      ).createShader(rect);
    },
    child: child,
  );
}

/// "May Allah accept it from you": shown when the set is complete.
class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.session, required this.onReview, required this.onDone});

  final AdhkarSession session;
  final VoidCallback onReview;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final name = l.adhkarCategoryName(session.key.category);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
        child: AnimatedReveal(
          from: EntranceFrom.bottom,
          child: GlassPanel(
            shareBackdrop: false,
            glowColor: t.accentGlow,
            padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.xl, Space.xl, Space.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const GirihRosette(size: 112),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.space1,
                          border: Border.all(color: t.success, width: 1.5),
                          boxShadow: [BoxShadow(color: t.success.withValues(alpha: 0.45), blurRadius: 18)],
                        ),
                        child: Icon(Icons.check_rounded, color: t.success, size: 26),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.l),
                Text(l.adhkarSetCompleteTitle, textAlign: TextAlign.center, style: text.headlineSmall),
                const SizedBox(height: Space.xs),
                Text(
                  l.adhkarSetCompleteBody(name),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge!.copyWith(color: t.textSecondary),
                ),
                Text(
                  fmt.localizeDigits(l.adhkarItemsCount(session.length)),
                  textAlign: TextAlign.center,
                  style: text.labelMedium!.copyWith(color: t.accent),
                ),
                const SizedBox(height: Space.xl),
                Row(
                  children: [
                    Expanded(
                      child: MadarButton(
                        label: l.adhkarSetCompleteReview,
                        icon: Icons.menu_book_rounded,
                        variant: MadarButtonVariant.secondary,
                        onPressed: onReview,
                      ),
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: MadarButton(label: l.actionDone, icon: Icons.check_rounded, onPressed: onDone),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
