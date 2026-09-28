import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/seed/seeder.dart';
import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/providers.dart';
import '../../core/routing/routes.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sound/sound_api.dart';
import '../settings/settings_controller.dart';
import '../settings/widgets/appearance_pickers.dart';
import 'widgets/orbit_emblem.dart';

/// Where onboarding hands over.
enum OnboardingExit { home, import }

/// Marks onboarding as done and returns the location to go to. Pure –
/// unit-tested.
({AppSettings settings, String location}) completeOnboarding(AppSettings s, OnboardingExit exit) => (
  settings: SettingsChanges.onboarded(s),
  location: exit == OnboardingExit.import ? AppRoutes.import : AppRoutes.home,
);

/// First launch, three cinematic steps over the cosmos:
/// 1. Welcome – "your day orbits the five prayers".
/// 2. Language and look – both apply live (the layout flips direction and
///    the whole screen re-themes as you tap).
/// 3. Start empty, or import the prototype's JSON export.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  static const int stepCount = 3;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pages = PageController();
  int _step = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    final target = step.clamp(0, OnboardingScreen.stepCount - 1);
    if (context.reducedMotion) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(target, duration: MadarMotion.long, curve: MadarMotion.emphasized);
    }
  }

  void _finish(OnboardingExit exit) {
    final next = completeOnboarding(ref.read(appSettingsProvider), exit);
    Fx.fire(exit == OnboardingExit.home ? Sfx.levelUp : Sfx.navigate);
    ref.updateSettings((_) => next.settings);
    // The database was seeded on first launch, before the language was
    // picked: move the untouched default lists into the chosen language.
    unawaited(
      MadarSeeder(ref.read(databaseProvider))
          .relocalizeDefaults(next.settings.languageCode)
          .then((_) {}, onError: (Object e, StackTrace st) => debugPrint('Relocalising the defaults failed: $e')),
    );
    context.go(next.location);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final batterySaver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final last = _step == OnboardingScreen.stepCount - 1;
    // System / predictive back walks the steps like the on-screen arrow;
    // only step 1 lets the route (and so the app) close.
    return PopScope<void>(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Fx.fire(Sfx.back);
        _goTo(_step - 1);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CosmosBackdrop(intensity: 1.25, seed: 0.11, animate: !batterySaver),
          Scaffold(
            backgroundColor: t.space0.withValues(alpha: 0),
            body: SafeArea(
              child: BackdropGroup(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.m, 0),
                      child: SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            _StepStars(
                              step: _step,
                              label: l.onboardingStep(
                                fmt.formatInt(_step + 1),
                                fmt.formatInt(OnboardingScreen.stepCount),
                              ),
                            ),
                            const Spacer(),
                            AnimatedOpacity(
                              opacity: last ? 0 : 1,
                              duration: context.motion(MadarMotion.short),
                              child: IgnorePointer(
                                ignoring: last,
                                child: MadarButton(
                                  label: l.onboardingSkip,
                                  variant: MadarButtonVariant.ghost,
                                  size: MadarButtonSize.small,
                                  onPressed: () => _goTo(OnboardingScreen.stepCount - 1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        onPageChanged: (i) {
                          Fx.fire(Sfx.swipe);
                          setState(() => _step = i);
                        },
                        children: [
                          _WelcomeStep(animate: !batterySaver),
                          const _StyleStep(),
                          _StartStep(onFinish: _finish),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.l),
                      child: SizedBox(
                        height: MadarButton.heightFor(MadarButtonSize.large),
                        child: Row(
                          children: [
                            AnimatedSwitcher(
                              duration: context.motion(MadarMotion.short),
                              child: _step == 0
                                  ? const SizedBox.shrink()
                                  : MadarButton.icon(
                                      key: const ValueKey('back'),
                                      icon: Icons.arrow_back_rounded,
                                      semanticLabel: l.actionBack,
                                      size: MadarButtonSize.large,
                                      sfx: Sfx.back,
                                      onPressed: () => _goTo(_step - 1),
                                    ),
                            ),
                            if (_step > 0) const SizedBox(width: Space.m),
                            Expanded(
                              child: AnimatedOpacity(
                                opacity: last ? 0 : 1,
                                duration: context.motion(MadarMotion.short),
                                child: IgnorePointer(
                                  ignoring: last,
                                  child: MadarButton(
                                    label: _step == 0 ? l.onboardingBegin : l.actionContinue,
                                    trailingIcon: Icons.arrow_forward_rounded,
                                    size: MadarButtonSize.large,
                                    expand: true,
                                    sfx: Sfx.navigate,
                                    onPressed: () => _goTo(_step + 1),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three small stars; the current one fills with the accent.
class _StepStars extends StatelessWidget {
  const _StepStars({required this.step, required this.label});

  final int step;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < OnboardingScreen.stepCount; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: Space.s),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: i == step ? 1 : (i < step ? 0.55 : 0)),
                  duration: context.motion(MadarMotion.medium),
                  curve: MadarMotion.standard,
                  builder: (context, v, _) => IslamicStar(
                    size: 12 + 6 * (i == step ? v : 0),
                    filled: v > 0.01,
                    glow: i == step,
                    color: Color.lerp(t.textTertiary, t.accent, v),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({required this.id, required this.children});

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

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final size = math.min(MediaQuery.sizeOf(context).width * 0.66, 280.0);
    return _StepFrame(
      id: 'onboarding-welcome',
      children: [
        OrbitEmblem(size: size, animate: animate),
        const SizedBox(height: Space.xl),
        Semantics(
          header: true,
          child: Text(
            l.appName,
            style: text.displayLarge!.copyWith(
              color: t.gold,
              shadows: [Shadow(color: t.accentGlow, blurRadius: 28)],
            ),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          l.onboardingWelcomeTagline,
          textAlign: TextAlign.center,
          style: text.headlineSmall!.copyWith(color: t.textPrimary),
        ),
        const SizedBox(height: Space.m),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            l.onboardingWelcomeBody,
            textAlign: TextAlign.center,
            style: text.bodyLarge!.copyWith(color: t.textSecondary, height: 1.7),
          ),
        ),
      ],
    );
  }
}

class _StyleStep extends ConsumerWidget {
  const _StyleStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(appSettingsProvider);
    return _StepFrame(
      id: 'onboarding-style',
      children: [
        Semantics(
          header: true,
          child: Text(l.onboardingStyleTitle, textAlign: TextAlign.center, style: text.displaySmall),
        ),
        const SizedBox(height: Space.s),
        Text(
          l.onboardingStyleBody,
          textAlign: TextAlign.center,
          style: text.bodyMedium!.copyWith(color: t.textSecondary),
        ),
        const SizedBox(height: Space.xl),
        _Label(l.settingsLanguage),
        LanguagePicker(
          languageCode: settings.languageCode,
          onChanged: (code) => ref.updateSettings((s) => SettingsChanges.language(s, code)),
        ),
        const SizedBox(height: Space.xl),
        _Label(l.settingsTheme),
        ThemeCarousel(
          selected: settings.themeId,
          customAccent: settings.customAccent,
          cardWidth: 92,
          padding: EdgeInsetsDirectional.zero,
          onSelected: (id) => ref.updateSettings((s) => SettingsChanges.theme(s, id)),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.m),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IslamicStar(size: 11),
          const SizedBox(width: Space.s),
          Text(text, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.textSecondary)),
          const SizedBox(width: Space.s),
          const IslamicStar(size: 11),
        ],
      ),
    );
  }
}

class _StartStep extends StatelessWidget {
  const _StartStep({required this.onFinish});

  final ValueChanged<OnboardingExit> onFinish;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return _StepFrame(
      id: 'onboarding-start',
      children: [
        const GirihRosette(size: 110, folds: 8),
        const SizedBox(height: Space.xl),
        Semantics(
          header: true,
          child: Text(l.onboardingStartTitle, textAlign: TextAlign.center, style: text.displaySmall),
        ),
        const SizedBox(height: Space.s),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 14, color: t.success),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                l.onboardingStartBody,
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: t.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        _ChoiceCard(
          icon: Icons.auto_awesome_rounded,
          title: l.onboardingStartFresh,
          body: l.onboardingStartFreshBody,
          highlighted: true,
          onTap: (card) {
            Celebrate.burstFrom(card, intensity: 1.2);
            onFinish(OnboardingExit.home);
          },
        ),
        const SizedBox(height: Space.m),
        _ChoiceCard(
          icon: Icons.move_to_inbox_rounded,
          title: l.onboardingImport,
          body: l.onboardingImportBody,
          onTap: (_) => onFinish(OnboardingExit.import),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Receives the card's own context (to burst celebrations from it).
  final ValueChanged<BuildContext> onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    // matchTextDirection: Icon mirrors it under RTL by itself.
    const chevron = Icons.chevron_right_rounded;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: GlassCard(
        onTap: () => onTap(context),
        semanticLabel: '$title. $body',
        borderColor: highlighted ? t.accent.withValues(alpha: 0.6) : null,
        glowColor: highlighted ? t.accentGlow.withValues(alpha: t.accentGlow.a * 0.5) : null,
        padding: const EdgeInsetsDirectional.all(Space.l),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: highlighted ? t.accent : t.accentSoft,
                boxShadow: highlighted ? [BoxShadow(color: t.accentGlow, blurRadius: 16)] : null,
              ),
              child: Icon(icon, color: highlighted ? t.textOnAccent : t.accent),
            ),
            const SizedBox(width: Space.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: text.titleLarge),
                  Text(body, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ],
              ),
            ),
            Icon(chevron, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}
