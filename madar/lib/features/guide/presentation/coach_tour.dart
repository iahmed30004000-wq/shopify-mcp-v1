import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/madar_button.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../domain/bubble_placement.dart';
import '../domain/guide_seen_store.dart';
import '../domain/tour.dart';

/// One bubble of a tour, anchored to a widget through its [target] key.
@immutable
class CoachStep {
  const CoachStep({required this.id, required this.title, required this.body, required this.target});

  final String id;
  final String title;
  final String body;

  /// Put this key on the widget to point at. When it is not on screen the
  /// bubble shows in the middle without a spotlight, never an error.
  final GlobalKey target;
}

/// The coach tour: three or four bubbles pointing at parts of a screen, the
/// rest dimmed.
abstract final class CoachTour {
  static final Set<String> _running = {};

  /// Runs [steps] over the current screen. Resolves when the person has
  /// finished or skipped it, or null when it did not run (already seen, no
  /// steps, or the same tour is already open).
  ///
  /// Once per [tourId]: finishing and skipping both count as seen (through
  /// [store]). [replay] ignores that, for the «replay the tour» button.
  /// Call it after the screen's first frame so the targets are laid out.
  static Future<TourOutcome?> run(
    BuildContext context, {
    required String tourId,
    required List<CoachStep> steps,
    required GuideSeenStore store,
    bool replay = false,
  }) async {
    if (steps.isEmpty || _running.contains(tourId)) return null;
    final gate = TourGate(store);
    if (!replay && !await gate.shouldRun(tourId)) return null;
    if (!context.mounted || _running.contains(tourId)) return null;
    _running.add(tourId);
    try {
      final reduced = context.reducedMotion;
      final outcome = await showGeneralDialog<TourOutcome>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0x00000000),
        barrierLabel: L10n.of(context).guideTourSkip,
        transitionDuration: reduced ? Duration.zero : MadarMotion.short,
        transitionBuilder: (context, animation, _, child) =>
            reduced ? child : FadeTransition(opacity: animation, child: child),
        pageBuilder: (_, _, _) => CoachTourOverlay(steps: steps),
      );
      await gate.markSeen(tourId);
      return outcome ?? TourOutcome.skipped;
    } finally {
      _running.remove(tourId);
    }
  }
}

/// The tour's screen. Pops with the [TourOutcome]; use [CoachTour.run].
class CoachTourOverlay extends StatefulWidget {
  const CoachTourOverlay({super.key, required this.steps});

  final List<CoachStep> steps;

  @override
  State<CoachTourOverlay> createState() => _CoachTourOverlayState();
}

class _CoachTourOverlayState extends State<CoachTourOverlay> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TourState _tour = TourState(widget.steps.length);
  Rect? _target;
  late final _SpotlightModel _spot = _SpotlightModel(this);
  final FocusNode _focus = FocusNode(debugLabel: 'coach bubble');
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStep(animate: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spot.dispose();
    _focus.dispose();
    super.dispose();
  }

  // The keyboard or a rotation moved things: measure again once laid out.
  @override
  void didChangeMetrics() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _measure(animate: false);
  });

  Future<void> _showStep({required bool animate}) async {
    if (!mounted) return;
    final ctx = widget.steps[_tour.index].target.currentContext;
    if (ctx != null && ctx.mounted) {
      // A target below the fold (or under the keyboard) is scrolled into view.
      final d = context.reducedMotion ? Duration.zero : MadarMotion.medium;
      await Scrollable.ensureVisible(ctx, alignment: 0.4, duration: d, curve: MadarMotion.standard);
    }
    if (!mounted) return;
    _measure(animate: animate);
    _focus.requestFocus();
  }

  void _measure({required bool animate}) {
    final box = context.findRenderObject();
    final targetObj = widget.steps[_tour.index].target.currentContext?.findRenderObject();
    Rect? rect;
    if (box is RenderBox && box.hasSize && targetObj is RenderBox && targetObj.attached && targetObj.hasSize) {
      final topLeft = box.globalToLocal(targetObj.localToGlobal(Offset.zero));
      rect = (topLeft & targetObj.size).inflate(6);
    }
    final media = MediaQuery.of(context);
    final spot = BubbleGeometry.visibleTarget(rect, media.size, media.viewInsets.bottom);
    _spot.moveTo(spot, animate: animate && !context.reducedMotion);
    setState(() => _target = rect);
  }

  void _go(TourState next) {
    if (_closing) return;
    if (!next.isRunning) {
      _closing = true;
      Navigator.of(context).pop(next.outcome);
      return;
    }
    if (next == _tour) return;
    setState(() => _tour = next);
    _showStep(animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final t = context.tokens;
    final l10n = L10n.of(context);
    final step = widget.steps[_tour.index];
    final direction = Directionality.of(context);
    final maxWidth = (media.size.width - 32).clamp(0.0, 360.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_tour.skip());
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  model: _spot,
                  dim: t.space0.withValues(alpha: t.isDark ? 0.78 : 0.66),
                  ring: t.accent,
                  radius: t.radiusM,
                ),
              ),
            ),
          ),
          CustomSingleChildLayout(
            delegate: _BubbleLayout(
              target: _target,
              screen: media.size,
              safe: media.padding,
              keyboard: media.viewInsets.bottom,
              direction: direction,
              maxWidth: maxWidth,
            ),
            child: KeyedSubtree(
              key: ValueKey(_tour.index),
              child: _Bubble(
                focus: _focus,
                step: step,
                index: _tour.index,
                total: _tour.total,
                semantics: l10n.guideTourBubbleSemantics(_tour.index + 1, _tour.total, step.title, step.body),
                onNext: () => _go(_tour.next()),
                onBack: _tour.isFirst ? null : () => _go(_tour.back()),
                onSkip: () => _go(_tour.skip()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays the bubble out with [BubbleGeometry]: constraints first (its height
/// is capped to the room beside the target), then its position.
class _BubbleLayout extends SingleChildLayoutDelegate {
  _BubbleLayout({
    required this.target,
    required this.screen,
    required this.safe,
    required this.keyboard,
    required this.direction,
    required this.maxWidth,
  });

  final Rect? target;
  final Size screen;
  final EdgeInsets safe;
  final double keyboard;
  final TextDirection direction;
  final double maxWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final h = BubbleGeometry.maxBubbleHeight(target: target, screen: screen, safe: safe, keyboard: keyboard);
    return BoxConstraints(maxWidth: maxWidth, minWidth: maxWidth, maxHeight: h);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final p = BubbleGeometry.place(
      target: target,
      screen: screen,
      bubble: childSize,
      direction: direction,
      safe: safe,
      keyboard: keyboard,
    );
    return p.rect.topLeft;
  }

  @override
  bool shouldRelayout(_BubbleLayout old) =>
      old.target != target ||
      old.screen != screen ||
      old.safe != safe ||
      old.keyboard != keyboard ||
      old.direction != direction ||
      old.maxWidth != maxWidth;
}

/// The spotlight's rectangle, animated from one step to the next. A
/// listenable so the painter repaints without rebuilding any widget.
class _SpotlightModel extends ChangeNotifier {
  _SpotlightModel(TickerProvider vsync) : _controller = AnimationController(vsync: vsync, duration: MadarMotion.medium) {
    _controller.addListener(notifyListeners);
  }

  final AnimationController _controller;
  Rect? _from;
  Rect? _to;

  Rect? get current => Rect.lerp(_from, _to, MadarMotion.standard.transform(_controller.value));

  void moveTo(Rect? rect, {required bool animate}) {
    if (rect == _to) return;
    if (animate) {
      _from = current;
      _to = rect;
      _controller.forward(from: 0);
    } else {
      _from = _to = rect;
      _controller.value = 1;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Dims everything but a rounded hole around the target, and rings the hole.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.model, required Color dim, required Color ring, required this.radius})
    : _dim = Paint()..color = dim,
      _ring = Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
      super(repaint: model);

  final _SpotlightModel model;
  final double radius;
  final Paint _dim;
  final Paint _ring;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = model.current;
    final all = Offset.zero & size;
    if (hole == null || hole.isEmpty) {
      canvas.drawRect(all, _dim);
      return;
    }
    final inner = RRect.fromRectAndRadius(hole, Radius.circular(radius));
    canvas.drawDRRect(RRect.fromRectXY(all, 0, 0), inner, _dim);
    canvas.drawRRect(inner, _ring);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.model != model || old._dim.color != _dim.color || old._ring.color != _ring.color || old.radius != radius;
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.focus,
    required this.step,
    required this.index,
    required this.total,
    required this.semantics,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final FocusNode focus;
  final CoachStep step;
  final int index;
  final int total;
  final String semantics;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  bool get _last => index == total - 1;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
        decoration: BoxDecoration(
          color: t.space2,
          borderRadius: BorderRadius.circular(t.radiusL),
          border: Border.all(color: t.accent.withValues(alpha: 0.7), width: 1.2),
          boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      l10n.guideTourStepOf(index + 1, total),
                      style: text.labelMedium?.copyWith(color: t.textSecondary),
                    ),
                  ),
                ),
                if (!_last)
                  MadarButton(
                    label: l10n.guideTourSkip,
                    variant: MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    onPressed: onSkip,
                  ),
              ],
            ),
            // One announcement for the whole bubble; the buttons stay their
            // own nodes. Focus lands here when a step appears.
            Flexible(
              child: Focus(
                focusNode: focus,
                child: Semantics(
                  container: true,
                  focusable: true,
                  liveRegion: true,
                  label: semantics,
                  child: ExcludeSemantics(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(step.title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: Space.xs),
                          Text(step.body, style: text.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.m),
            ExcludeSemantics(child: _Dots(count: total, index: index)),
            const SizedBox(height: Space.m),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              alignment: WrapAlignment.end,
              children: [
                if (onBack != null)
                  MadarButton(
                    label: l10n.guideTourBack,
                    variant: MadarButtonVariant.secondary,
                    icon: Icons.arrow_back_rounded,
                    onPressed: onBack,
                  ),
                MadarButton(
                  label: _last ? l10n.guideTourDone : l10n.guideTourNext,
                  trailingIcon: _last ? null : Icons.arrow_forward_rounded,
                  onPressed: onNext,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: i == index ? 18 : 8,
            height: 8,
            margin: const EdgeInsetsDirectional.only(end: Space.xs),
            decoration: BoxDecoration(
              color: i == index ? t.accent : t.textTertiary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
