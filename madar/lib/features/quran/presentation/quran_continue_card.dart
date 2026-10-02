import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/sound/sound_api.dart';
import '../data/quran_providers.dart';
import '../domain/quran_meta.dart';
import '../domain/quran_prefs.dart';
import 'quran_labels.dart';
import 'quran_reader_screen.dart';

/// "Continue reading": where the reader last stopped (sura, ayah, page,
/// juz) with the khatma position as a thin progress line; before any
/// reading it invites to start with al-Fatihah. Compact enough for the
/// Faith page; [prominent] makes it the Quran home's hero.
class QuranContinueCard extends ConsumerWidget {
  const QuranContinueCard({super.key, this.onOpen, this.prominent = false});

  /// Opens the reader (default: [QuranNavigation.openReader]).
  final QuranOpenReader? onOpen;
  final bool prominent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final meta = ref.watch(quranMetaProvider).value;
    final last = ref.watch(quranLastReadProvider).value;
    final ready = meta != null;
    final ref0 = last?.ref ?? const AyahRef(1, 1);

    void open() {
      if (onOpen != null) {
        Fx.fire(Sfx.navigate);
        onOpen!(context, ayah: last?.ref);
      } else {
        unawaited(QuranNavigation.openReader(context, ayah: last?.ref));
      }
    }

    final surah = ready ? meta.surah(ref0.surah) : null;
    final page = last?.page ?? 1;
    final progress = last == null ? 0.0 : page / QuranMeta.pageCount;
    final title = last == null ? l.quranContinueEmpty : l.quranContinueTitle;
    final place = surah == null ? '' : l.quranPlace(surah, ref0.ayah, fmt);
    final detail = !ready
        ? ''
        : l.quranJoin([quranPageCounter(l, fmt, page), l.quranJuzLabel(fmt.formatInt(meta.juzOf(ref0)))]);
    final card = Row(
      children: [
        _PageSeal(page: page, size: prominent ? 64 : 52),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: (prominent ? text.titleMedium : text.titleSmall)!.copyWith(color: t.gold)),
              const SizedBox(height: Space.xxs),
              if (last != null && surah != null)
                Text(place, style: prominent ? text.titleLarge : text.titleMedium, maxLines: 1)
              else
                Text(l.quranContinueStart, style: text.titleMedium),
              if (last != null) ...[
                const SizedBox(height: Space.xxs),
                Text(detail, style: text.bodySmall),
                const SizedBox(height: Space.s),
                SizedBox(width: double.infinity, child: _Progress(value: progress)),
              ],
            ],
          ),
        ),
        const SizedBox(width: Space.s),
        MadarButton.icon(
          icon: Icons.auto_stories_rounded,
          semanticLabel: last == null ? l.quranContinueStart : l.quranContinueAction,
          variant: MadarButtonVariant.primary,
          size: prominent ? MadarButtonSize.large : MadarButtonSize.medium,
          sfx: Sfx.navigate,
          onPressed: ready ? open : null,
        ),
      ],
    );
    final padding = EdgeInsetsDirectional.fromSTEB(Space.l, prominent ? Space.l : Space.m, Space.m, Space.m);
    return prominent
        ? GlassPanel(padding: padding, glowColor: t.accentGlow, child: card)
        : GlassCard(
            onTap: ready ? open : null,
            semanticLabel: last == null ? l.quranContinueStart : '$title, $place',
            borderRadius: BorderRadius.circular(t.radiusL),
            padding: padding,
            child: card,
          );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: t.glassBorder),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [t.brass, t.gold])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A brass eight-point seal with the page number (a little mushaf).
class _PageSeal extends StatelessWidget {
  const _PageSeal({required this.page, required this.size});

  final int page;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IslamicStar(size: size, color: t.accentSoft),
          IslamicStar(size: size, filled: false, color: t.brass, strokeWidth: 1.4),
          IslamicStar(size: size * 0.72, filled: false, color: t.brass.withValues(alpha: 0.5), rotation: 0.39),
          // Kept inside the star's inner field at any text size.
          SizedBox(
            width: size * 0.5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                fmt.formatInt(page),
                style: MadarTypography.numerals(t, size: size * 0.24, color: t.gold).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where "continue" will open (for hosts that route themselves).
AyahRef? quranContinueTarget(WidgetRef ref) {
  final QuranLastRead? last = ref.read(quranLastReadProvider).value;
  return last?.ref;
}
