import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/recitation/recitation.dart' show NowPlayingBar, NowPlayingSheet, recitationStateProvider;
import '../design/tokens.dart';
import '../interaction/sheets/sheet.dart' show InteractionSheetRoute;
import '../motion/motion.dart';

/// Docks the mini player ([NowPlayingBar]) at the bottom of a Quran, wird or
/// Hifz page while a recitation plays.
///
/// The bar floats over the page's own backdrop; while it shows, the page's
/// bottom inset grows by the bar's height **at once** (not along the bar's
/// entrance), so a fitted mushaf page is laid out once rather than on every
/// frame, and nothing on the page is ever covered. With the keyboard up the
/// bar steps aside (and reserves nothing).
class NowPlayingDock extends ConsumerWidget {
  const NowPlayingDock({super.key, required this.child});

  final Widget child;

  /// The bar's height with its bottom margin at the ambient text scale: the
  /// 48 px play ring, or the two text lines when larger text outgrows it,
  /// inside the glass pill's padding.
  static double extentOf(BuildContext context) =>
      math.max(48.0, MediaQuery.textScalerOf(context).scale(38)) + Space.s * 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(recitationStateProvider.select((s) => s.active));
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom > 0;
    final reserve = active && !keyboard ? extentOf(context) : 0.0;
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(bottom: media.padding.bottom + reserve),
            viewPadding: media.viewPadding.copyWith(bottom: media.viewPadding.bottom + reserve),
          ),
          child: child,
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: Offstage(
            offstage: keyboard,
            child: const SafeArea(top: false, child: NowPlayingBar()),
          ),
        ),
      ],
    );
  }
}

/// `/now-playing`: the full player as a routed sheet over the page
/// underneath (the same rise, scrim and drag-to-dismiss as the mini
/// player's sheet), e.g. from a tap on the media notification. Nothing
/// playing: the sheet closes itself at once.
class NowPlayingSheetPage extends Page<void> {
  const NowPlayingSheetPage({super.key, super.name});

  @override
  Route<void> createRoute(BuildContext context) => InteractionSheetRoute<void>(
    settings: this,
    builder: (_) => const _NowPlayingRouteBody(),
    tokens: context.tokens,
    reduced: context.reducedMotion,
    barrierText: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  );
}

class _NowPlayingRouteBody extends ConsumerStatefulWidget {
  const _NowPlayingRouteBody();

  @override
  ConsumerState<_NowPlayingRouteBody> createState() => _NowPlayingRouteBodyState();
}

class _NowPlayingRouteBodyState extends ConsumerState<_NowPlayingRouteBody> {
  @override
  void initState() {
    super.initState();
    if (!ref.read(recitationStateProvider).active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(Navigator.of(context).maybePop());
      });
    }
  }

  @override
  Widget build(BuildContext context) => const NowPlayingSheet();
}
