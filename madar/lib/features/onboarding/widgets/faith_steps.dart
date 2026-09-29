import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../../adhan/presentation/adhan_permissions_card.dart';
import '../../lock/application/lock_controller.dart';
import '../../lock/presentation/pin_sheets.dart';
import '../../prayer/prayer.dart';

/// One onboarding step's scrolling, vertically centred frame; its children
/// stagger in the first time the step shows.
class OnboardingStepFrame extends StatelessWidget {
  const OnboardingStepFrame({super.key, required this.id, required this.children});

  final String id;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Center(
            child: StaggerIn(id: id, crossAxisAlignment: CrossAxisAlignment.center, children: children),
          ),
        ),
      ),
    );
  }
}

/// The emblem, title and explanation at the top of a step.
class OnboardingStepHeading extends StatelessWidget {
  const OnboardingStepHeading({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.optional = false,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Adds "Optional – you can set this later in Settings".
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [t.accentSoft, t.space1.withValues(alpha: 0)]),
            border: Border.all(color: t.accent.withValues(alpha: 0.45)),
            boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: t.accentGlow.a * 0.6), blurRadius: 28)],
          ),
          child: Icon(icon, size: 40, color: t.gold),
        ),
        const SizedBox(height: Space.xl),
        Semantics(
          header: true,
          child: Text(title, textAlign: TextAlign.center, style: text.displaySmall),
        ),
        const SizedBox(height: Space.s),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.6),
          ),
        ),
        if (optional) ...[
          const SizedBox(height: Space.s),
          Text(
            l.onboardingOptional,
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(color: t.textTertiary),
          ),
        ],
      ],
    );
  }
}

/// A calm confirmation line: a check and what is now set.
class _Done extends StatelessWidget {
  const _Done({super.key, required this.label, this.icon = Icons.check_circle_rounded, this.done = true});

  final String label;
  final IconData icon;

  /// Set by the owner (a success accent) rather than a default.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: GlassCard(
        glow: false,
        borderColor: done ? t.success.withValues(alpha: 0.5) : null,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
        child: Row(
          children: [
            Icon(icon, color: done ? t.success : t.gold, size: 22),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(label, style: text.bodyLarge!.copyWith(color: t.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step: where the prayer times are calculated for – the prayer package's
/// own location flow (GPS with its explanation and every refusal handled,
/// or a city from the offline list). Skippable: the default city stays.
class OnboardingLocationStep extends ConsumerWidget {
  const OnboardingLocationStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final settings = ref.watch(prayerSettingsControllerProvider);
    final lang = ref.watch(appSettingsProvider.select((s) => s.languageCode));
    final cities = ref.watch(cityDatabaseProvider).value;
    final chosen = settings.locationSource != PrayerLocationSource.defaultCity;
    final place = l.placeLabel(settings, lang, cities: cities);
    return OnboardingStepFrame(
      id: 'onboarding-location',
      children: [
        OnboardingStepHeading(
          icon: Icons.explore_rounded,
          title: l.onboardingLocationTitle,
          body: l.onboardingLocationBody,
        ),
        const SizedBox(height: Space.xl),
        _Done(
          label: l.onboardingLocationFor(place),
          icon: chosen ? Icons.check_circle_rounded : Icons.place_rounded,
          done: chosen,
        ),
        const SizedBox(height: Space.m),
        MadarButton(
          label: chosen ? l.onboardingLocationChange : l.onboardingLocationSet,
          icon: Icons.my_location_rounded,
          // Continue is the step's primary action; this one is optional.
          variant: MadarButtonVariant.secondary,
          onPressed: () => unawaited(showPrayerLocationSheet(context)),
        ),
      ],
    );
  }
}

/// Step: what the adhan needs from Android (notifications, exact alarms,
/// the lock screen, battery optimisation) – the adhan's own permissions
/// card, live. Skippable: Settings › Adhan has the same card.
class OnboardingAdhanStep extends StatelessWidget {
  const OnboardingAdhanStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return OnboardingStepFrame(
      id: 'onboarding-adhan',
      children: [
        OnboardingStepHeading(
          icon: Icons.notifications_active_rounded,
          title: l.onboardingAdhanTitle,
          body: l.onboardingAdhanBody,
        ),
        const SizedBox(height: Space.xl),
        // The heading above already says what the card is for.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const AdhanPermissionsCard(showHeader: false),
        ),
      ],
    );
  }
}

/// Step (optional): the app lock – choose a PIN (and fingerprint) on the
/// lock package's own sheet. Skippable: a fresh install has no lock until a
/// PIN exists; Settings › Security offers it again.
class OnboardingLockStep extends ConsumerStatefulWidget {
  const OnboardingLockStep({super.key});

  @override
  ConsumerState<OnboardingLockStep> createState() => _OnboardingLockStepState();
}

class _OnboardingLockStepState extends ConsumerState<OnboardingLockStep> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _setUp() async {
    final result = await showPinSetupSheet(context);
    if (result == null || !mounted) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await ref.read(lockControllerProvider.notifier).setPin(result.pin, biometrics: result.biometrics ?? false);
      Fx.fire(Sfx.complete);
    } catch (e) {
      Fx.fire(Sfx.error);
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final lock = ref.watch(lockControllerProvider);
    return OnboardingStepFrame(
      id: 'onboarding-lock',
      children: [
        OnboardingStepHeading(
          icon: Icons.fingerprint_rounded,
          title: l.onboardingLockTitle,
          body: l.onboardingLockBody,
          optional: true,
        ),
        const SizedBox(height: Space.xl),
        AnimatedSwitcher(
          duration: context.motion(MadarMotion.medium),
          child: lock.armed
              ? _Done(
                  key: const ValueKey('on'),
                  label: lock.biometrics ? l.onboardingLockOnBio : l.onboardingLockOn,
                  icon: Icons.lock_rounded,
                )
              : MadarButton(
                  key: const ValueKey('set'),
                  label: l.onboardingLockSet,
                  icon: Icons.pin_rounded,
                  variant: MadarButtonVariant.secondary,
                  loading: _busy,
                  onPressed: _busy ? null : () => unawaited(_setUp()),
                ),
        ),
        if (_failed) ...[
          const SizedBox(height: Space.s),
          Text(
            l.lockSettingsSaveFailed,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.danger),
          ),
        ],
      ],
    );
  }
}
