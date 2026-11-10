import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/gen/app_localizations.dart';
import '../../core/kids_section.dart' show kidsReligiousUnlockedProvider;
import '../application/kids_actions.dart';
import '../application/kids_providers.dart';
import '../domain/kids_logic.dart';
import 'kids_palette.dart';

/// The parent corner: what is behind the gate. Leave kids mode, the daily
/// screen-time limit, pinning the screen again, and one read-only line about
/// the religious section. It makes no network call and closes by itself when
/// the app leaves the foreground, so a phone handed back never stays open.
class KidsParentCorner extends ConsumerStatefulWidget {
  const KidsParentCorner({super.key});

  @override
  ConsumerState<KidsParentCorner> createState() => _KidsParentCornerState();
}

class _KidsParentCornerState extends ConsumerState<KidsParentCorner> {
  bool _pinSupported = false;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPinning());
  }

  Future<void> _refreshPinning() async {
    final pinning = ref.read(kidsPinningProvider);
    final supported = await pinning.supported;
    final pinned = supported && await pinning.isPinned();
    if (mounted) {
      setState(() {
        _pinSupported = supported;
        _pinned = pinned;
      });
    }
  }

  Future<void> _pin() async {
    await ref.read(kidsPinningProvider).start();
    await _refreshPinning();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final mode = ref.watch(kidsModeProvider);
    final used = ref.watch(kidsTimeProvider).usedSeconds;
    final religiousHidden = !ref.watch(kidsReligiousUnlockedProvider);
    final limit = mode.limitMinutes;
    final stepLimit = ref.read(kidsModeProvider.notifier).stepLimit;

    return Material(
      key: const ValueKey('kids-parent-corner'),
      color: KidsColors.paper,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(20),
          children: [
            Text(
              l.kidsShellCornerTitle,
              style: KidsText.title(KidsColors.ink, size: 34),
            ),
            const SizedBox(height: 16),
            KidsBigButton(
              key: const ValueKey('kids-corner-leave'),
              label: l.kidsShellCornerLeave,
              icon: Icons.logout_rounded,
              tone: KidsButtonTone.teal,
              onPressed: () => unawaited(ref.read(kidsActionsProvider).leave()),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, bottom: 16),
              child: Text(
                l.kidsShellCornerLeaveHint,
                textAlign: TextAlign.center,
                style: KidsText.text(KidsColors.ink2, size: 16),
              ),
            ),
            _Card(
              title: l.kidsShellCornerTimeTitle,
              child: Column(
                children: [
                  Row(
                    children: [
                      KidsRoundButton(
                        key: const ValueKey('kids-limit-less'),
                        icon: Icons.remove_rounded,
                        semanticLabel: l.kidsShellCornerLess,
                        background: KidsColors.night100,
                        foreground: KidsColors.night800,
                        onPressed: limit <= 0
                            ? null
                            : () => stepLimit(up: false),
                      ),
                      Expanded(
                        child: Text(
                          key: const ValueKey('kids-limit-value'),
                          kidsDigits(
                            context,
                            l.kidsShellCornerTimeValue(limit),
                          ),
                          textAlign: TextAlign.center,
                          style: KidsText.title(KidsColors.ink, size: 28),
                        ),
                      ),
                      KidsRoundButton(
                        key: const ValueKey('kids-limit-more'),
                        icon: Icons.add_rounded,
                        semanticLabel: l.kidsShellCornerMore,
                        background: KidsColors.night100,
                        foreground: KidsColors.night800,
                        onPressed: limit >= ScreenTimeRules.maxLimitMinutes
                            ? null
                            : () => stepLimit(up: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kidsDigits(context, l.kidsShellCornerTimeUsed(used ~/ 60)),
                    textAlign: TextAlign.center,
                    style: KidsText.text(KidsColors.ink2, size: 16),
                  ),
                  Text(
                    l.kidsShellCornerTimeHint,
                    textAlign: TextAlign.center,
                    style: KidsText.text(KidsColors.ink2, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              title: l.kidsShellCornerPinTitle,
              child: Column(
                children: [
                  Text(
                    !_pinSupported
                        ? l.kidsShellCornerPinUnsupported
                        : (_pinned
                              ? l.kidsShellCornerPinOn
                              : l.kidsShellCornerPinOff),
                    textAlign: TextAlign.center,
                    style: KidsText.text(KidsColors.ink, size: 18),
                  ),
                  if (_pinSupported && !_pinned) ...[
                    const SizedBox(height: 12),
                    KidsBigButton(
                      key: const ValueKey('kids-corner-pin'),
                      label: l.kidsShellCornerPinAction,
                      icon: Icons.push_pin_rounded,
                      tone: KidsButtonTone.gold,
                      onPressed: () => unawaited(_pin()),
                    ),
                  ],
                ],
              ),
            ),
            if (religiousHidden) ...[
              const SizedBox(height: 12),
              _Card(
                title: l.kidsShellCornerReligiousTitle,
                child: Text(
                  key: const ValueKey('kids-religious-line'),
                  l.kidsShellCornerReligiousHidden,
                  textAlign: TextAlign.center,
                  style: KidsText.text(KidsColors.ink, size: 18),
                ),
              ),
            ],
            const SizedBox(height: 20),
            KidsBigButton(
              key: const ValueKey('kids-corner-back'),
              label: l.kidsShellCornerBack,
              icon: Icons.home_rounded,
              tone: KidsButtonTone.ghost,
              onPressed: ref.read(kidsParentPhaseProvider.notifier).close,
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: KidsColors.sand2, width: 2),
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: KidsText.title(KidsColors.night800, size: 22)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
