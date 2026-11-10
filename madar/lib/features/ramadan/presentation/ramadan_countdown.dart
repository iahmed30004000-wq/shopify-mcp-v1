import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../orbit/data/orbit_providers.dart' show orbitClockProvider, prayerScheduleProvider, prayerSettingsProvider;
import '../../orbit/domain/prayer_schedule.dart' show PrayerSettings;
import '../../prayer/presentation/prayer_labels.dart';
import '../domain/fast_countdown.dart';
import '../domain/ramadan_today.dart';

/// The live countdown to iftar (by day) or to the end of suhoor (by night):
/// what it counts to, the time of it on the place's clock, and `h:mm:ss`
/// ticking once a second - only while the page is showing (a covered or hidden
/// page stops its timer; the target itself is recomputed by the minute from
/// the prayer schedule, so with the screen off nothing is lost: it is simply
/// right again the moment the screen is on).
class RamadanCountdownBlock extends ConsumerStatefulWidget {
  const RamadanCountdownBlock({super.key, required this.today});

  final RamadanToday today;

  @override
  ConsumerState<RamadanCountdownBlock> createState() => _RamadanCountdownBlockState();
}

class _RamadanCountdownBlockState extends ConsumerState<RamadanCountdownBlock> {
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final live = TickerMode.valuesOf(context).enabled;
    if (live && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!live) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final c = widget.today.countdown;
    final at = c.at;
    if (c.phase == FastPhase.idle || at == null) {
      return Text(
        l.ramadanLastIftarDone,
        key: const ValueKey('ramadan.countdown.idle'),
        style: text.bodyMedium!.copyWith(color: t.textSecondary),
      );
    }
    final now = ref.read(orbitClockProvider)();
    final remaining = at.difference(now);
    final schedule = ref.watch(prayerScheduleProvider);
    final settings = ref.watch(prayerSettingsProvider).value ?? const PrayerSettings();
    final clock = prayerClockOf(context, settings);
    final label = c.target == FastTarget.iftar ? l.ramadanIftarIn : l.ramadanSuhoorEndsIn;
    final atText = l.ramadanAtTime(clock.format(schedule.wallClock(at)).joined);
    return Semantics(
      container: true,
      label: l.ramadanCountdownSemantics(label, fmt.formatDurationWords(l, remaining)),
      excludeSemantics: true,
      child: Row(
        key: ValueKey('ramadan.countdown.${c.target!.name}'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.labelMedium!.copyWith(color: t.textTertiary)),
                Text(atText, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          // The same tabular Plex numerals as the next-prayer card; built on a
          // theme style (the planet sheet has no Material above it).
          Text(
            clock.countdown(remaining),
            key: const ValueKey('ramadan.countdown.time'),
            style: text.titleLarge!.merge(
              MadarTypography.numerals(t, size: 24, color: t.accent).copyWith(fontWeight: FontWeight.w600, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
