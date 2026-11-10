import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/gen/app_localizations.dart';
import '../../core/kids_section.dart' show kidsStarCountProvider;
import '../application/kids_providers.dart';
import 'kids_palette.dart';

/// Screen 1b: the one plain sentence about pinning the screen, offered when
/// kids mode is entered. Either answer goes on to the kids home; nothing here
/// can leave Madar.
class KidsPinOffer extends ConsumerWidget {
  const KidsPinOffer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    void done() => ref.read(kidsPinOfferPendingProvider.notifier).set(false);
    return Material(
      key: const ValueKey('kids-pin-offer'),
      color: KidsColors.night900,
      child: KidsNightBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const KhatamStar(
                          size: 150,
                          color: KidsColors.sun500,
                          child: Icon(Icons.stars_rounded, color: KidsColors.teal500, size: 60),
                        ),
                        const SizedBox(height: 20),
                        Text(l.kidsShellEntryTitle, style: KidsText.title(Colors.white, size: 38)),
                      ],
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: KidsColors.paper,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const KhatamStar(
                              size: 64,
                              color: KidsColors.teal100,
                              child: Icon(Icons.verified_user_rounded, color: KidsColors.teal700, size: 30),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: KidsColors.night100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 4),
                                      child: Text(
                                        l.kidsShellPinOfferBadge,
                                        style: KidsText.text(KidsColors.night800, size: 15, weight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                  Text(l.kidsShellPinOfferTitle, style: KidsText.title(KidsColors.ink, size: 28)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(l.kidsShellPinOfferBody, style: KidsText.text(KidsColors.ink, size: 20)),
                        const SizedBox(height: 16),
                        KidsBigButton(
                          key: const ValueKey('kids-offer-pin'),
                          label: l.kidsShellPinOfferYes,
                          icon: Icons.verified_user_rounded,
                          tone: KidsButtonTone.teal,
                          onPressed: () async {
                            await ref.read(kidsPinningProvider).start();
                            done();
                          },
                        ),
                        const SizedBox(height: 10),
                        KidsBigButton(
                          key: const ValueKey('kids-offer-skip'),
                          label: l.kidsShellPinOfferNo,
                          tone: KidsButtonTone.ghost,
                          onPressed: done,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.kidsShellPinOfferLater,
                          textAlign: TextAlign.center,
                          style: KidsText.text(KidsColors.ink2, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen 12: «خلص وقت اللعب اليوم». Gentle, no red, the stars kept. «تمام»
/// leads to the parent gate (nothing more is playable today); «للأهل: زيادة
/// الوقت» does too.
class KidsEndScreen extends ConsumerWidget {
  const KidsEndScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final stars = ref.watch(kidsStarCountProvider);
    void parents() => ref.read(kidsParentPhaseProvider.notifier).openGate();
    return Material(
      key: const ValueKey('kids-end-screen'),
      color: KidsColors.night900,
      child: KidsNightBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 28, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.nightlight_round, color: KidsColors.sun100, size: 140),
                      const SizedBox(height: 24),
                      Text(
                        l.kidsShellEndTitle,
                        textAlign: TextAlign.center,
                        style: KidsText.title(Colors.white, size: 36),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.kidsShellEndBody,
                        textAlign: TextAlign.center,
                        style: KidsText.text(KidsColors.night100, size: 20),
                      ),
                      const SizedBox(height: 20),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0x22FFFFFF),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: KidsColors.night300),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const KhatamStar(size: 32, color: KidsColors.sun500),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  kidsDigits(context, l.kidsShellEndStars(stars)),
                                  style: KidsText.text(Colors.white, size: 18, weight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      KidsBigButton(
                        key: const ValueKey('kids-end-ok'),
                        label: l.kidsShellEndOk,
                        icon: Icons.nightlight_round,
                        height: 88,
                        onPressed: parents,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        key: const ValueKey('kids-end-parents'),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(kKidsMinTarget, kKidsMinTarget),
                          foregroundColor: KidsColors.night300,
                        ),
                        onPressed: parents,
                        icon: const Icon(Icons.lock_rounded, size: 20),
                        label: Text(l.kidsShellEndParent, style: KidsText.text(KidsColors.night300, size: 17)),
                      ),
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

/// The gentle five-minute warning: a small pill, never in the way of touches.
class KidsWarningPill extends ConsumerWidget {
  const KidsWarningPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(kidsTimeProvider.select((t) => t.remainingMinutes)) ?? 0;
    final l = L10n.of(context);
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topCenter,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(top: 8),
            child: DecoratedBox(
              key: const ValueKey('kids-warning-pill'),
              decoration: BoxDecoration(
                color: KidsColors.sun100,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: KidsColors.sun500, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  kidsDigits(context, l.kidsShellWarning(minutes)),
                  style: KidsText.text(KidsColors.night900, size: 16, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every text on a kids screen can have a speaker button for a child who cannot
/// read it yet. OPTIONAL and SILENT until voices exist: it speaks through
/// [kidsSpeakProvider], which does nothing until the recordings are wired in.
/// Other kids folders may place it next to any text; a 64-point target.
class KidsSpeakButton extends ConsumerWidget {
  const KidsSpeakButton({super.key, required this.textId});

  /// Which text it reads, e.g. `letters.alef.name`.
  final String textId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => KidsRoundButton(
    icon: Icons.volume_up_rounded,
    semanticLabel: L10n.of(context).kidsShellSpeak,
    background: KidsColors.teal100,
    foreground: KidsColors.teal700,
    onPressed: () => unawaited(ref.read(kidsSpeakProvider)(textId)),
  );
}
