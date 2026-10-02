import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';

/// A short glass note at the bottom of the screen (copied, saved …): a
/// live region for screen readers, gone after [duration].
abstract final class QuranToast {
  static OverlayEntry? _current;

  static void show(BuildContext context, String message, {IconData icon = Icons.check_rounded, Duration? duration}) {
    final overlay =
        Navigator.maybeOf(context, rootNavigator: true)?.overlay ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _current?.remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Toast(
        message: message,
        icon: icon,
        tokens: context.tokens,
        textStyle: Theme.of(context).textTheme.labelLarge!,
        reduced: context.reducedMotion,
        duration: duration ?? const Duration(milliseconds: 2200),
        onDone: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.icon,
    required this.tokens,
    required this.textStyle,
    required this.reduced,
    required this.duration,
    required this.onDone,
  });

  final String message;
  final IconData icon;
  final MadarTokens tokens;
  final TextStyle textStyle;
  final bool reduced;
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.reduced ? MadarMotion.reduced : MadarMotion.medium,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_c.forward());
    _timer = Timer(widget.duration, () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom + UndoToast.bottomInset + Space.xl;
    return Positioned(
      left: Space.gutter,
      right: Space.gutter,
      bottom: bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _c, curve: MadarMotion.standard),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero)
                .animate(CurvedAnimation(parent: _c, curve: MadarMotion.decelerate)),
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.xl, Space.m),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(t.glassFill, t.space2).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(t.radiusXL),
                      border: Border.all(color: t.glassBorder),
                      boxShadow: [BoxShadow(color: t.glassShadow, blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 18, color: t.success),
                        const SizedBox(width: Space.s),
                        Flexible(child: Text(widget.message, style: widget.textStyle.copyWith(color: t.textPrimary))),
                      ],
                    ),
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
