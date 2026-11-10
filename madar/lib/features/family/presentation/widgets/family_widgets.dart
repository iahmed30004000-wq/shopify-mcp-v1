import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/contrast.dart';
import '../../../../core/design/themes.dart' show PlanetPalettes;
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/family_models.dart';
import '../../family_texts.dart' show FamilyTexts;
import '../../domain/rhythm.dart';

/// The colour a rhythm state speaks in.
Color familyStatusColor(RhythmStatus s, MadarTokens t) => switch (s) {
  RhythmStatus.overdue => t.danger,
  RhythmStatus.dueToday => t.warning,
  RhythmStatus.dueSoon => t.gold,
  RhythmStatus.ok => t.success,
  RhythmStatus.none => t.textTertiary,
};

/// A person's colour: theirs, else a stable pick from the curated palette.
Color personColor(String name, int? color) {
  if (color != null) return Color(color);
  final colors = CuratedPalette.colors.take(PlanetPalettes.byKey.length).toList();
  var h = 0;
  for (final c in name.runes) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return colors[h % colors.length];
}

IconData channelIcon(ContactChannel c) => switch (c) {
  ContactChannel.call => Icons.call_rounded,
  ContactChannel.visit => Icons.home_rounded,
  ContactChannel.message => Icons.chat_bubble_rounded,
  ContactChannel.other => Icons.favorite_rounded,
};

/// The first letter of [name] (a grapheme, so an Arabic letter with its
/// marks or an emoji stays whole).
String personInitial(String name) {
  final t = BidiIsolate.strip(name).trim();
  if (t.isEmpty) return '·';
  // The person's own name, not the title or kinship word before it: «أختي
  // ليلى» is «ل», "Mr. Jones" is "J" – unless that word is all there is
  // («أمي» stays «أ»).
  final words = t.split(RegExp(r'\s+'));
  var i = 0;
  while (i < words.length - 1 && _leadWords.contains(FamilyTexts.matchForm(words[i]).replaceAll('.', ''))) {
    i++;
  }
  return words[i].characters.first.toUpperCase();
}

/// Titles and kinship words that come before a name (in [FamilyTexts.matchForm]).
const Set<String> _leadWords = {
  // titles
  'م', 'د', 'ا', 'الاستاذ', 'استاذ', 'الاستاذه', 'استاذه', 'الدكتور', 'دكتور', 'الدكتوره', 'دكتوره',
  'المهندس', 'مهندس', 'الحاج', 'حاج', 'الحاجه', 'حجي', 'الشيخ', 'شيخ', 'السيد', 'السيده',
  'mr', 'mrs', 'ms', 'miss', 'dr', 'eng', 'prof', 'sir', 'uncle', 'aunt', 'auntie', 'grandma', 'grandpa',
  // kinship
  'اخي', 'اختي', 'اخوي', 'خالي', 'خالتي', 'عمي', 'عمتي', 'خالو', 'خالتو', 'عمو', 'عمتو', 'ابن', 'بنت',
  'جدي', 'جدتي', 'ستي', 'سيدي', 'ابني', 'بنتي', 'ابنتي', 'صديقي', 'صديقتي', 'زميلي', 'زميلتي', 'جاري', 'جارتي',
};

/// A person's orb: their colour with the initial, ringed by how much of the
/// rhythm has passed (green → gold → amber → red).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.size = 48, this.ring = true});

  final PersonView person;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = personColor(person.name, person.row.color);
    final status = person.rhythm.status;
    final progress = person.rhythm.progress;
    final ringColor = familyStatusColor(status, t);
    final stroke = math.max(2.5, size / 16);
    final inner = size - (ring ? stroke * 2 + 3 : 0);
    // The ink with the better contrast on the person's colour (a light
    // lavender read 2.4 : 1 under white).
    final ink = MadarContrast.bestOn(c, const [Color(0xFF2A1A10), Colors.white]);
    final orb = Container(
      width: inner,
      height: inner,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [Color.lerp(c, Colors.white, 0.28)!, c, Color.lerp(c, Colors.black, 0.35)!],
          stops: const [0, 0.55, 1],
        ),
        boxShadow: t.isDark ? [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: size * 0.3)] : null,
      ),
      child: Text(
        personInitial(person.name),
        style: Theme.of(context).textTheme.titleMedium!.copyWith(
          fontSize: inner * 0.42,
          height: 1.1,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    );
    if (!ring) {
      return SizedBox.square(
        dimension: size,
        child: Center(child: orb),
      );
    }
    return ProgressRing(
      value: progress == null ? 0 : math.min(1, progress),
      size: size,
      strokeWidth: stroke,
      color: ringColor,
      trackColor: t.glassBorder,
      glow: status == RhythmStatus.overdue,
      child: orb,
    );
  }
}

/// A tiny rounded label.
class FamilyBadge extends StatelessWidget {
  const FamilyBadge({super.key, required this.label, required this.color, this.icon, this.filled = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme.labelSmall!;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, 2, Space.s, 2),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: t.isDark ? 0.2 : 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.copyWith(color: color, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// The round one-tap "contacted" button: a soft glowing heart-check that
/// pops when pressed.
class ContactedButton extends StatefulWidget {
  const ContactedButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 44,
    this.emphasis = false,
  });

  final Future<void> Function(BuildContext context) onPressed;
  final String semanticLabel;
  final double size;

  /// Filled (the person is due) rather than outlined.
  final bool emphasis;

  @override
  State<ContactedButton> createState() => _ContactedButtonState();
}

class _ContactedButtonState extends State<ContactedButton> {
  bool _busy = false;
  bool _done = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed(context);
      if (mounted) setState(() => _done = true);
    } finally {
      // The check lingers a beat, then the heart comes back.
      _reset?.cancel();
      _reset = Timer(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _busy = false;
            _done = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = widget.emphasis ? t.accent : t.success;
    final fill = widget.emphasis ? c.withValues(alpha: t.isDark ? 0.28 : 0.16) : Colors.transparent;
    return MadarPressable(
      onTap: _tap,
      sfx: null,
      semanticLabel: widget.semanticLabel,
      focusRadius: BorderRadius.circular(widget.size),
      child: SizedBox.square(
        // The hit area is 48 dp (Android) whatever the drawn heart.
        dimension: math.max(widget.size, 48),
        child: Center(
          child: AnimatedContainer(
            duration: context.motion(MadarMotion.short),
            curve: MadarMotion.standard,
            width: widget.size - 4,
            height: widget.size - 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _done ? t.success.withValues(alpha: t.isDark ? 0.32 : 0.2) : fill,
              border: Border.all(color: (_done ? t.success : c).withValues(alpha: 0.8), width: 1.2),
              boxShadow: widget.emphasis && t.isDark
                  ? [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: widget.size * 0.35)]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.short),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(
                _done ? Icons.check_rounded : Icons.favorite_rounded,
                key: ValueKey(_done),
                size: widget.size * 0.44,
                color: _done ? t.success : c,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round glass icon button for call / SMS / WhatsApp.
class FamilyRoundAction extends StatelessWidget {
  const FamilyRoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showLabel = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.accent;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.tap,
      semanticLabel: label,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      // At least 48 dp wide even when the label under the circle is short.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.withValues(alpha: t.isDark ? 0.16 : 0.1),
                border: Border.all(color: c.withValues(alpha: 0.5), width: 0.9),
              ),
              child: Icon(icon, size: 21, color: c),
            ),
            if (showLabel) ...[
              const SizedBox(height: Space.xs),
              Text(label, style: text.labelSmall!.copyWith(color: t.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section title of the Family screen with a count.
class FamilySectionTitle extends StatelessWidget {
  const FamilySectionTitle({super.key, required this.title, required this.count, required this.color, this.icon});

  final String title;
  final String count;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, Space.s),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: t.isDark ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)] : null,
            ),
          ),
          const SizedBox(width: Space.s),
          if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: Space.xs)],
          Text(
            title,
            style: text.titleSmall!.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: Space.s),
          Text(count, style: text.labelMedium!.copyWith(color: t.textTertiary)),
          const SizedBox(width: Space.s),
          Expanded(child: Container(height: 0.8, color: t.glassBorder)),
        ],
      ),
    );
  }
}
