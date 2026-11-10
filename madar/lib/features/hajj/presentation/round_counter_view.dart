import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../data/round_counter_store.dart';
import '../domain/round_counter.dart';

/// What the phone should feel / hear for a tap. The host maps these to its
/// haptics (e.g. light and success); the view has no hard dependency on them.
enum RoundFeedback { counted, completed }

/// The offline round counter for the tawaf and the sa'i, sized as a screen:
/// the whole lower two-thirds is one huge tap target, the round is written
/// big ("الشوط ٤ من ٧"), and every change is saved at once so the count
/// survives the app being killed, a call, or a restart. No network.
///
/// Platform things come in as callbacks so the view stays testable:
/// [onFeedback] (haptics), [keepAwake] (screen wake lock; called with true
/// while counting and false when done / leaving).
class RoundCounterView extends StatefulWidget {
  const RoundCounterView({
    super.key,
    required this.store,
    this.initialKind = RoundKind.tawaf,
    this.debounce = RoundCounter.defaultDebounce,
    this.monotonic,
    this.wallClock,
    this.newId,
    this.onFeedback,
    this.keepAwake,
  });

  final RoundCounterStore store;

  /// The kind offered when nothing is saved yet.
  final RoundKind initialKind;
  final Duration debounce;

  /// Monotonic clock for the debounce (a stopwatch by default).
  final Duration Function()? monotonic;
  final DateTime Function()? wallClock;
  final String Function()? newId;
  final ValueChanged<RoundFeedback>? onFeedback;
  final FutureOr<void> Function(bool awake)? keepAwake;

  @override
  State<RoundCounterView> createState() => _RoundCounterViewState();
}

class _RoundCounterViewState extends State<RoundCounterView> with WidgetsBindingObserver {
  late final RoundCounterPersister _persister = RoundCounterPersister(widget.store);
  RoundCounter? _counter;
  bool _awake = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    final counter = await _persister.load(
      debounce: widget.debounce,
      monotonic: widget.monotonic,
      wallClock: widget.wallClock,
      newId: widget.newId,
    );
    if (counter.active == null) counter.start(widget.initialKind);
    if (!mounted) return;
    setState(() => _counter = counter);
    _syncAwake();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Belt and braces: every change is already queued for writing; make sure
    // the queue is empty before the system may take the app away.
    if (state != AppLifecycleState.resumed) unawaited(_persister.flush());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_awake) unawaited(Future.sync(() => widget.keepAwake?.call(false)).catchError((Object _) {}));
    unawaited(_persister.flush().whenComplete(_persister.dispose));
    super.dispose();
  }

  void _syncAwake() {
    final counting = _counter?.active != null && !_counter!.active!.isComplete;
    if (counting == _awake) return;
    _awake = counting;
    // A wake-lock failure must never disturb counting.
    unawaited(Future.sync(() => widget.keepAwake?.call(counting)).catchError((Object _) {}));
  }

  /// Applies [change] to the counter, shows it and queues the save.
  void _apply(void Function(RoundCounter c) change) {
    final c = _counter;
    if (c == null) return;
    setState(() => change(c));
    _persister.save(c);
    _syncAwake();
  }

  void _onTap() {
    if (_counter == null) return;
    late TapResult result;
    _apply((c) => result = c.tap());
    if (result.counts) {
      widget.onFeedback?.call(result == TapResult.completed ? RoundFeedback.completed : RoundFeedback.counted);
    }
  }

  Future<void> _correct() async {
    final c = _counter;
    final s = c?.active;
    if (c == null || s == null) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CorrectionSheet(total: s.total, current: s.isComplete ? null : s.currentRound),
    );
    if (picked != null && mounted) _apply((c) => c.setRound(picked));
  }

  @override
  Widget build(BuildContext context) {
    final c = _counter;
    final s = c?.active;
    if (c == null || s == null) return const SizedBox.expand();
    return Column(
      children: [
        Expanded(
          child: _Header(
            session: s,
            onKind: (k) => _apply((c) => c.start(k)),
            saveError: _persister.lastError,
          ),
        ),
        // Outside the scrolling header, so the three controls are always on
        // screen, even at the largest text size on a small phone.
        _Controls(
          session: s,
          canUndo: c.canUndo,
          onUndo: () => _apply((c) => c.undo()),
          onCorrect: _correct,
          onPauseToggle: () => _apply((c) => (c.active?.paused ?? false) ? c.resume() : c.pause()),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.l),
            child: s.isComplete
                ? _CompletePanel(
                    session: s,
                    onStart: (k) => _apply((c) => c.start(k)),
                  )
                : _TapArea(session: s, onTap: _onTap),
          ),
        ),
      ],
    );
  }
}

/// Everything above the controls: the big round, direction, dots, kind and
/// the saved note. Scrolls rather than overflows at large text sizes.
class _Header extends StatelessWidget {
  const _Header({
    required this.session,
    required this.onKind,
    required this.saveError,
  });

  final RoundSession session;
  final ValueChanged<RoundKind> onKind;
  final ValueListenable<Object?> saveError;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = session;
    final reduced = context.reducedMotion;
    final heading = switch (s.headingTo) {
      SaiPoint.safa => l.hajjCounterHeadingSafa,
      SaiPoint.marwa => l.hajjCounterHeadingMarwa,
      null => null,
    };
    final roundText = s.isComplete
        ? l.hajjCounterCountOf(fmt.formatInt(s.total, grouping: false), fmt.formatInt(s.total, grouping: false))
        : l.hajjCounterRoundOf(fmt.formatInt(s.currentRound, grouping: false), fmt.formatInt(s.total, grouping: false));
    final spoken = s.isComplete
        ? (s.kind == RoundKind.tawaf ? l.hajjCounterCompleteTawaf : l.hajjCounterCompleteSai)
        : (heading == null ? roundText : l.hajjCounterAnnounce(roundText, heading));

    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.s),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - Space.l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // One live region for the number and the direction, so a screen
              // reader announces the new round after every tap.
              Semantics(
                liveRegion: true,
                container: true,
                label: spoken,
                excludeSemantics: true,
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
                      child: FittedBox(
                        key: ValueKey('${s.id}/${s.count}'),
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.isComplete ? (s.kind == RoundKind.tawaf ? l.hajjCounterCompleteTawaf : l.hajjCounterCompleteSai) : roundText,
                          maxLines: 1,
                          style: text.displayMedium!.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (s.isComplete)
                      Text(roundText, style: text.titleLarge!.copyWith(color: t.textSecondary))
                    else if (heading != null)
                      Text(heading, style: text.titleLarge!.copyWith(color: t.gold), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: Space.s),
              ExcludeSemantics(child: _Dots(done: s.count, total: s.total)),
              const SizedBox(height: Space.s),
              const SizedBox(height: Space.s),
              Semantics(
                container: true,
                label: l.hajjCounterKindLabel,
                child: Wrap(
                  spacing: Space.s,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final k in RoundKind.values)
                      ChoiceChip(
                        label: Text(k == RoundKind.tawaf ? l.hajjCounterKindTawaf : l.hajjCounterKindSai),
                        selected: s.kind == k,
                        // The kind can be changed only before the first tap:
                        // switching later would throw a count away.
                        onSelected: s.phase == CounterPhase.notStarted && s.kind != k ? (_) => onKind(k) : null,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xs),
              ValueListenableBuilder<Object?>(
                valueListenable: saveError,
                builder: (context, err, _) => Text(
                  err == null ? l.hajjCounterSaved : l.hajjCounterNotSaved,
                  textAlign: TextAlign.center,
                  style: text.bodySmall!.copyWith(color: err == null ? t.textTertiary : t.warning),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

/// Undo, correct by hand, pause / resume: always visible, each at least 48 dp.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.session,
    required this.canUndo,
    required this.onUndo,
    required this.onCorrect,
    required this.onPauseToggle,
  });

  final RoundSession session;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onCorrect;
  final VoidCallback onPauseToggle;

  static final ButtonStyle _style = TextButton.styleFrom(minimumSize: const Size(48, 48));

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final s = session;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: Space.s,
        children: [
          TextButton.icon(
            style: _style,
            onPressed: canUndo ? onUndo : null,
            icon: const Icon(Icons.undo_rounded),
            label: Text(l.hajjCounterUndo),
          ),
          TextButton.icon(
            style: _style,
            onPressed: onCorrect,
            icon: const Icon(Icons.edit_rounded),
            label: Text(l.hajjCounterCorrect),
          ),
          if (!s.isComplete)
            TextButton.icon(
              style: _style,
              onPressed: onPauseToggle,
              icon: Icon(s.paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              label: Text(s.paused ? l.hajjCounterResume : l.hajjCounterPause),
            ),
        ],
      ),
    );
  }
}

/// One dot per round, filled for the rounds already counted.
class _Dots extends StatelessWidget {
  const _Dots({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: Space.s,
      children: [
        for (var i = 0; i < total; i++)
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? t.accent : Colors.transparent,
              border: Border.all(color: i < done ? t.accent : t.textTertiary, width: 1.5),
            ),
          ),
      ],
    );
  }
}

/// The huge target: everything in it counts, nothing in it needs aiming.
class _TapArea extends StatelessWidget {
  const _TapArea({required this.session, required this.onTap});

  final RoundSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final paused = session.paused;
    return Semantics(
      button: true,
      enabled: !paused,
      label: l.hajjCounterTapArea,
      hint: paused ? l.hajjCounterPausedBanner : l.hajjCounterTapHint,
      onTap: paused ? null : onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: paused ? t.space2 : t.accentSoft,
            borderRadius: BorderRadius.circular(t.radiusXL),
            border: Border.all(color: paused ? t.glassBorder : t.accent, width: 2),
          ),
          child: LayoutBuilder(
            builder: (context, box) => Center(
              // Wraps text at the area's width, and shrinks the whole block
              // if a small screen at a large text size leaves too little
              // height, so it can never overflow.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: (box.maxWidth - 2 * Space.l).clamp(0.0, double.infinity),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        paused ? Icons.pause_circle_outline_rounded : Icons.touch_app_rounded,
                        size: 72,
                        color: t.textPrimary,
                      ),
                      const SizedBox(height: Space.m),
                      Text(
                        paused ? l.hajjCounterPausedBanner : l.hajjCounterTapArea,
                        textAlign: TextAlign.center,
                        style: text.headlineSmall!.copyWith(color: t.textPrimary),
                      ),
                      if (!paused) ...[
                        const SizedBox(height: Space.s),
                        Text(
                          l.hajjCounterTapHint,
                          textAlign: TextAlign.center,
                          style: text.bodyLarge!.copyWith(color: t.textSecondary),
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

/// Shown instead of the tap area once every round is counted: taps do
/// nothing; a new session starts only from these explicit buttons.
class _CompletePanel extends StatelessWidget {
  const _CompletePanel({required this.session, required this.onStart});

  final RoundSession session;
  final ValueChanged<RoundKind> onStart;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 72, color: t.success),
            const SizedBox(height: Space.l),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
              onPressed: () => onStart(RoundKind.tawaf),
              icon: const Icon(Icons.replay_rounded),
              label: Text(l.hajjCounterStartAnotherTawaf),
            ),
            const SizedBox(height: Space.s),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 56)),
              onPressed: () => onStart(RoundKind.sai),
              icon: const Icon(Icons.replay_rounded),
              label: Text(l.hajjCounterStartAnotherSai),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Which round are you on now?" - one big button per round, no typing.
class _CorrectionSheet extends StatelessWidget {
  const _CorrectionSheet({required this.total, required this.current});

  final int total;

  /// The round shown as chosen (null when the session is complete).
  final int? current;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.hajjCounterCorrectTitle, textAlign: TextAlign.center, style: text.titleLarge),
            const SizedBox(height: Space.l),
            Wrap(
              spacing: Space.m,
              runSpacing: Space.m,
              alignment: WrapAlignment.center,
              children: [
                for (var n = 1; n <= total; n++)
                  Semantics(
                    button: true,
                    selected: n == current,
                    label: l.hajjCounterCorrectOption(fmt.formatInt(n, grouping: false)),
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: (n == current ? FilledButton.new : OutlinedButton.new)(
                        onPressed: () => Navigator.of(context).pop(n),
                        child: Text(fmt.formatInt(n, grouping: false), style: text.titleLarge),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
