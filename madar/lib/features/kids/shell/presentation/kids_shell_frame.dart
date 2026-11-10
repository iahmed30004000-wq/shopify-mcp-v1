import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing/router.dart' show routerProvider;
import '../application/kids_providers.dart';
import '../domain/kids_logic.dart';
import 'kids_overlays.dart';
import 'kids_palette.dart';
import 'kids_parent_corner.dart';
import 'kids_parent_gate.dart';

/// The frame around everything under `/kids/**` (a `ShellRoute` builds it):
/// the kids look, the foreground play-time counter, and the layers only a parent
/// can pass – the pin-the-screen offer, the end-of-time scene, the PIN gate and
/// the parent corner.
///
/// * **Back never leaves.** At the kids root (and on the end scene, the offer)
///   the system Back, the back gesture and a held Back open the parent gate; on
///   the gate or the corner they close it; inside a section they pop to the
///   home. Nothing here can reach the adult app.
/// * **Screen time** counts only while the app is in the foreground (a phone
///   call, the recents list or a locked screen pause it), once a second, and
///   never counts a clock jump (see [ScreenTimeRules.tickSeconds]).
class KidsShellFrame extends ConsumerStatefulWidget {
  const KidsShellFrame({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KidsShellFrame> createState() => _KidsShellFrameState();
}

class _KidsShellFrameState extends ConsumerState<KidsShellFrame> with WidgetsBindingObserver {
  Timer? _timer;
  late DateTime _last;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _last = ref.read(kidsClockProvider)();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted || !_foreground) return;
    final now = ref.read(kidsClockProvider)();
    final seconds = ScreenTimeRules.tickSeconds(_last, now);
    _last = now;
    final ended = ref.read(kidsTimeProvider).status == ScreenTimeStatus.ended;
    // Time behind the parent's own layers is the parent's, not the child's.
    final parent = ref.read(kidsParentPhaseProvider) != KidsParentPhase.none || ref.read(kidsPinOfferPendingProvider);
    // At the limit nothing more is counted, but the day is still watched: at
    // midnight a fresh day begins and the end scene lifts.
    ref.read(kidsModeProvider.notifier).play(ended || parent ? 0 : seconds);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed) {
      _last = ref.read(kidsClockProvider)();
      _foreground = true;
      _tick();
      return;
    }
    // Leaving the foreground (a call, recents, the screen locking): stop
    // counting at once and write what has been played.
    _foreground = false;
    ref.read(kidsModeProvider.notifier).play(0, flush: true);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // A phone handed back must not still be open on the parent's corner.
      if (ref.read(kidsParentPhaseProvider) == KidsParentPhase.corner) {
        ref.read(kidsParentPhaseProvider.notifier).close();
      }
    }
  }

  Future<bool> _onBack() async {
    final phase = ref.read(kidsParentPhaseProvider);
    final flow = ref.read(kidsParentPhaseProvider.notifier);
    if (phase != KidsParentPhase.none) {
      flow.close();
      return true;
    }
    if (ref.read(kidsPinOfferPendingProvider)) {
      // The offer is answered with its own two buttons; Back never leaves.
      return true;
    }
    if (ref.read(kidsTimeProvider).status == ScreenTimeStatus.ended) {
      flow.openGate();
      return true;
    }
    // Inside a section (or anywhere the shell's navigator holds more than one
    // page) the router pops one page, back towards the kids home; at the root
    // there is nothing to pop and Back means "a parent, please".
    if (ref.read(routerProvider).canPop()) return false;
    flow.openGate();
    return true;
  }

  ThemeData _theme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: KidsColors.paper,
      colorScheme: ColorScheme.fromSeed(seedColor: KidsColors.night700, surface: KidsColors.paper),
      textTheme: base.textTheme.apply(
        fontFamily: KidsText.body,
        bodyColor: KidsColors.ink,
        displayColor: KidsColors.ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(kidsParentPhaseProvider);
    final offer = ref.watch(kidsPinOfferPendingProvider);
    final status = ref.watch(kidsTimeProvider.select((t) => t.status));
    final ended = status == ScreenTimeStatus.ended;
    final covered = offer || ended || phase != KidsParentPhase.none;

    return BackButtonListener(
      onBackButtonPressed: _onBack,
      child: Theme(
        data: _theme(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: covered,
              child: ExcludeSemantics(excluding: covered, child: widget.child),
            ),
            if (status == ScreenTimeStatus.warning && !covered) const KidsWarningPill(),
            if (ended) const KidsEndScreen(),
            if (offer) const KidsPinOffer(),
            if (phase == KidsParentPhase.gate) const KidsParentGate(),
            if (phase == KidsParentPhase.corner) const KidsParentCorner(),
          ],
        ),
      ),
    );
  }
}
