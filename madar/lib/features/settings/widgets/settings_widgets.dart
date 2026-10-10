import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';

/// A titled group of settings rows on one glass panel. A null [title] leaves
/// the header out (a page whose app bar already names its only group).
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, this.subtitle, required this.children, this.seed = 0});

  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final double seed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title case final title?)
          SectionHeader(
            title: title,
            subtitle: subtitle,
            padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
          )
        else
          const SizedBox(height: Space.l),
        GlassPanel(
          padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
          seed: seed,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
                    child: Divider(height: 1, thickness: 0.6, color: t.glassBorder.withValues(alpha: 0.35)),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The round tinted badge that leads every settings row.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {super.key, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.accent;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withValues(alpha: 0.14),
        border: Border.all(color: c.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Icon(icon, size: 18, color: c),
    );
  }
}

/// A settings row: icon, title, optional subtitle and trailing widget.
/// With [onTap] the row is pressable; [navigates] adds a direction-aware
/// chevron and plays [Sfx.navigate].
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.navigates = false,
    this.iconColor,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool navigates;
  final Color? iconColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final row = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          SettingsIcon(icon, color: iconColor),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: text.titleMedium!.copyWith(height: 1.3)),
                if (subtitle != null)
                  Text(subtitle!, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.35)),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Space.s), trailing!],
          if (navigates) ...[
            const SizedBox(width: Space.xs),
            // chevron_right is declared matchTextDirection: Icon mirrors it
            // under RTL by itself.
            Icon(Icons.chevron_right_rounded, color: t.textTertiary),
          ],
        ],
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    return MadarPressable(
      onTap: onTap,
      sfx: navigates ? Sfx.navigate : Sfx.tap,
      pressScale: 0.985,
      semanticLabel: semanticLabel,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: row,
    );
  }
}

/// A row with a [MadarSwitch]; tapping anywhere on the row toggles it.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: SettingsTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        trailing: MadarSwitch(value: value, onChanged: onChanged, semanticLabel: title),
      ),
    );
  }
}

/// A row holding a [ChoicePills] group under its title.
class SettingsChoiceTile<T> extends StatelessWidget {
  const SettingsChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<ChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsTile(icon: icon, title: title, subtitle: subtitle),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l + 36 + Space.m, 0, Space.l, Space.l),
          child: ChoicePills<T>.single(
            options: options,
            selected: selected,
            dense: true,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
        ?footer,
      ],
    );
  }
}

/// A volume row: title, live percentage and a themed slider. Feedback plays
/// on release at the chosen level (so the user hears the result).
class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    return AnimatedOpacity(
      duration: context.motion(MadarMotion.short),
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SettingsIcon(icon),
                const SizedBox(width: Space.m),
                Expanded(child: Text(title, style: text.titleMedium)),
                Text(
                  fmt.formatPercent(value),
                  style: text.labelLarge!.copyWith(color: t.accent, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: t.accent,
                inactiveTrackColor: t.glassBorder.withValues(alpha: 0.5),
                thumbColor: t.gold,
                overlayColor: t.accentSoft,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9, elevation: 2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: value.clamp(0.0, 1.0),
                onChanged: enabled ? onChanged : null,
                onChangeEnd: enabled ? onChangeEnd : null,
                semanticFormatterCallback: (v) => fmt.formatPercent(v),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short explanatory note under a group of settings.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.text, {super.key, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textTertiary, height: 1.45);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.l, Space.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Icon(icon, size: 15, color: t.textTertiary),
          ),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

/// The scrolling body of a settings page inside a `MadarScaffold` with
/// `extendBodyBehindAppBar`: clears the (frosting) app bar and the system
/// insets, which are only known inside the scaffold body.
class SettingsListView extends StatelessWidget {
  const SettingsListView({super.key, required this.children, this.horizontal = Space.gutter, this.top = Space.xs});

  final List<Widget> children;
  final double horizontal;
  final double top;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(horizontal, padding.top + top, horizontal, padding.bottom + Space.xxxl),
      children: children,
    );
  }
}
