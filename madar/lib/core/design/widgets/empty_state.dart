import 'package:flutter/material.dart';

import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../painters/empty_state_painters.dart';
import '../tokens.dart';
import 'ambient_motion.dart';
import 'madar_button.dart';

/// Which illustration an [AnimatedEmptyState] shows.
enum EmptyStateKind {
  /// Empty list: a crescent with drifting stars.
  emptyList,

  /// No data / empty chart: a tiny astrolabe with a sweeping needle.
  noData,

  /// Search without results: a lens scanning the stars.
  noResults,
}

/// A living empty state: an animated illustration, title, body and an
/// optional action, entering with a gentle staggered rise. The illustration
/// loops (paused under reduced motion / TickerMode off).
class AnimatedEmptyState extends StatefulWidget {
  const AnimatedEmptyState({
    super.key,
    required this.kind,
    this.title,
    this.body,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.illustrationSize = 148,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: Space.xl, vertical: Space.l),
  });

  final EmptyStateKind kind;

  /// Defaults to a localised title for [kind].
  final String? title;

  /// Defaults to a localised body for [kind].
  final String? body;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final double illustrationSize;
  final EdgeInsetsGeometry padding;

  @override
  State<AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
}

class _AnimatedEmptyStateState extends State<AnimatedEmptyState> with TickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: _loopDuration(widget.kind),
    value: 0.18,
  );
  late final AnimationController _entrance = AnimationController(vsync: this, duration: MadarMotion.long);
  late final List<CurvedAnimation> _stagger = [
    for (final begin in const [0.0, 0.12, 0.22, 0.34])
      CurvedAnimation(
        parent: _entrance,
        curve: Interval(begin, begin + 0.6, curve: MadarMotion.decelerate),
      ),
  ];
  bool _started = false;

  static Duration _loopDuration(EmptyStateKind kind) => switch (kind) {
    EmptyStateKind.emptyList => const Duration(seconds: 16),
    EmptyStateKind.noData => const Duration(seconds: 9),
    EmptyStateKind.noResults => const Duration(seconds: 14),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = context.reducedMotion;
    if (!_started) {
      _started = true;
      _entrance.duration = context.motion(MadarMotion.long);
      _entrance.forward();
    }
    if (reduced || !context.ambientMotion) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedEmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) {
      _loop.duration = _loopDuration(widget.kind);
      if (_loop.isAnimating) _loop.repeat();
    }
  }

  @override
  void dispose() {
    for (final c in _stagger) {
      c.dispose();
    }
    _loop.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Widget _rise(int step, Widget child) {
    final curve = _stagger[step];
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = Localizations.of<L10n>(context, L10n);
    final (defTitle, defBody) = switch (widget.kind) {
      EmptyStateKind.emptyList => (l?.designEmptyListTitle, l?.designEmptyListBody),
      EmptyStateKind.noData => (l?.designNoDataTitle, l?.designNoDataBody),
      EmptyStateKind.noResults => (l?.designNoResultsTitle, l?.designNoResultsBody),
    };
    final title = widget.title ?? defTitle ?? '';
    final body = widget.body ?? defBody;
    final colors = EmptyIllustrationColors(
      gold: t.gold,
      brass: t.brass,
      brassDark: t.brassDark,
      glow: t.accentGlow,
      star: t.starTint,
      line: t.glassBorder,
      glass: Color.alphaBlend(t.glassFill, t.space2.withValues(alpha: 0.5)),
      accent: t.accent,
    );
    final dir = Directionality.of(context);
    final painter = switch (widget.kind) {
      EmptyStateKind.emptyList => CrescentStarsPainter(phase: _loop, colors: colors, textDirection: dir),
      EmptyStateKind.noData => AstrolabeNeedlePainter(phase: _loop, colors: colors, textDirection: dir),
      EmptyStateKind.noResults => TelescopeScanPainter(phase: _loop, colors: colors, textDirection: dir),
    };
    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _rise(
            0,
            ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(size: Size.square(widget.illustrationSize), painter: painter),
              ),
            ),
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            _rise(
              1,
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.titleLarge!.copyWith(color: t.textPrimary),
                ),
              ),
            ),
          ],
          if (body != null && body.isNotEmpty) ...[
            const SizedBox(height: Space.xs + 2),
            _rise(
              2,
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium!.copyWith(color: t.textSecondary),
                ),
              ),
            ),
          ],
          if (widget.actionLabel != null && widget.onAction != null) ...[
            const SizedBox(height: Space.xl - 4),
            _rise(
              3,
              MadarButton(
                label: widget.actionLabel!,
                icon: widget.actionIcon,
                variant: MadarButtonVariant.secondary,
                onPressed: widget.onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
