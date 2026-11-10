import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/routing/route_pages.dart';
import '../../../core/sound/sound_api.dart';
import '../application/ramadan_providers.dart';
import '../data/ramadan_texts.dart';
import '../domain/khatmah_plan.dart';
import '../domain/last_ten_nights.dart';
import '../domain/ramadan_today.dart';
import 'ramadan_countdown.dart';

/// Shows the undo toast of a change that was just written.
void ramadanUndoToast(BuildContext context, String label, RamadanUndo undo) {
  if (!context.mounted) return;
  unawaited(showUndoToast(context, UndoableAction(label: label, undo: undo)));
}

/// The Faith hub's Ramadan card - only while Ramadan is on (or, for the
/// last 30 days before it, a countdown to it):
///
/// * today's day number («اليوم ١٢ من رمضان»; «ليلة ١» on the first evening);
/// * the live countdown to iftar (by day) or to the end of suhoor (by night),
///   from the app's own prayer schedule;
/// * «تراويح الليلة»: one tap logs the night, a second un-logs it;
/// * today's khatmah portion with «افتح القرآن» (the reader at that page);
/// * on the last ten nights, which night it is and whether it is an odd one.
///
/// Tapping the title opens the Ramadan screen. It draws nothing otherwise.
class RamadanHubCard extends ConsumerWidget {
  const RamadanHubCard({super.key});

  /// Whether the card has anything to show now (the hub leaves its slot out
  /// otherwise, so no empty gap).
  static bool visible(RamadanToday today) => today.inRamadan || today.comingSoon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(ramadanTodayProvider);
    if (today.inRamadan) return _InRamadanCard(today: today);
    if (today.comingSoon) return _ComingCard(today: today);
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------------------

class _InRamadanCard extends ConsumerWidget {
  const _InRamadanCard({required this.today});

  final RamadanToday today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final texts = ref.watch(ramadanTextsProvider);
    final config = ref.watch(ramadanConfigProvider);
    final number = today.headlineNumber ?? 1;
    final headline = today.dayOfRamadan != null ? l.ramadanDayOf(texts.number(number)) : l.ramadanNightOf(texts.number(number));
    final calendar = ref.watch(ramadanCalendarProvider);
    final hijri = texts.hijriFull(calendar.hijriOf(today.date));
    final tonight = today.tonight;
    final year = today.hijriYear;
    final done = tonight != null && year != null && (ref.watch(ramadanLogBookProvider).value?.of(year)?.taraweeh.isDone(tonight) ?? false);
    final khatmah = config.hubKhatmah ? ref.watch(ramadanKhatmahTodayProvider) : null;

    return GlassCard(
      key: const ValueKey('ramadan.card'),
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xs, Space.l, Space.m),
      glowColor: t.accentGlow.withValues(alpha: t.accentGlow.a * 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MadarPressable(
            onTap: () => FaithNav.ramadan(context),
            sfx: Sfx.navigate,
            semanticLabel: '$headline. $hijri',
            excludeChildSemantics: true,
            minTapTarget: MadarPressable.minTouchTarget,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        key: const ValueKey('ramadan.card.headline'),
                        style: text.titleLarge!.copyWith(
                          fontFamily: MadarTypography.naskhFamily,
                          fontSize: 21,
                          height: 1.35,
                          color: t.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(hijri, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s),
                Icon(Icons.nightlight_round, size: 24, color: t.gold),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Space.m),
            child: Divider(height: 1, thickness: 0.6, color: t.glassBorder.withValues(alpha: 0.4)),
          ),
          RamadanCountdownBlock(today: today),
          if (tonight != null && year != null) ...[
            const SizedBox(height: Space.s),
            _TonightRow(texts: texts, night: tonight, done: done, year: year),
          ],
          if (khatmah != null && khatmah.status != KhatmahStatus.finished && !khatmah.portion.isEmpty) ...[
            const SizedBox(height: Space.xs),
            _PortionRow(texts: texts, today: khatmah),
          ],
          if (today.lastTenTonight && tonight != null) ...[
            const SizedBox(height: Space.xs),
            _LastTenStrip(texts: texts, night: tonight),
          ],
        ],
      ),
    );
  }
}

/// «تراويح الليلة»: a row you tap once to log the night.
class _TonightRow extends ConsumerWidget {
  const _TonightRow({required this.texts, required this.night, required this.done, required this.year});

  final RamadanTexts texts;
  final int night;
  final bool done;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final title = l.ramadanTaraweehTonight(texts.number(night));
    return MadarPressable(
      key: const ValueKey('ramadan.card.tonight'),
      onTap: () async {
        final undo = await ref.read(ramadanServiceProvider).toggleTaraweeh(year, night);
        if (context.mounted) ramadanUndoToast(context, done ? l.ramadanTaraweehRemovedToast : l.ramadanTaraweehLoggedToast, undo);
      },
      toggled: done,
      sfx: Sfx.tap,
      semanticLabel: '$title. ${done ? l.ramadanTaraweehLogged : l.ramadanTaraweehNotYet}',
      excludeChildSemantics: true,
      minTapTarget: MadarPressable.minTouchTarget,
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 24,
            color: done ? t.success : t.textTertiary,
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                Text(
                  done ? l.ramadanTaraweehLogged : l.ramadanTaraweehNotYet,
                  style: text.bodySmall!.copyWith(color: done ? t.success : t.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's khatmah portion and the way into the reader.
class _PortionRow extends StatelessWidget {
  const _PortionRow({required this.texts, required this.today});

  final RamadanTexts texts;
  final KhatmahToday today;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final p = today.portion;
    final done = today.todayDone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.auto_stories_rounded, size: 24, color: done ? t.success : t.accent),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? l.ramadanKhatmahDoneToday : l.ramadanKhatmahPortion,
                    key: const ValueKey('ramadan.card.portion'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall!.copyWith(color: t.textPrimary),
                  ),
                  Text(
                    l.ramadanKhatmahPages(texts.number(p.fromPage), texts.number(p.toPage)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Under the text, not beside it: at a large text size and 320 dp the
        // button would not fit on the line.
        Padding(
          padding: const EdgeInsetsDirectional.only(top: Space.xs, start: 24 + Space.m),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              key: const ValueKey('ramadan.card.openQuran'),
              label: l.ramadanKhatmahOpenQuran,
              variant: MadarButtonVariant.secondary,
              size: MadarButtonSize.small,
              onPressed: () => FaithNav.quranReader(context, page: p.fromPage),
            ),
          ),
        ),
      ],
    );
  }
}

/// «العشر الأواخر · ليلة ٢٧» with a star on the odd nights.
class _LastTenStrip extends StatelessWidget {
  const _LastTenStrip({required this.texts, required this.night});

  final RamadanTexts texts;
  final int night;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final odd = LastTenNights.isOddSought(night);
    final label = l.ramadanLastTenStrip(texts.number(night));
    return Semantics(
      container: true,
      label: odd ? '$label. ${l.ramadanLastTenOdd}' : label,
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey('ramadan.card.lastTen'),
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
        child: Row(
          children: [
            Icon(odd ? Icons.star_rounded : Icons.star_outline_rounded, size: 20, color: t.gold),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(
                odd ? '$label${l.commonFactSeparator}${l.ramadanLastTenOdd}' : label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium!.copyWith(color: t.gold, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// «رمضان بعد ١٢ يوم»: the countdown to Ramadan, in its last 30 days.
class _ComingCard extends ConsumerWidget {
  const _ComingCard({required this.today});

  final RamadanToday today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final texts = ref.watch(ramadanTextsProvider);
    final calendar = ref.watch(ramadanCalendarProvider);
    final days = today.daysUntilRamadan;
    final first = calendar.nextSpanAfter(today.date).first;
    final title = days == 1 ? l.ramadanComingTomorrow : l.ramadanComingTitle(texts.days(days));
    final date = l.ramadanComingDate(texts.when(first, calendar.hijriOf(first)));
    return MadarPressable(
      key: const ValueKey('ramadan.coming'),
      onTap: () => FaithNav.ramadan(context),
      sfx: Sfx.navigate,
      semanticLabel: '$title. $date',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusL),
      child: GlassCard(
        borderRadius: BorderRadius.circular(t.radiusL),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    key: const ValueKey('ramadan.coming.title'),
                    style: text.titleLarge!.copyWith(
                      fontFamily: MadarTypography.naskhFamily,
                      fontSize: 21,
                      height: 1.35,
                      color: t.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(date, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                  const SizedBox(height: Space.xs),
                  Text(l.ramadanComingOpen, style: text.labelLarge!.copyWith(color: t.accent)),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            Icon(Icons.nightlight_round, size: 28, color: t.gold),
          ],
        ),
      ),
    );
  }
}
