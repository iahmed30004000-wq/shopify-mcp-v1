import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/prayer_mute.dart';
import '../../../core/sound/sound_api.dart';
import '../../orbit/data/orbit_providers.dart' show prayerScheduleProvider;
import '../../prayer/presentation/widgets/prayer_widgets.dart' show HijriDateText;
import '../application/adhan_providers.dart';
import '../data/adhan_audio.dart';
import '../data/adhan_scheduler.dart';
import '../data/adhan_system.dart';
import '../data/adhan_texts.dart';
import '../domain/adhan_dua.dart';
import '../domain/adhan_event.dart';
import '../domain/adhan_screen_model.dart';
import '../domain/adhan_settings.dart';
import '../domain/adhan_slot.dart';
import '../domain/adhan_sound.dart';
import 'widgets/adhan_halo.dart';

/// The full-screen adhan: the prayer's name in calligraphy under a golden
/// astrolabe, the time, the Hijri date, and – after the adhan – the
/// supplication that follows it. Stop / "I prayed" / close; for reminders a
/// live countdown and snooze. Works over the lock screen (the host enables
/// the window's lock-screen mode only for the adhan's own full-screen
/// launch) and mutes game music and ambience while it shows.
///
/// Route widget: `AdhanScreen(event: e, onClose: () => …)`; [AdhanHost]
/// presents it over the app for notification events.
class AdhanScreen extends ConsumerStatefulWidget {
  const AdhanScreen({super.key, required this.event, this.onClose});

  final AdhanEvent event;

  /// Called when the user closes the screen (after "I prayed", snooze or
  /// close). Defaults to popping the route.
  final VoidCallback? onClose;

  @override
  ConsumerState<AdhanScreen> createState() => _AdhanScreenState();
}

class _AdhanScreenState extends ConsumerState<AdhanScreen> {
  late final AdhanScreenModel _model;
  late final AdhanSettings _settings;
  late final DateTime Function() _clock;
  late final AdhanAudio _audio;
  late final AdhanSystem _system;
  late final AdhanScheduler _scheduler;
  late AdhanPhase _phase;
  PrayerMuteLease? _mute;
  Timer? _soundEnd;
  Timer? _tick;

  /// "Now" for the countdowns: ticks every second during a reminder or the
  /// sunrise alert and rebuilds only what shows it (not the backdrop and
  /// the astrolabe).
  late final ValueNotifier<DateTime> _now;
  Timer? _closeLater;
  String? _message;
  bool _busy = false;
  bool _closed = false;

  AdhanEvent get event => widget.event;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(adhanSettingsProvider).value ?? const AdhanSettings();
    _clock = ref.read(adhanClockProvider);
    _audio = ref.read(adhanAudioProvider);
    _system = ref.read(adhanSystemProvider);
    _scheduler = ref.read(adhanSchedulerProvider);
    _model = AdhanScreenModel(
      kind: event.kind,
      firedAt: event.firedAt,
      soundLength: AdhanScreenModel.soundLengthOf(event.sound, _settings),
    );
    final now = _clock();
    _now = ValueNotifier(now);
    final silenced = event.actionId == AdhanActions.stop;
    _phase = _model.initialPhase(now, silenced: silenced);
    _mute = ref.read(prayerMuteProvider).acquire('adhan screen');
    if (silenced) unawaited(_scheduler.silence(event));
    if (_phase == AdhanPhase.calling) {
      _soundEnd = Timer(_model.soundingLeft(now), _onSoundEnded);
      if (event.playInApp && event.sound != null) {
        unawaited(_audio.play(event.sound!, muezzin: _settings.muezzinById(event.sound!.fileId)));
      }
    }
    if (_phase == AdhanPhase.reminder || _phase == AdhanPhase.sunrise) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _now.value = _clock();
      });
    }
  }

  @override
  void dispose() {
    _soundEnd?.cancel();
    _tick?.cancel();
    _now.dispose();
    _closeLater?.cancel();
    _mute?.release();
    if (event.playInApp) unawaited(_audio.stop());
    // Hosted by [AdhanHost], the event hub owns the lock-screen mode: a
    // screen leaving because a newer adhan replaced it must not hide that
    // one behind the keyguard. Routed by hand, the screen releases it.
    if (widget.onClose == null) unawaited(_system.setLockScreenMode(false));
    super.dispose();
  }

  void _onSoundEnded() {
    if (!mounted || _phase != AdhanPhase.calling) return;
    setState(() => _phase = AdhanPhase.after);
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _stop() async {
    _soundEnd?.cancel();
    setState(() => _phase = AdhanPhase.after);
    await _scheduler.silence(event);
    await _audio.stop();
  }

  Future<void> _markPrayed() async {
    if (_busy) return;
    setState(() => _busy = true);
    final slot = AdhanScreenModel.prayedSlot(event.slot);
    try {
      if (_phase == AdhanPhase.calling) {
        _soundEnd?.cancel();
        await _scheduler.silence(event);
        await _audio.stop();
      }
      await ref.read(adhanMarkPrayedProvider)(event.localDay, slot.prayer!);
      if (!mounted) return;
      Fx.fire(Sfx.prayerLit);
      setState(() {
        _phase = AdhanPhase.prayed;
        _busy = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Celebrate.burstFrom(context, kind: CelebrationKind.lanternSparks, color: context.tokens.gold);
      });
      _closeLater = Timer(const Duration(milliseconds: 1800), _close);
    } catch (e) {
      debugPrint('AdhanScreen: logging the prayer failed: $e');
      if (!mounted) return;
      Fx.fire(Sfx.error);
      setState(() {
        _busy = false;
        _message = L10n.of(context).adhanPrayedFailed;
      });
    }
  }

  Future<void> _snooze(AdhanTexts texts) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await _scheduler.snooze(event, settings: _settings, texts: texts);
    if (!mounted) return;
    Fx.fire(ok ? Sfx.complete : Sfx.error);
    setState(() {
      _busy = false;
      _message = ok ? L10n.of(context).adhanSnoozed(texts.minutes(_settings.snoozeMinutes)) : null;
    });
    if (ok) _closeLater = Timer(const Duration(milliseconds: 1400), _close);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final texts = ref.watch(adhanTextsProvider);
    final schedule = ref.watch(prayerScheduleProvider);
    final times = ref.watch(adhanTimesProvider);
    final wall = schedule.wallClock(event.prayerAt);
    final day = times.timesFor(event.day);
    final dayTimes = [
      for (final s in AdhanSlot.prayers)
        if (day[s] != null) schedule.wallClock(day[s]!),
    ];
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final media = MediaQuery.of(context);
    final dua = _phase == AdhanPhase.after || (_phase == AdhanPhase.prayed && event.kind.isCall);
    // Once the adhan has ended the instrument steps back for the
    // supplication.
    final haloSize = dua
        ? math.min(media.size.width * 0.44, math.min(190.0, media.size.height * 0.2))
        : math.min(media.size.width * 0.74, math.min(310.0, media.size.height * 0.34));
    final sounding = _phase == AdhanPhase.calling;
    final dim = _phase == AdhanPhase.reminder || _phase == AdhanPhase.sunrise;
    final ambient = AmbientMotion.enabled && !context.reducedMotion;

    String overline(DateTime now) => switch (event.kind) {
      AdhanKind.test => l.adhanScreenOverlineTest,
      AdhanKind.preAdhan || AdhanKind.snooze => l.adhanScreenOverlinePre,
      AdhanKind.sunrise =>
        event.minutesBefore > 0 && event.prayerAt.isAfter(now)
            ? l.adhanScreenOverlineSunriseSoon
            : l.adhanScreenOverlineSunrise,
      AdhanKind.adhan => l.adhanScreenOverlineCall,
    };

    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        label: l.adhanScreenSemantics(texts.prayer(event.slot), texts.time(event.prayerAt)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: t.space0),
            CosmosBackdrop(intensity: 0.85, animate: ambient, seed: 0.33),
            // Focus: a soft vignette around the centre.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 1.1,
                  colors: [
                    t.space0.withValues(alpha: 0),
                    t.space0.withValues(alpha: t.isDark ? 0.55 : 0.35),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    date: fmt.formatDate(wall, style: MadarDateStyle.weekdayDayMonth),
                    hijriAt: event.prayerAt,
                    onClose: _close,
                    closeLabel: l.adhanClose,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(end: haloSize),
                                duration: context.motion(MadarMotion.long),
                                curve: MadarMotion.standard,
                                builder: (context, size, _) =>
                                    AdhanHalo(at: wall, dayTimes: dayTimes, size: size, sounding: sounding, dim: dim),
                              ),
                              const SizedBox(height: Space.l),
                              StaggerIn(
                                id: 'adhan-${event.key}',
                                crossAxisAlignment: CrossAxisAlignment.center,
                                from: EntranceFrom.bottom,
                                delay: const Duration(milliseconds: 380),
                                children: [
                                  ValueListenableBuilder<DateTime>(
                                    valueListenable: _now,
                                    builder: (context, now, _) => Text(
                                      overline(now),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.titleSmall!
                                          .copyWith(color: t.textSecondary, letterSpacing: arabic ? 0 : 1.2),
                                    ),
                                  ),
                                  _PrayerName(slot: event.slot, name: texts.prayer(event.slot), arabic: arabic),
                                  const SizedBox(height: Space.xs),
                                  Text(
                                    texts.time(event.prayerAt),
                                    textAlign: TextAlign.center,
                                    style: MadarTypography.numerals(
                                      t,
                                      size: 30,
                                      color: t.textPrimary,
                                    ).copyWith(fontWeight: FontWeight.w300, height: 1.2),
                                  ),
                                  const SizedBox(height: Space.m),
                                  ValueListenableBuilder<DateTime>(
                                    valueListenable: _now,
                                    builder: (context, now, _) => _StatusLine(
                                      phase: _phase,
                                      event: event,
                                      settings: _settings,
                                      texts: texts,
                                      now: now,
                                    ),
                                  ),
                                ],
                              ),
                              if (dua)
                                Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    Space.gutter,
                                    Space.l,
                                    Space.gutter,
                                    Space.s,
                                  ),
                                  child: AnimatedReveal(
                                    child: _DuaCard(fmt: fmt, arabicUi: arabic),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.gutter, Space.l),
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: _now,
                      builder: (context, now, _) => AnimatedSwitcher(
                        duration: context.motion(MadarMotion.medium),
                        switchInCurve: MadarMotion.decelerate,
                        child: _actions(context, texts, now),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, AdhanTexts texts, DateTime now) {
    final l = L10n.of(context);
    final t = context.tokens;
    final message = _message;
    if (_phase == AdhanPhase.prayed || message != null) {
      final prayed = _phase == AdhanPhase.prayed;
      return Row(
        key: ValueKey('msg-$prayed-$message'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            prayed ? Icons.check_circle_rounded : Icons.notifications_active_rounded,
            color: prayed ? t.success : t.accent,
          ),
          const SizedBox(width: Space.s),
          Flexible(
            child: Text(
              prayed ? l.adhanPrayedDone : message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(color: t.textPrimary),
            ),
          ),
        ],
      );
    }
    final canPray = AdhanScreenModel.canMarkPrayed(event.kind, event.slot, event.prayerAt, now);
    final prayedLabel = event.slot == AdhanSlot.sunrise
        ? l.adhanPrayedNamed(texts.prayer(AdhanSlot.fajr))
        : l.adhanPrayed;
    final close = MadarButton(
      label: l.adhanClose,
      onPressed: _close,
      variant: MadarButtonVariant.ghost,
      sfx: Sfx.back,
      expand: true,
    );
    final prayedButton = MadarButton(
      label: prayedLabel,
      icon: Icons.mosque_rounded,
      onPressed: _busy ? null : _markPrayed,
      loading: _busy,
      variant: MadarButtonVariant.secondary,
      expand: true,
      sfx: Sfx.tap,
    );
    switch (_phase) {
      case AdhanPhase.calling:
        return Column(
          key: const ValueKey('calling'),
          mainAxisSize: MainAxisSize.min,
          children: [
            MadarButton(
              label: l.adhanStop,
              icon: Icons.stop_circle_rounded,
              onPressed: _stop,
              size: MadarButtonSize.large,
              expand: true,
              sfx: Sfx.toggleOff,
            ),
            const SizedBox(height: Space.s),
            Row(
              children: [
                if (canPray) ...[Expanded(child: prayedButton), const SizedBox(width: Space.s)],
                Expanded(child: close),
              ],
            ),
          ],
        );
      case AdhanPhase.after || AdhanPhase.sunrise:
        return Column(
          key: ValueKey(_phase),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canPray)
              MadarButton(
                label: prayedLabel,
                icon: Icons.mosque_rounded,
                onPressed: _busy ? null : _markPrayed,
                loading: _busy,
                size: MadarButtonSize.large,
                expand: true,
                sfx: Sfx.tap,
              ),
            if (canPray) const SizedBox(height: Space.s),
            close,
          ],
        );
      case AdhanPhase.reminder:
        final canSnooze = AdhanScheduler.canSnooze(event, settings: _settings, now: now);
        return Column(
          key: const ValueKey('reminder'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canSnooze)
              MadarButton(
                label: l.adhanSnooze(texts.minutes(_settings.snoozeMinutes)),
                icon: Icons.snooze_rounded,
                onPressed: _busy ? null : () => _snooze(texts),
                loading: _busy,
                size: MadarButtonSize.large,
                expand: true,
                sfx: Sfx.tap,
              ),
            if (canSnooze) const SizedBox(height: Space.s),
            close,
          ],
        );
      case AdhanPhase.prayed:
        return const SizedBox.shrink();
    }
  }
}

/// Date (Gregorian and Hijri) at the start, close at the end.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.date, required this.hijriAt, required this.onClose, required this.closeLabel});

  final String date;
  final DateTime hijriAt;
  final VoidCallback onClose;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.s, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(date, style: text.labelLarge!.copyWith(color: t.textPrimary)),
                HijriDateText(
                  at: hijriAt,
                  style: text.bodySmall!.copyWith(color: t.gold),
                ),
              ],
            ),
          ),
          MadarButton.icon(
            icon: Icons.close_rounded,
            onPressed: onClose,
            semanticLabel: closeLabel,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.back,
          ),
        ],
      ),
    );
  }
}

/// The prayer's name set large: naskh calligraphy (Amiri) in gold. In
/// English the Latin name leads and the Arabic calligraphy follows beneath.
class _PrayerName extends StatelessWidget {
  const _PrayerName({required this.slot, required this.name, required this.arabic});

  final AdhanSlot slot;
  final String name;
  final bool arabic;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colors = t.isDark ? [t.starTint, t.gold, t.brass] : [t.gold, t.brassDark, t.gold];
    final glow = [Shadow(color: t.accentGlow.withValues(alpha: t.isDark ? 0.7 : 0.45), blurRadius: 28)];
    final calligraphy = TextStyle(
      fontFamily: MadarTypography.naskhFamily,
      fontWeight: FontWeight.w700,
      fontSize: arabic ? 76 : 40,
      height: arabic ? 1.45 : 1.5,
      color: t.gold,
    );
    // The Arabic name in calligraphy – in English too, as an ornament.
    final arabicName = arabic ? name : lookupL10n(const Locale('ar')).adhanCalligraphyName(slot);
    if (arabic) {
      return _GildedText(arabicName, style: calligraphy, colors: colors, glow: glow);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GildedText(
          name,
          style: Theme.of(context).textTheme.displayMedium!.copyWith(color: t.gold, height: 1.2),
          colors: colors,
          glow: glow,
        ),
        ExcludeSemantics(
          child: Text(
            arabicName,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: calligraphy.copyWith(color: t.gold.withValues(alpha: 0.75)),
          ),
        ),
      ],
    );
  }
}

/// Text in a vertical metal gradient with a soft glow around it.
///
/// The glow is its own unmasked layer beneath: inside the `ShaderMask` it
/// would be tinted by the gradient and cut off at the text's box – a hard
/// edge beside the letters, plainly visible on the light Pearl theme.
class _GildedText extends StatelessWidget {
  const _GildedText(this.text, {required this.style, required this.colors, required this.glow});

  final String text;
  final TextStyle style;
  final List<Color> colors;
  final List<Shadow> glow;

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context);
    final effective = base.style.merge(style);
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: RichText(
            text: TextSpan(text: text, style: effective.copyWith(color: const Color(0x00000000), shadows: glow)),
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(context),
            textWidthBasis: base.textWidthBasis,
            textHeightBehavior: base.textHeightBehavior ?? DefaultTextHeightBehavior.maybeOf(context),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) =>
              LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(r),
          child: Text(text, textAlign: TextAlign.center, style: style.copyWith(shadows: const [])),
        ),
      ],
    );
  }
}

extension on L10n {
  String adhanCalligraphyName(AdhanSlot s) => switch (s) {
    AdhanSlot.fajr => prayerFajr,
    AdhanSlot.sunrise => prayerSunrise,
    AdhanSlot.dhuhr => prayerDhuhr,
    AdhanSlot.asr => prayerAsr,
    AdhanSlot.maghrib => prayerMaghrib,
    AdhanSlot.isha => prayerIsha,
  };
}

/// Sounding / countdown / sunrise line under the time.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.phase,
    required this.event,
    required this.settings,
    required this.texts,
    required this.now,
  });

  final AdhanPhase phase;
  final AdhanEvent event;
  final AdhanSettings settings;
  final AdhanTexts texts;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    switch (phase) {
      case AdhanPhase.calling:
        final sound = event.sound;
        final label = switch (sound?.kind) {
          AdhanSoundKind.silent => l.adhanScreenSilent,
          AdhanSoundKind.file => l.adhanScreenSoundingCall,
          _ => l.adhanScreenSoundingTone,
        };
        return _Pill(
          icon: sound?.kind == AdhanSoundKind.silent ? Icons.vibration_rounded : Icons.graphic_eq_rounded,
          label: label,
          detail: sound == null ? null : texts.soundName(sound, muezzin: settings.muezzinById(sound.fileId)),
        );
      case AdhanPhase.reminder:
        final left = event.prayerAt.difference(now);
        return _Pill(
          icon: Icons.hourglass_top_rounded,
          label: left > Duration.zero
              ? l.adhanScreenAdhanIn(fmt.formatDuration(left, seconds: true))
              : l.adhanScreenAdhanAt(texts.time(event.prayerAt)),
        );
      case AdhanPhase.sunrise:
        final left = event.prayerAt.difference(now);
        if (left <= Duration.zero) return const SizedBox.shrink();
        return _Pill(
          icon: Icons.wb_twilight_rounded,
          label: l.adhanScreenSunriseIn(fmt.formatDuration(left, seconds: true)),
        );
      case AdhanPhase.after || AdhanPhase.prayed:
        return const SizedBox.shrink();
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.detail});

  final IconData icon;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.l, Space.s),
      decoration: BoxDecoration(
        color: t.glassFill,
        borderRadius: BorderRadius.circular(t.radiusXL),
        border: Border.all(color: t.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: t.accent),
          const SizedBox(width: Space.s),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label,
                    style: text.labelLarge!.copyWith(color: t.textPrimary),
                  ),
                  if (detail != null) ...[
                    TextSpan(
                      text: '  ·  ',
                      style: text.labelLarge!.copyWith(color: t.textTertiary),
                    ),
                    TextSpan(
                      text: detail,
                      style: text.labelLarge!.copyWith(color: t.textSecondary),
                    ),
                  ],
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// The supplication after the adhan (Sahih al-Bukhari 614).
class _DuaCard extends StatelessWidget {
  const _DuaCard({required this.fmt, required this.arabicUi});

  final MadarFormatter fmt;
  final bool arabicUi;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.l, Space.xl, Space.l),
      glowColor: t.accentGlow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IslamicStar(size: 12, color: t.gold),
              const SizedBox(width: Space.s),
              Flexible(
                child: Text(
                  l.adhanDuaTitle,
                  textAlign: TextAlign.center,
                  style: text.titleSmall!.copyWith(color: t.gold),
                ),
              ),
              const SizedBox(width: Space.s),
              IslamicStar(size: 12, color: t.gold),
            ],
          ),
          const SizedBox(height: Space.m),
          Text(
            AdhanDua.arabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(fontFamily: MadarTypography.naskhFamily, fontSize: 21, height: 2.0, color: t.textPrimary),
          ),
          const SizedBox(height: Space.s),
          Text(
            l.adhanDuaMeaning,
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(
              color: t.textSecondary,
              fontStyle: arabicUi ? FontStyle.normal : FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            l.adhanDuaSource(fmt.formatInt(AdhanDua.bukhari, grouping: false)),
            textAlign: TextAlign.center,
            style: text.labelSmall!.copyWith(color: t.textTertiary),
          ),
        ],
      ),
    );
  }
}
