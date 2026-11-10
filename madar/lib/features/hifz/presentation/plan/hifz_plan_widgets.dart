/// «الحفظ» · the pieces its screens share (Part 14, step 2).
///
/// Three rules live here, so no screen can break them on its own:
///
/// * **The verified text is the only Quran on screen.** [HifzVerifiedText]
///   draws [WordCheck]s – words that came out of the engines, out of the
///   app's own Uthmani data – in the Quran face.
/// * **What he typed is his, and is labelled as his** ([HifzTypedAnswer]):
///   a different face, a different colour, under «مكتوب منك على الكيبورد».
/// * **A mode that cannot run says so** ([HifzNotReadyCard]) – never a dead
///   button and never a crash.
library;

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../tasmee/tasmee.dart';
import '../../domain/hifz_modes.dart';
import '../../domain/hifz_strength.dart';
import 'hifz_plan_texts.dart';

/// A glass card with a title row, the shape every «الحفظ» screen is built
/// out of (the kitchen's `SufraCard`, in this world's colours).
class HifzPanel extends StatelessWidget {
  const HifzPanel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    this.seed = 0,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final head = title;
    final card = GlassCard(
      seed: seed,
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (head != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: iconColor ?? t.accent),
                  const SizedBox(width: Space.s),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(head, style: text.titleMedium),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Space.xxs),
                          child: Text(subtitle!, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: Space.s), trailing!],
              ],
            ),
            const SizedBox(height: Space.m),
          ],
          child,
        ],
      ),
    );
    if (onTap == null) return card;
    return MadarPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      excludeChildSemantics: semanticLabel != null,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: card,
    );
  }
}

/// A small round of a band's colour – the one key to the whole feature.
class HifzBandDot extends StatelessWidget {
  const HifzBandDot({super.key, required this.band, required this.texts, this.size = 10});

  final StrengthBand band;
  final HifzPlanTexts texts;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = texts.bandColor(band);
    return Semantics(
      label: texts.band(band),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: band == StrengthBand.unknown ? Colors.transparent : color,
          border: Border.all(color: color, width: 1.4),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// What a colour means, spelled out – a map that does not say this is a
/// decoration.
class HifzBandLegend extends StatelessWidget {
  const HifzBandLegend({super.key, required this.texts, this.bands = HifzPlanTexts.legendBands});

  final HifzPlanTexts texts;
  final List<StrengthBand> bands;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary);
    return Wrap(
      spacing: Space.m,
      runSpacing: Space.s,
      children: [
        for (final b in bands)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HifzBandDot(band: b, texts: texts),
              const SizedBox(width: Space.xs),
              Text(texts.band(b), style: style),
            ],
          ),
      ],
    );
  }
}

/// «بصوتك لسا مش جاهز» – why a mode is not ready, and what works instead.
/// Shown in place of the drill, never beside a button that does nothing.
class HifzNotReadyCard extends StatelessWidget {
  const HifzNotReadyCard({super.key, required this.state, required this.texts, this.onPickAnother, this.pickLabel});

  final HifzMethodState state;
  final HifzPlanTexts texts;
  final VoidCallback? onPickAnother;
  final String? pickLabel;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final audio = state.blocker == HifzMethodBlocker.audioNotDownloaded;
    return HifzPanel(
      key: const ValueKey('hifz.notReady'),
      title: audio ? l.hifzMethodNoAudio : l.hifzMicSoonTitle,
      icon: audio ? Icons.download_for_offline_outlined : Icons.mic_off_rounded,
      iconColor: t.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            audio
                ? l.hifzMethodNoAudio
                : HifzMethods.canBeTyped(state.method)
                ? l.hifzMicSoonBody
                : l.hifzMicSoonNoTyping,
            style: text.bodyMedium?.copyWith(color: t.textSecondary),
          ),
          if (onPickAnother != null) ...[
            const SizedBox(height: Space.m),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MadarButton(
                key: const ValueKey('hifz.notReady.another'),
                label: pickLabel ?? l.hifzPlanPickMethod,
                icon: Icons.swap_horiz_rounded,
                variant: MadarButtonVariant.secondary,
                size: MadarButtonSize.small,
                onPressed: onPickAnother,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The verified text, word by word, coloured by how each word went.
///
/// Nothing here is generated: every letter is [WordCheck.word]'s own text,
/// which came out of `assets/quran/` through the engines. A word still to
/// be reached is drawn as a faint ghost so the line never moves when it
/// arrives.
class HifzVerifiedText extends StatelessWidget {
  const HifzVerifiedText({
    super.key,
    required this.words,
    this.hidden = const {},
    this.hints = const {},
    this.size = 24,
    this.textAlign = TextAlign.center,
    this.semanticsLabel,
  });

  /// One entry per word of the target, in order.
  final List<WordCheck> words;

  /// Word indices to draw as a ghost although they carry no verdict yet
  /// (the hidden page before he has reached them).
  final Set<int> hidden;

  /// Word indices he asked to see – drawn as shown, marked as a hint.
  final Set<int> hints;

  final double size;
  final TextAlign textAlign;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = MadarTypography.quran(t, size: size);
    final ghost = t.textPrimary.withValues(alpha: t.isDark ? 0.14 : 0.16);
    final spans = <InlineSpan>[];
    for (var i = 0; i < words.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' ', style: base));
      final w = words[i];
      final color = switch (w.verdict) {
        WordVerdict.right => t.success,
        WordVerdict.wrong => t.danger,
        WordVerdict.skipped => t.warning,
        WordVerdict.unsure => t.textSecondary,
        WordVerdict.pending => hints.contains(i)
            ? t.brass
            : hidden.contains(i)
            ? ghost
            : t.textPrimary,
      };
      spans.add(
        TextSpan(
          text: w.word.text,
          style: base.copyWith(
            color: color,
            decoration: w.verdict == WordVerdict.skipped ? TextDecoration.underline : null,
            decorationStyle: TextDecorationStyle.dotted,
          ),
        ),
      );
    }
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: semanticsLabel != null,
      child: Text.rich(TextSpan(children: spans), textAlign: textAlign),
    );
  }
}

/// The verified text with only the first letters of each word showing – a
/// *verbatim prefix* sliced out of the word, never a letter of Madar's own.
class HifzFirstLettersText extends StatelessWidget {
  const HifzFirstLettersText({super.key, required this.hints, this.size = 24});

  final List<LetterHint> hints;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = MadarTypography.quran(t, size: size);
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < hints.length; i++) ...[
            if (i > 0) TextSpan(text: ' ', style: base),
            TextSpan(text: hints[i].hint, style: base.copyWith(color: t.accent)),
          ],
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// What he typed, kept apart from the Quran: a plain face, the secondary
/// colour, and the label above it. It is his own writing, not scripture,
/// and the screen says so.
class HifzTypedAnswer extends StatelessWidget {
  const HifzTypedAnswer({super.key, required this.text, this.label});

  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final style = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.keyboard_alt_outlined, size: 14, color: t.textTertiary),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                label ?? l.hifzDrillTypedBadge,
                style: style.labelSmall?.copyWith(color: t.textTertiary),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xxs),
        Text(
          text,
          style: style.bodyMedium?.copyWith(color: t.textSecondary, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

/// The honest footer every screen of «الحفظ» carries: the numbers come
/// from his own attempts and are not a ruling.
class HifzHonestyNote extends StatelessWidget {
  const HifzHonestyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: Space.m),
      child: Text(
        L10n.of(context).hifzPlanNotRuling,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
      ),
    );
  }
}
