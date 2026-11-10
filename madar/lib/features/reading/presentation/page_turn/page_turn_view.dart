import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'book_direction.dart';
import 'curl_painter.dart';
import 'curl_scene.dart';
import 'page_snapshot_cache.dart';
import 'page_turn_controller.dart';
import 'page_turn_labels.dart';
import 'paper_texture.dart';
import 'spread_layout.dart';
import 'turn_logic.dart';

/// A book that turns its pages under the finger, for ANY widget pages.
///
/// * The page follows the finger from its free edge with a real curl: the
///   corner or edge lifts, its back shows (mirrored, a little darker), a soft
///   shadow moves over the page below and a highlight runs along the bend.
///   Releasing completes or springs back by distance and fling speed. A tap
///   near the free edge turns too (near the other edge: back).
/// * [bookDirection] is the BOOK's, never the app's: an Arabic book is [BookDirection.rtl]:
///   it opens from the right, the spine is on the right, and the page is
///   turned by dragging its left edge across to the right. Page contents
///   also get the book's text direction.
/// * Held sideways ([spread] and an aspect ratio of 1.2 or more) two pages
///   face each other; page 0 stands alone as the cover, then 1+2, 3+4 ...
/// * With reduced motion (the [reducedMotion] flag or the system setting)
///   there is no curl: pages cross-fade. A [PageTurnController.jumpTo] more
///   than one page away also cross-fades instead of flipping through the
///   pages in between.
///
/// How it stays smooth: the pages next to the current one are captured to
/// images (`RepaintBoundary.toImageSync`, a few at a time, after the frame)
/// and the curl is drawn with canvas clips, transforms and gradients over
/// those images (no fragment shader). Until an image exists the turn uses the
/// live widgets instead, so it never waits and never shows a blank page.
/// Images are dropped when the size, pixel ratio, text scale, paper or
/// [contentKey] change, and for pages that are far away.
///
/// Measured in `page_turn_view_test.dart` (debug JIT build, shared 4-core
/// CI box): see the comments in the performance test for the numbers.
class PageTurnView extends StatefulWidget {
  const PageTurnView({
    super.key,
    required this.pageCount,
    required this.pageBuilder,
    required this.labels,
    this.initialPage = 0,
    this.onPageChanged,
    this.controller,
    this.bookDirection = BookDirection.ltr,
    this.spread = true,
    this.paper = const PaperOptions(),
    this.reducedMotion = false,
    this.contentKey,
    this.useSnapshots = true,
    this.onTapCenter,
  });

  final int pageCount;

  /// Builds page [index] (0-based). It gets the page's exact size as a tight
  /// constraint and the book's text direction. It must not depend on state
  /// the view cannot see: when the content changes, change [contentKey] or
  /// call [PageTurnController.invalidate].
  final Widget Function(BuildContext context, int index) pageBuilder;

  final PageTurnLabels labels;
  final int initialPage;

  /// Called with the new (0-based) page after a turn or a jump. In a
  /// facing-pages layout: the lower page of the pair.
  final ValueChanged<int>? onPageChanged;

  final PageTurnController? controller;
  final BookDirection bookDirection;

  /// Show two facing pages when the reader is wider than tall.
  final bool spread;

  final PaperOptions paper;
  final bool reducedMotion;

  /// Change it to say "every page's content changed" (font size, a new
  /// highlight colour ...): the stored page images are rebuilt.
  final Object? contentKey;

  /// False = never capture images, always turn the live widgets (heavier;
  /// for very low memory, or for tests).
  final bool useSnapshots;

  /// A tap away from both edges (the reader can toggle its toolbars here).
  final VoidCallback? onTapCenter;

  @override
  State<PageTurnView> createState() => PageTurnViewState();
}

class _Plan {
  const _Plan({required this.front, required this.under, required this.back, required this.other, required this.target, required this.forward});
  final int? front;
  final int? under;
  final int? back;
  final int? other;
  final int target;
  final bool forward;
}

class _ActiveTurn {
  _ActiveTurn({required this.plan, required this.scene, required this.useImages, required this.touch});
  final _Plan plan;
  final CurlScene scene;
  final bool useImages;
  Offset touch;
  bool animating = false;
  bool commit = false;
  Offset from = Offset.zero;
  Offset to = Offset.zero;
  double arc = 0;
  Curve curve = Curves.easeOutCubic;
}

class _ActiveFade {
  _ActiveFade(this.from, this.to);
  final int from;
  final int to;
}

class _Drag {
  _Drag(this.start);
  final Offset start;
  TurnIntent? intent;
  bool ignored = false;
  Offset delta = Offset.zero;
}

class PageTurnViewState extends State<PageTurnView> with SingleTickerProviderStateMixin implements PageTurnHost {
  late final AnimationController _anim;
  final PageSnapshotCache _cache = PageSnapshotCache();
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};

  late int _page;
  ReaderRects? _rects;
  Size _size = Size.zero;
  double _dpr = 1;
  double _textScale = 1;
  bool _mediaReduced = false;
  Object _signature = 0;
  int _contentGen = 0;

  _ActiveTurn? _turn;
  _ActiveFade? _fade;
  _Drag? _drag;
  Completer<void>? _done;

  ui.Image? _grainTile;
  GrainPaint? _grain;
  double _grainDpr = 0;

  bool _captureScheduled = false;
  int _captureFailures = 0;

  PageSpreads get _spreads => PageSpreads(widget.pageCount);
  bool get _reduced => widget.reducedMotion || _mediaReduced;
  bool get _isSpread => _rects?.spread ?? false;

  // ---- test hooks ------------------------------------------------------

  @visibleForTesting
  PageSnapshotCache get debugCache => _cache;
  @visibleForTesting
  int get debugPage => _page;
  @visibleForTesting
  bool get debugTurning => _turn != null;
  @visibleForTesting
  bool get debugFading => _fade != null;
  @visibleForTesting
  bool get debugTurnUsesImages => _turn?.useImages ?? false;
  @visibleForTesting
  bool get debugSpread => _isSpread;
  @visibleForTesting
  Object get debugSignature => _signature;

  // ---- lifecycle ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    _page = _clampPage(widget.initialPage);
    widget.controller?.attach(this, page: _page, count: widget.pageCount);
    _loadTexture();
  }

  @override
  void didUpdateWidget(PageTurnView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget;
    if (old.controller != widget.controller) {
      old.controller?.detach(this);
      widget.controller?.attach(this, page: _page, count: widget.pageCount);
    }
    if (old.bookDirection != widget.bookDirection || old.pageCount != widget.pageCount) {
      _settleInstant(defer: true);
      final clamped = _clampPage(_page);
      if (clamped != _page) _applyPage(clamped, defer: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller?.update(page: _page, count: widget.pageCount);
      });
    }
    if (old.contentKey != widget.contentKey) _contentGen++;
    if (old.paper.seed != widget.paper.seed || old.paper.grainStrength != widget.paper.grainStrength) {
      _loadTexture();
    }
    if (!widget.useSnapshots) _cache.clear();
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _turn?.scene.dispose();
    _turn = null;
    _anim.dispose();
    _cache.dispose();
    _grain?.dispose();
    _complete();
    super.dispose();
  }

  int _clampPage(int p) => widget.pageCount <= 0 ? 0 : p.clamp(0, widget.pageCount - 1).toInt();

  void _loadTexture() {
    final o = widget.paper;
    _grainTile = null;
    _grain?.dispose();
    _grain = null;
    if (o.grainStrength <= 0) return;
    PaperTexture.load(seed: o.seed, strength: o.grainStrength).then((img) {
      if (!mounted || widget.paper.seed != o.seed || widget.paper.grainStrength != o.grainStrength) return;
      setState(() => _grainTile = img);
    }, onError: (Object _) {});
  }

  // ---- PageTurnHost ------------------------------------------------------

  @override
  bool get canGoNext => _planFor(forward: true) != null;

  @override
  bool get canGoPrevious => _planFor(forward: false) != null;

  @override
  Future<void> turnNext() => _programmaticTurn(forward: true);

  @override
  Future<void> turnPrevious() => _programmaticTurn(forward: false);

  @override
  Future<void> jumpToPage(int page, {required bool animate}) {
    final target = _clampPage(page);
    if (widget.pageCount <= 0 || target == _page) return Future<void>.value();
    final sp = _spreads;
    final spreadMode = _isSpread;
    final cur = spreadMode ? sp.spreadOfPage(_page) : _page;
    final dst = spreadMode ? sp.spreadOfPage(target) : target;
    if (!animate || dst == cur) {
      _settleInstant();
      setState(() => _applyPage(target));
      return Future<void>.value();
    }
    if ((dst - cur).abs() == 1 && !_reduced) return _programmaticTurn(forward: dst > cur);
    _settleInstant();
    return _fadeTo(target);
  }

  @override
  void invalidatePage(int? page) {
    _cache.invalidate(page);
    if (mounted) setState(() {});
  }

  // ---- turn planning -----------------------------------------------------

  _Plan? _planFor({required bool forward}) {
    final n = widget.pageCount;
    if (n <= 0) return null;
    int? pg(int i) => (i >= 0 && i < n) ? i : null;
    if (_isSpread) {
      final sp = _spreads;
      final s = sp.spreadOfPage(_page);
      final t = forward ? s + 1 : s - 1;
      if (t < 0 || t >= sp.count) return null;
      final base = forward ? s : t;
      return _Plan(
        front: pg(2 * base),
        back: pg(2 * base + 1),
        under: pg(2 * base + 2),
        other: pg(2 * base - 1),
        target: sp.firstPage(t),
        forward: forward,
      );
    }
    final t = _page + (forward ? 1 : -1);
    if (t < 0 || t >= n) return null;
    final base = forward ? _page : t;
    return _Plan(front: base, under: base + 1, back: null, other: null, target: t, forward: forward);
  }

  // ---- layout bookkeeping --------------------------------------------------

  void _onLayout(Size size, ReaderRects rects) {
    final changed = _size != size || _rects?.spread != rects.spread;
    if (changed && (_turn != null || _fade != null || _drag != null)) {
      // Rotated or resized mid-turn: finish a turn that was already
      // committed, cancel one that was still under the finger. No exception,
      // no half-drawn page.
      _drag?.ignored = true;
      _settleInstant(defer: true);
    }
    _size = size;
    _rects = rects;
    _signature = (size, _dpr, _textScale, rects.spread, widget.paper, _contentGen, _grainTile != null, widget.bookDirection);
    _cache.dropStale(_signature);
  }

  void _applyPage(int p, {bool defer = false}) {
    if (p == _page) return;
    _page = p;
    _cache.evictFar(p, _isSpread ? 3 : 1);
    _keys.removeWhere((i, k) => (i - p).abs() > 6 && k.currentContext == null);
    void notify() {
      widget.controller?.update(page: p, count: widget.pageCount);
      widget.onPageChanged?.call(p);
    }

    if (defer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) notify();
      });
    } else {
      notify();
    }
  }

  void _complete() {
    final c = _done;
    _done = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  void _disposeSceneLater(CurlScene scene) {
    // The painters stop listening when the rebuild unmounts them; dispose
    // after that frame so nothing paints a released image.
    SchedulerBinding.instance.addPostFrameCallback((_) => scene.dispose());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Ends any turn/fade right now without animation. A turn that was already
  /// committed lands on its page; one that was only being dragged is cancelled.
  void _settleInstant({bool defer = false}) {
    final t = _turn;
    final f = _fade;
    if (t == null && f == null) {
      _complete();
      return;
    }
    _turn = null;
    _fade = null;
    if (_anim.isAnimating) _anim.stop();
    int? land;
    if (t != null) {
      if (t.animating && t.commit) land = t.plan.target;
      _disposeSceneLater(t.scene);
    }
    if (f != null) land = f.to;
    if (land != null) _applyPage(land, defer: defer);
    _complete();
    if (mounted && !defer) setState(() {});
  }

  // ---- starting a turn -----------------------------------------------------

  Set<int> _neededPages(_Plan plan) => <int>{
    ?plan.front,
    ?plan.under,
    if (_isSpread) ...<int>{?plan.back, ?plan.other},
  };

  bool _beginTurn(_Plan plan, Offset grab, {required Offset touch}) {
    final rects = _rects;
    if (rects == null) return false;
    final needed = _neededPages(plan);
    if (widget.useSnapshots) {
      for (final i in needed) {
        if (!_cache.has(i, _signature)) _captureNow(i);
      }
    }
    final useImages = widget.useSnapshots && needed.every((i) => _cache.has(i, _signature));
    ui.Image? clone(int? i) => (useImages && i != null) ? _cache.lookup(i, _signature)?.clone() : null;
    final scene = CurlScene(
      rects: rects,
      grab: grab,
      touch: touch,
      paperTint: widget.paper.tint,
      front: clone(plan.front),
      under: clone(plan.under),
      back: _isSpread ? clone(plan.back) : null,
      other: _isSpread ? clone(plan.other) : null,
    );
    setState(() => _turn = _ActiveTurn(plan: plan, scene: scene, useImages: useImages, touch: touch));
    return true;
  }

  Future<void> _programmaticTurn({required bool forward, double? y}) {
    final rects = _rects;
    if (rects == null) return Future<void>.value();
    _settleInstant();
    final plan = _planFor(forward: forward);
    if (plan == null) return Future<void>.value();
    if (_reduced) return _fadeTo(plan.target);
    final grab = grabPoint(leaf: rects.leaf, spine: rects.spine, startY: y ?? rects.leaf.bottom);
    final rest = restTouch(rects.leaf, rects.spine, grab);
    if (!_beginTurn(plan, grab, touch: forward ? grab : rest)) return Future<void>.value();
    _done = Completer<void>();
    final future = _done!.future;
    _animateTurn(commit: true, programmatic: true);
    return future;
  }

  void _animateTurn({required bool commit, bool programmatic = false, double velocity = 0}) {
    final t = _turn;
    final rects = _rects;
    if (t == null || rects == null) return;
    final grab = t.scene.grab;
    final rest = restTouch(rects.leaf, rects.spine, grab);
    final target = (t.plan.forward == commit) ? rest : grab;
    t
      ..animating = true
      ..commit = commit
      ..from = t.touch
      ..to = target
      ..curve = programmatic ? Curves.easeInOutCubic : Curves.easeOutCubic
      ..arc = commit ? (rects.leaf.center.dy - grab.dy) * 0.25 : 0;
    final dist = (target - t.touch).distance;
    final ms = programmatic ? 430.0 : (dist / math.max(velocity.abs(), 2400) * 1000).clamp(200.0, 460.0).toDouble();
    _anim
      ..duration = Duration(milliseconds: ms.round())
      ..forward(from: 0);
  }

  void _onTick() {
    final t = _turn;
    if (t != null && t.animating) {
      final e = t.curve.transform(_anim.value);
      final p = Offset.lerp(t.from, t.to, e)!;
      t.touch = Offset(p.dx, p.dy + math.sin(math.pi * e) * t.arc);
      t.scene.moveTouch(t.touch);
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final t = _turn;
    final f = _fade;
    if (t != null && t.animating) {
      _turn = null;
      _disposeSceneLater(t.scene);
      if (mounted) {
        setState(() {
          if (t.commit) _applyPage(t.plan.target);
        });
      }
      _complete();
    } else if (f != null) {
      _fade = null;
      if (mounted) setState(() => _applyPage(f.to));
      _complete();
    }
  }

  Future<void> _fadeTo(int target) {
    if (!mounted || target == _page) return Future<void>.value();
    _settleInstant();
    _done = Completer<void>();
    final future = _done!.future;
    setState(() => _fade = _ActiveFade(_page, target));
    _anim
      ..duration = const Duration(milliseconds: 220)
      ..forward(from: 0);
    return future;
  }

  // ---- gestures --------------------------------------------------------------

  void _onDragStart(DragStartDetails d) {
    if (_rects == null) return;
    _settleInstant();
    _drag = _Drag(d.localPosition);
  }

  Offset _touchForDrag(_ActiveTurn t, Offset delta) {
    final rects = _rects!;
    final leaf = rects.leaf;
    final u = towardSpine(rects.spine);
    final w = leaf.width;
    final grab = t.scene.grab;
    final along = delta.dx * u.dx;
    final tilt = isCornerGrab(leaf, grab) ? 1.0 : 0.5;
    final y = (grab.dy + delta.dy * tilt).clamp(leaf.top - leaf.height * 0.1, leaf.bottom + leaf.height * 0.1).toDouble();
    if (t.plan.forward) {
      final travel = math.min(math.max(0.0, along) * 1.4, 2 * w);
      return Offset(grab.dx + u.dx * travel, y);
    }
    final back = math.min(math.max(0.0, -along) * 2, 2 * w);
    final rest = restTouch(leaf, rects.spine, grab);
    return Offset(rest.dx - u.dx * back, y);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final drag = _drag;
    final rects = _rects;
    if (drag == null || drag.ignored || rects == null) return;
    drag.delta = d.localPosition - drag.start;
    if (drag.intent == null) {
      if (drag.delta.dx.abs() < 1) return;
      final intent = intentForDrag(widget.bookDirection, drag.delta.dx)!;
      final plan = _planFor(forward: intent == TurnIntent.next);
      if (plan == null) {
        drag.ignored = true;
        return;
      }
      drag.intent = intent;
      if (_reduced) return;
      final grab = grabPoint(leaf: rects.leaf, spine: rects.spine, startY: drag.start.dy);
      final rest = restTouch(rects.leaf, rects.spine, grab);
      if (!_beginTurn(plan, grab, touch: plan.forward ? grab : rest)) {
        drag.ignored = true;
        return;
      }
    }
    final t = _turn;
    if (t == null || t.animating) return;
    t.touch = _touchForDrag(t, drag.delta);
    t.scene.moveTouch(t.touch);
  }

  void _onDragEnd(DragEndDetails d) {
    final drag = _drag;
    _drag = null;
    final rects = _rects;
    final intent = drag?.intent;
    if (drag == null || drag.ignored || intent == null || rects == null) return;
    final forward = intent == TurnIntent.next;
    final u = towardSpine(rects.spine);
    final vAlong = d.velocity.pixelsPerSecond.dx * u.dx;
    final vToward = forward ? vAlong : -vAlong;
    final t = _turn;
    if (t == null) {
      // Reduced motion: no curl followed the finger; decide the same way.
      final along = drag.delta.dx * u.dx;
      final travel = math.max(0.0, forward ? along : -along) / rects.leaf.width;
      final plan = _planFor(forward: forward);
      if (plan != null && shouldCommitTurn(travel: travel, velocityTowardCommit: vToward)) _fadeTo(plan.target);
      return;
    }
    final progress = turnProgress(rects.leaf, rects.spine, t.scene.grab, t.touch);
    final travel = forward ? progress : 1 - progress;
    _animateTurn(commit: shouldCommitTurn(travel: travel, velocityTowardCommit: vToward), velocity: vToward);
  }

  void _onDragCancel() {
    final drag = _drag;
    _drag = null;
    final t = _turn;
    if (drag != null && t != null && !t.animating) _animateTurn(commit: false);
  }

  void _onTapUp(TapUpDetails d) {
    final intent = intentForTap(widget.bookDirection, d.localPosition.dx, _size.width);
    if (intent == null) {
      widget.onTapCenter?.call();
      return;
    }
    _programmaticTurn(forward: intent == TurnIntent.next, y: d.localPosition.dy);
  }

  // ---- snapshots ---------------------------------------------------------------

  GlobalKey _keyFor(int i) => _keys.putIfAbsent(i, () => GlobalKey(debugLabel: 'page_turn_$i'));

  /// Captures page [i] if its boundary is mounted and painted. True = stored.
  bool _captureNow(int i) {
    final ro = _keys[i]?.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary || !ro.attached || !ro.hasSize || ro.size.isEmpty) return false;
    try {
      final img = ro.toImageSync(pixelRatio: _dpr);
      _cache.store(i, img, _signature);
      return true;
    } catch (_) {
      return false;
    }
  }

  List<int> _wantedPages() {
    final n = widget.pageCount;
    final out = <int>[];
    void add(int? p) {
      if (p != null && p >= 0 && p < n && !out.contains(p)) out.add(p);
    }

    if (_isSpread) {
      final sp = _spreads;
      final s = sp.spreadOfPage(_page);
      for (final k in <int>[s, s + 1, s - 1]) {
        if (k < 0 || k >= sp.count) continue;
        add(sp.leafSidePage(k));
        add(sp.startSidePage(k));
      }
    } else {
      add(_page);
      add(_page + 1);
      add(_page - 1);
    }
    return out;
  }

  List<int> _visiblePages() {
    if (!_isSpread) return <int>[_page];
    final s = _spreads.spreadOfPage(_page);
    return <int>[?_spreads.leafSidePage(s), ?_spreads.startSidePage(s)];
  }

  void _scheduleCapture() {
    if (_captureScheduled || !widget.useSnapshots) return;
    _captureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureScheduled = false;
      if (!mounted || _rects == null || _turn != null || _fade != null) return;
      for (final i in _wantedPages()) {
        if (_cache.has(i, _signature)) continue;
        if (_captureNow(i)) {
          _captureFailures = 0;
          // One per frame keeps the capture invisible; the rebuild unmounts
          // the hidden copy and asks for the next.
          setState(() {});
        } else if (++_captureFailures < 6) {
          // Not painted yet (first frame after a rotation): try next frame.
          SchedulerBinding.instance.scheduleFrame();
        }
        return;
      }
      _captureFailures = 0;
    });
  }

  // ---- building -----------------------------------------------------------------

  Rect _rectOf(int? page) {
    final r = _rects!;
    if (!r.spread || page == null) return r.leaf;
    return page.isEven ? r.leaf : r.other!;
  }

  SpineSide? _gutterOf(Rect rect) {
    final r = _rects!;
    if (!r.spread) return r.spine;
    if (rect == r.leaf) return r.spine;
    return r.spine == SpineSide.left ? SpineSide.right : SpineSide.left;
  }

  Widget _pageFrame(int? index, Rect rect, {required bool keyed}) {
    final o = widget.paper;
    return Positioned.fromRect(
      rect: rect,
      child: RepaintBoundary(
        key: (keyed && index != null) ? _keyFor(index) : null,
        child: PaperPage(
          tint: o.tint,
          grain: _grain?.paint,
          gutterShade: o.gutterShade,
          gutter: _gutterOf(rect),
          child: index == null
              ? null
              : Directionality(
                  textDirection: widget.bookDirection.textDirection,
                  child: KeyedSubtree(
                    key: ValueKey<int>(index),
                    child: Builder(builder: (context) => widget.pageBuilder(context, index)),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _idleContent(int page, {required bool keyed}) {
    final r = _rects!;
    if (!r.spread) {
      return Stack(fit: StackFit.expand, children: <Widget>[_pageFrame(page, r.leaf, keyed: keyed)]);
    }
    final sp = _spreads;
    final s = sp.spreadOfPage(page);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _pageFrame(sp.leafSidePage(s), r.leaf, keyed: keyed),
        _pageFrame(sp.startSidePage(s), r.other!, keyed: keyed),
      ],
    );
  }

  Widget _turnLayer(_ActiveTurn t) {
    final r = _rects!;
    if (t.useImages) {
      return RepaintBoundary(
        child: SizedBox.expand(
          child: CustomPaint(painter: CurlPainter(scene: t.scene), isComplex: true, willChange: true),
        ),
      );
    }
    final plan = t.plan;
    final backWidget = r.spread ? _pageFrame(plan.back, r.other!, keyed: false) : _pageFrame(plan.front, r.leaf, keyed: false);
    return CurlLiveLayers(
      scene: t.scene,
      front: _pageFrame(plan.front, r.leaf, keyed: false),
      under: _pageFrame(plan.under, r.leaf, keyed: false),
      back: backWidget,
      other: r.spread ? _pageFrame(plan.other, r.other!, keyed: false) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    _dpr = mq?.devicePixelRatio ?? 1;
    _textScale = mq?.textScaler.scale(10) ?? 10;
    _textScale /= 10;
    _mediaReduced = mq?.disableAnimations ?? false;
    final o = widget.paper;

    return LayoutBuilder(
      builder: (context, constraints) {
        var size = constraints.biggest;
        if (!size.isFinite) size = mq?.size ?? Size.zero;
        if (size.isEmpty || widget.pageCount <= 0) {
          return SizedBox.expand(child: ColoredBox(color: o.tint));
        }
        final rects = ReaderRects.compute(
          size,
          widget.bookDirection,
          spread: PageSpreads.shouldSpread(size, enabled: widget.spread),
        );
        if (_grainTile != null && (_grain == null || _grainDpr != _dpr)) {
          _grain?.dispose();
          _grain = GrainPaint(_grainTile!, _dpr);
          _grainDpr = _dpr;
        }
        _onLayout(size, rects);

        final turn = _turn;
        final fade = _fade;
        final children = <Widget>[];
        if (turn == null && fade == null) {
          final visible = _visiblePages();
          for (final i in _wantedPages()) {
            if (visible.contains(i) || _cache.has(i, _signature) || !widget.useSnapshots) continue;
            children.add(
              ExcludeSemantics(
                child: IgnorePointer(
                  child: TickerMode(enabled: false, child: Stack(fit: StackFit.expand, children: <Widget>[_pageFrame(i, _rectOf(i), keyed: true)])),
                ),
              ),
            );
          }
          children.add(_idleContent(_page, keyed: true));
          _scheduleCapture();
        } else if (fade != null) {
          children.add(_idleContent(fade.to, keyed: false));
          children.add(
            ExcludeSemantics(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _anim,
                  child: _idleContent(fade.from, keyed: false),
                  builder: (context, child) => Opacity(opacity: (1 - _anim.value).clamp(0.0, 1.0).toDouble(), child: child),
                ),
              ),
            ),
          );
        } else if (turn != null) {
          if (turn.useImages) children.add(_idleContent(_page, keyed: true));
          children.add(ExcludeSemantics(child: _turnLayer(turn)));
        }

        final labels = widget.labels;
        return Semantics(
          container: true,
          explicitChildNodes: true,
          liveRegion: true,
          label: labels.pageStatus(_page + 1, widget.pageCount),
          customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
            if (canGoNext) CustomSemanticsAction(label: labels.nextPage): () => turnNext(),
            if (canGoPrevious) CustomSemanticsAction(label: labels.previousPage): () => turnPrevious(),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onHorizontalDragCancel: _onDragCancel,
            onTapUp: _onTapUp,
            child: ClipRect(child: Stack(fit: StackFit.expand, children: children)),
          ),
        );
      },
    );
  }
}
