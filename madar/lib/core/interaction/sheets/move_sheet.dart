import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../i18n/gen/app_localizations.dart';
import '../../motion/motion.dart';
import '../../sound/sound_api.dart';
import '../src/glass.dart';
import '../src/pressable.dart';
import '../src/search.dart';
import '../src/stagger.dart';
import 'field_inputs.dart' show kitInputDecoration;
import 'sheet.dart';

/// A destination offered by [showMoveSheet] (a planet, project, list, day …).
@immutable
class MoveTarget {
  const MoveTarget({
    required this.id,
    required this.label,
    this.icon,
    this.color,
    this.group,
    this.subtitle,
    this.isCurrent = false,
    this.enabled = true,
  });

  final String id;
  final String label;
  final IconData? icon;

  /// Orb colour (e.g. the planet's palette colour); the theme accent when null.
  final Color? color;

  /// Optional section header; targets sharing a group are listed together
  /// under it, in first-appearance order.
  final String? group;
  final String? subtitle;

  /// Where the item currently lives – shown with a "Current" badge and not
  /// selectable.
  final bool isCurrent;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is MoveTarget &&
      other.id == id &&
      other.label == label &&
      other.icon == icon &&
      other.color == color &&
      other.group == group &&
      other.subtitle == subtitle &&
      other.isCurrent == isCurrent &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, label, icon, color, group, subtitle, isCurrent, enabled);
}

/// Groups [targets] by [MoveTarget.group] (ungrouped first, then groups in
/// first-appearance order) after filtering by [query]. Pure – unit-tested.
List<(String?, List<MoveTarget>)> groupMoveTargets(List<MoveTarget> targets, {String query = ''}) {
  final groups = <String?, List<MoveTarget>>{};
  for (final t in targets) {
    if (!KitSearch.matches(query, [t.label, t.subtitle, t.group])) continue;
    (groups[t.group] ??= []).add(t);
  }
  final ungrouped = groups.remove(null);
  return [if (ungrouped != null) (null, ungrouped), for (final e in groups.entries) (e.key, e.value)];
}

/// Opens a glass sheet listing [targets] and resolves with the one the user
/// picked (null when dismissed). A search field appears automatically for
/// longer lists ([searchable] overrides).
Future<MoveTarget?> showMoveSheet(
  BuildContext context, {
  required String title,
  required List<MoveTarget> targets,
  String? subtitle,
  IconData icon = Icons.drive_file_move_rounded,
  bool? searchable,
}) {
  return showInteractionSheet<MoveTarget>(
    context,
    builder: (_) => MoveSheet(
      title: title,
      targets: targets,
      subtitle: subtitle,
      icon: icon,
      searchable: searchable ?? targets.length > 7,
    ),
  );
}

/// Body of [showMoveSheet] (public for embedding / tests).
class MoveSheet extends StatefulWidget {
  const MoveSheet({
    super.key,
    required this.title,
    required this.targets,
    this.subtitle,
    this.icon = Icons.drive_file_move_rounded,
    this.searchable = false,
  });

  final String title;
  final List<MoveTarget> targets;
  final String? subtitle;
  final IconData icon;
  final bool searchable;

  @override
  State<MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<MoveSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQuery);
  }

  void _onQuery() => setState(() {});

  @override
  void dispose() {
    _query.removeListener(_onQuery);
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final sections = groupMoveTargets(widget.targets, query: _query.text);

    final children = <Widget>[];
    var index = 0;
    for (final (group, items) in sections) {
      if (group != null) {
        children.add(
          KitStaggerIn(
            index: index++,
            child: _GroupHeader(label: group),
          ),
        );
      }
      for (final target in items) {
        children.add(
          KitStaggerIn(
            index: index++,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: _TargetRow(target: target),
            ),
          ),
        );
      }
    }

    final Widget body = sections.isEmpty
        ? Padding(
            key: const ValueKey('empty'),
            padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xxl),
            child: Column(
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: CustomPaint(painter: StarOrnamentPainter(color: t.brass.withValues(alpha: 0.5))),
                ),
                const SizedBox(height: Space.m),
                Semantics(
                  liveRegion: true,
                  child: Text(l10n.interactionMoveEmpty, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
                ),
              ],
            ),
          )
        : Column(
            key: ValueKey('list-${_query.text}'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );

    return InteractionSheetFrame(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      toolbar: widget.searchable
          ? TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              decoration: kitInputDecoration(
                context,
                hint: l10n.interactionMoveSearch,
              ).copyWith(prefixIcon: Icon(Icons.search_rounded, color: t.textTertiary, size: 20), isDense: true),
            )
          : null,
      body: AnimatedSwitcher(
        duration: context.motion(MadarMotion.short),
        layoutBuilder: (current, previous) =>
            Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
        child: body,
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.m, bottom: Space.s, start: Space.xxs),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Text(label, style: text.labelLarge?.copyWith(color: t.brass, letterSpacing: 0.4)),
            const SizedBox(width: Space.m),
            Expanded(
              child: Container(
                height: 0.8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [t.brass.withValues(alpha: 0.5), t.brass.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({required this.target});

  final MoveTarget target;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final color = target.color ?? t.accent;
    final selectable = target.enabled && !target.isCurrent;
    final onOrb = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? t.starTint : t.space0;
    return Opacity(
      opacity: target.enabled ? 1 : 0.45,
      child: KitPressable(
        enabled: selectable,
        sfx: Sfx.drop,
        pressScale: 0.975,
        selected: target.isCurrent,
        semanticLabel: [
          target.label,
          if (target.subtitle != null) target.subtitle!,
          if (target.isCurrent) l10n.interactionMoveCurrent,
        ].join(Directionality.of(context) == TextDirection.rtl ? '، ' : ', '),
        excludeSemantics: true,
        onTap: () => Navigator.of(context).pop(target),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusM),
            color: target.isCurrent ? t.accentSoft.withValues(alpha: t.accentSoft.a * 0.6) : t.glassFill,
            border: Border.all(
              color: target.isCurrent ? t.accent.withValues(alpha: 0.6) : t.glassBorder,
              width: target.isCurrent ? 1.2 : 0.9,
            ),
          ),
          child: Row(
            children: [
              // Glowing orb in the destination's colour.
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.4),
                    colors: [Color.lerp(color, t.glassHighlight, 0.35)!, color, Color.lerp(color, t.space0, 0.35)!],
                    stops: const [0, 0.6, 1],
                  ),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 14)],
                ),
                child: target.icon == null ? null : Icon(target.icon, size: 19, color: onOrb),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(target.label, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (target.subtitle != null)
                      Text(
                        target.subtitle!,
                        style: text.bodySmall?.copyWith(color: t.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Space.s),
              if (target.isCurrent)
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.xxs),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(t.radiusXL),
                    border: Border.all(color: t.accent.withValues(alpha: 0.6), width: 0.8),
                  ),
                  child: Text(l10n.interactionMoveCurrent, style: text.labelSmall?.copyWith(color: t.accent)),
                )
              else
                Icon(Icons.chevron_right_rounded, color: t.textTertiary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
