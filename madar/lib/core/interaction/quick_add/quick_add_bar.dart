import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/themes.dart';
import '../../design/tokens.dart';
import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../numbers.dart';
import '../src/glass.dart';
import '../src/labels.dart';
import '../src/pressable.dart';
import 'parser.dart';
import 'preview.dart';
import 'quick_add_handler.dart';

/// Glass quick-add pill: type anything ("صرفت 12.5 دينار بنزين", "tomorrow
/// after isha call supplier") and watch live-parse chips (kind, amount,
/// window, date …) pop in as you type. Submitting hands the parsed
/// [QuickAddIntent] to [handler] or, by default, the app's
/// [quickAddHandlerProvider].
///
/// Feedback: Sfx.tap on send, Sfx.complete when added, Sfx.error (with a
/// shake and an announced message) when empty, unhandled or failed.
class QuickAddBar extends ConsumerStatefulWidget {
  const QuickAddBar({
    super.key,
    this.handler,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.hint,
    this.previewAbove = false,
    this.blur = true,
    this.clock,
    this.onIntentChanged,
    this.onAdded,
  });

  /// Overrides [quickAddHandlerProvider] for this bar.
  final QuickAddHandler? handler;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Placeholder (defaults to a localised example).
  final String? hint;

  /// Show the preview chips above the pill (for bars docked at the bottom).
  final bool previewAbove;

  /// Real backdrop blur behind the pill (turn off inside scrolling lists).
  final bool blur;

  /// Clock for relative dates ("tomorrow") – tests.
  final DateTime Function()? clock;
  final ValueChanged<QuickAddIntent>? onIntentChanged;

  /// Called after the handler accepted an intent.
  final ValueChanged<QuickAddIntent>? onAdded;

  @override
  ConsumerState<QuickAddBar> createState() => QuickAddBarState();
}

/// Public so parents can [submit] or read the live [intent].
class QuickAddBarState extends ConsumerState<QuickAddBar> with TickerProviderStateMixin {
  TextEditingController? _ownController;
  FocusNode? _ownFocus;
  QuickAddIntent? _intent;
  bool _busy = false;
  ({String text, bool error})? _status;
  Timer? _statusTimer;

  late final AnimationController _shake = AnimationController(vsync: this, duration: MadarMotion.long);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: MadarMotion.long);
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  TextEditingController get _controller => widget.controller ?? (_ownController ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  /// The live parse of the current text (null while empty).
  QuickAddIntent? get intent => _intent;

  bool get busy => _busy;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focus.addListener(_onFocus);
    _reparse();
  }

  @override
  void didUpdateWidget(QuickAddBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
      _reparse();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocus?.dispose();
    _statusTimer?.cancel();
    _shake.dispose();
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  void _onFocus() => setState(() {});

  void _onText() {
    final before = _intent;
    _reparse();
    if (_status?.error == true) _clearStatus();
    if (before != _intent) setState(() {});
  }

  void _reparse() {
    final text = _controller.text;
    final next = text.trim().isEmpty ? null : QuickAddParser.parse(text, now: _now());
    if (next == _intent) return;
    _intent = next;
    if (next != null) widget.onIntentChanged?.call(next);
  }

  void _setStatus(String text, {required bool error}) {
    _statusTimer?.cancel();
    setState(() => _status = (text: text, error: error));
    _statusTimer = Timer(const Duration(milliseconds: 2800), _clearStatus);
  }

  void _clearStatus() {
    _statusTimer?.cancel();
    if (mounted && _status != null) setState(() => _status = null);
  }

  void _fail(String message) {
    Fx.fire(Sfx.error);
    if (!context.reducedMotion) _shake.forward(from: 0);
    _setStatus(message, error: true);
  }

  /// Parses and hands the text to the handler. Returns whether it was added.
  Future<bool> submit() async {
    if (_busy) return false;
    final l10n = L10n.of(context);
    final text = _controller.text;
    if (text.trim().isEmpty) {
      _fail(l10n.interactionQuickAddEmpty);
      return false;
    }
    final handler = widget.handler ?? ref.read(quickAddHandlerProvider);
    if (handler == null) {
      _fail(l10n.interactionQuickAddUnavailable);
      return false;
    }
    Fx.fire(Sfx.tap);
    final intent = QuickAddParser.parse(text, now: _now());
    setState(() => _busy = true);
    if (!context.reducedMotion) unawaited(_spin.repeat());
    var ok = false;
    try {
      ok = await handler.handle(intent);
    } catch (e, s) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: s, library: 'madar quick add'));
    }
    if (!mounted) return ok;
    _spin
      ..stop()
      ..value = 0;
    setState(() => _busy = false);
    if (!ok) {
      _fail(l10n.interactionQuickAddFailed);
      return false;
    }
    Fx.fire(Sfx.complete);
    if (!context.reducedMotion) unawaited(_pulse.forward(from: 0));
    _controller.clear();
    _setStatus(l10n.interactionQuickAddAdded, error: false);
    widget.onAdded?.call(intent);
    return true;
  }

  /// Direction of the text as typed (Arabic → RTL, Latin → LTR), so mixed
  /// input reads naturally regardless of the UI language.
  static TextDirection? _typedDirection(String text) {
    for (final c in text.runes) {
      final arabic =
          (c >= 0x0600 && c <= 0x06FF) ||
          (c >= 0x0750 && c <= 0x077F) ||
          (c >= 0x08A0 && c <= 0x08FF) ||
          (c >= 0xFB50 && c <= 0xFDFF) ||
          (c >= 0xFE70 && c <= 0xFEFF);
      if (arabic && !LocalizedNumbers.isDigitUnit(c) && c != 0x066B && c != 0x066C) return TextDirection.rtl;
      final latin = (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
      if (latin) return TextDirection.ltr;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final focused = _focus.hasFocus;
    final intent = _intent;
    final hasText = _controller.text.trim().isNotEmpty;
    final radius = BorderRadius.circular(t.radiusXL);

    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      textDirection: _typedDirection(_controller.text),
      textInputAction: TextInputAction.send,
      keyboardType: TextInputType.text,
      minLines: 1,
      maxLines: 1,
      style: text.bodyLarge?.copyWith(color: t.textPrimary),
      cursorColor: t.accent,
      decoration: InputDecoration(
        hintText: widget.hint ?? l10n.interactionQuickAddHint,
        hintStyle: text.bodyMedium?.copyWith(color: t.textTertiary),
        hintMaxLines: 1,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsetsDirectional.symmetric(vertical: Space.m),
      ),
      onSubmitted: (_) => submit(),
    );

    Widget pill = InteractionGlass(
      borderRadius: radius,
      blur: widget.blur,
      dense: !widget.blur,
      borderColor: focused ? t.accent.withValues(alpha: 0.75) : null,
      glowColor: focused ? t.accentGlow.withValues(alpha: t.accentGlow.a * 0.55) : t.glassShadow,
      glowSigma: focused ? 22 : 16,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.xs + 2, Space.xs + 2, Space.xs + 2),
      child: Row(
        children: [
          ExcludeSemantics(
            child: _KindOrb(
              kind: intent?.kind,
              confidence: intent?.confidence ?? 0,
              spin: _spin,
              pulse: _pulse,
              busy: _busy,
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(child: field),
          const SizedBox(width: Space.xs),
          _SendButton(enabled: hasText && !_busy, busy: _busy, label: l10n.actionAdd, onTap: submit),
        ],
      ),
    );

    pill = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final v = _shake.value;
        final dx = v == 0 || v == 1 ? 0.0 : math.sin(v * math.pi * 6) * (1 - v) * 9;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: pill,
    );

    final facets = intent == null ? const <QuickAddFacet>[] : quickAddFacets(intent);
    final preview = AnimatedSize(
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.emphasized,
      alignment: widget.previewAbove ? AlignmentDirectional.bottomStart : AlignmentDirectional.topStart,
      child: facets.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsetsDirectional.only(
                top: widget.previewAbove ? 0 : Space.s,
                bottom: widget.previewAbove ? Space.s : 0,
                start: Space.m,
                end: Space.m,
              ),
              child: Semantics(
                container: true,
                label: l10n.interactionQuickAddPreview,
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: Space.xs + 2,
                    runSpacing: Space.xs + 2,
                    children: [
                      for (final (i, f) in facets.indexed)
                        _PopIn(
                          key: ValueKey('$f:${_facetText(context, intent!, f)}'),
                          delay: MadarMotion.staggerStep * i,
                          child: _PreviewChip(
                            icon: _facetIcon(intent, f),
                            label: _facetText(context, intent, f),
                            primary: f == QuickAddFacet.kind,
                            dot: f == QuickAddFacet.planet ? PlanetPalettes.byKey[intent.planetKey]?.surface : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );

    final status = _status;
    final statusLine = AnimatedSize(
      duration: context.motion(MadarMotion.short),
      curve: MadarMotion.emphasized,
      alignment: AlignmentDirectional.topStart,
      child: AnimatedSwitcher(
        duration: context.motion(MadarMotion.short),
        child: status == null
            ? const SizedBox(width: double.infinity, key: ValueKey('none'))
            : Padding(
                key: ValueKey(status),
                padding: const EdgeInsetsDirectional.only(top: Space.s, start: Space.l, end: Space.l),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      Icon(
                        status.error ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
                        size: 15,
                        color: status.error ? t.danger : t.success,
                      ),
                      const SizedBox(width: Space.xs + 2),
                      Expanded(
                        child: Text(
                          status.text,
                          style: text.bodySmall?.copyWith(color: status.error ? t.danger : t.success),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.previewAbove ? [preview, pill, statusLine] : [pill, preview, statusLine],
    );
  }

  static IconData _facetIcon(QuickAddIntent i, QuickAddFacet f) => switch (f) {
    QuickAddFacet.kind => KitLabels.kindIcon(i.kind),
    QuickAddFacet.amount => i.kind == QuickAddKind.income ? Icons.south_west_rounded : Icons.north_east_rounded,
    QuickAddFacet.water => Icons.water_drop_rounded,
    QuickAddFacet.score => i.kind == QuickAddKind.pain ? Icons.healing_rounded : Icons.mood_rounded,
    QuickAddFacet.date => Icons.event_rounded,
    QuickAddFacet.time => Icons.schedule_rounded,
    QuickAddFacet.window => KitLabels.windowIcon(i.window!),
    QuickAddFacet.planet => Icons.public_rounded,
  };

  static String _facetText(BuildContext context, QuickAddIntent i, QuickAddFacet f) {
    final l = L10n.of(context);
    switch (f) {
      case QuickAddFacet.kind:
        return KitLabels.kind(l, i.kind);
      case QuickAddFacet.amount:
        final amount = LocalizedNumbers.formatMilli(i.amountMilli!);
        final cur = i.currency;
        return cur == null ? amount : '$amount ${KitLabels.currencySymbol(l, cur)}';
      case QuickAddFacet.water:
        return l.interactionQuickAddMl('${i.ml}');
      case QuickAddFacet.score:
        return l.interactionQuickAddScore('${i.score}', i.kind == QuickAddKind.pain ? 10 : 5);
      case QuickAddFacet.date:
        return KitLabels.date(context, i.date!);
      case QuickAddFacet.time:
        return l.interactionQuickAddAt(KitLabels.time(context, i.time!));
      case QuickAddFacet.window:
        return KitLabels.window(l, i.window!);
      case QuickAddFacet.planet:
        return KitLabels.planet(l, i.planetKey!);
    }
  }
}

/// The kind medallion at the start of the pill: the parsed kind's icon inside
/// an accent orb, ringed by an arc showing how sure the parser is. Spins while
/// the handler works and sends out a success ripple when the item is added.
class _KindOrb extends StatelessWidget {
  const _KindOrb({
    required this.kind,
    required this.confidence,
    required this.spin,
    required this.pulse,
    required this.busy,
  });

  final QuickAddKind? kind;
  final double confidence;
  final Animation<double> spin;
  final Animation<double> pulse;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final motion = context.motion(MadarMotion.medium);
    final k = kind;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: 42,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: k == null ? 0 : confidence),
          duration: motion,
          curve: MadarMotion.emphasized,
          builder: (context, c, child) => AnimatedBuilder(
            animation: Listenable.merge([spin, pulse]),
            builder: (context, child) => CustomPaint(
              painter: _OrbRingPainter(
                confidence: c,
                rotation: busy ? spin.value * 2 * math.pi : 0,
                pulse: pulse.isAnimating ? pulse.value : 0,
                arc: Color.lerp(t.accent, t.gold, 0.35)!,
                track: t.glassBorder,
                success: t.success,
                busy: busy,
              ),
              child: child,
            ),
            child: child,
          ),
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [
                    Color.lerp(t.accent, t.glassHighlight, 0.3)!,
                    t.accent,
                    Color.lerp(t.accent, t.space0, 0.4)!,
                  ],
                  stops: const [0, 0.55, 1],
                ),
                boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: t.accentGlow.a * 0.6), blurRadius: 10)],
              ),
              child: AnimatedSwitcher(
                duration: context.motion(MadarMotion.short),
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: Icon(
                  k == null ? Icons.add_rounded : KitLabels.kindIcon(k),
                  key: ValueKey(k),
                  size: 17,
                  color: t.textOnAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbRingPainter extends CustomPainter {
  _OrbRingPainter({
    required this.confidence,
    required this.rotation,
    required this.pulse,
    required this.arc,
    required this.track,
    required this.success,
    required this.busy,
  });

  final double confidence, rotation, pulse;
  final Color arc, track, success;
  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = track,
    );
    final sweep = busy ? math.pi * 0.6 : 2 * math.pi * confidence.clamp(0.0, 1.0);
    if (sweep > 0.01) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2 + rotation,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = arc,
      );
    }
    if (pulse > 0 && pulse < 1) {
      final e = Curves.easeOutCubic.transform(pulse);
      canvas.drawCircle(
        c,
        r + 10 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - e) + 0.5
          ..color = success.withValues(alpha: (1 - e) * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbRingPainter old) =>
      old.confidence != confidence ||
      old.rotation != rotation ||
      old.pulse != pulse ||
      old.arc != arc ||
      old.track != track ||
      old.success != success ||
      old.busy != busy;
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.busy, required this.label, required this.onTap});

  final bool enabled;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final motion = context.motion(MadarMotion.short);
    return KitPressable(
      onTap: onTap,
      // Tapping while empty explains why nothing happens (submit fires the
      // error sound itself).
      onDisabledTap: busy ? null : onTap,
      enabled: enabled,
      sfx: null,
      pressScale: 0.9,
      semanticLabel: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: motion,
        curve: MadarMotion.emphasized,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(t.accent, t.glassHighlight, 0.2)!, t.accent],
                )
              : null,
          color: enabled ? null : t.glassFill,
          border: Border.all(color: enabled ? t.accent : t.glassBorder, width: 0.9),
          boxShadow: enabled
              ? [BoxShadow(color: t.accentGlow.withValues(alpha: t.accentGlow.a * 0.6), blurRadius: 14)]
              : null,
        ),
        child: AnimatedScale(
          duration: motion,
          curve: context.reducedMotion ? Curves.linear : Curves.easeOutBack,
          scale: enabled ? 1 : 0.86,
          child: Icon(Icons.send_rounded, size: 19, color: enabled ? t.textOnAccent : t.textTertiary),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.label, this.primary = false, this.dot});

  final IconData icon;
  final String label;
  final bool primary;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.labelMedium;
    final fg = primary ? t.accent : t.textSecondary;
    return Container(
      height: 30,
      padding: const EdgeInsetsDirectional.only(start: Space.s + 2, end: Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusXL),
        color: primary ? t.accentSoft : t.glassFill,
        border: Border.all(color: primary ? t.accent.withValues(alpha: 0.55) : t.glassBorder, width: 0.8),
        boxShadow: primary
            ? [BoxShadow(color: t.accentGlow.withValues(alpha: t.accentGlow.a * 0.3), blurRadius: 10)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null)
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsetsDirectional.only(end: Space.xs + 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot,
                boxShadow: [BoxShadow(color: dot!.withValues(alpha: 0.7), blurRadius: 6)],
              ),
            )
          else ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: Space.xs + 1),
          ],
          Text(label, style: style?.copyWith(color: primary ? t.accent : t.textPrimary)),
        ],
      ),
    );
  }
}

/// Springs a chip in (scale + fade) the first time it appears.
class _PopIn extends StatefulWidget {
  const _PopIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reducedMotion) {
      _c.value = 1;
      return;
    }
    void go() {
      if (mounted) _c.animateWith(SpringSimulation(MadarMotion.bouncy, 0, 1, 0));
    }

    if (widget.delay == Duration.zero) {
      go();
    } else {
      _timer = Timer(widget.delay, go);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final v = _c.value;
        if ((v - 1).abs() < 0.001 && !_c.isAnimating) return child!;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.7 + 0.3 * v, child: child),
        );
      },
      child: widget.child,
    );
  }
}
