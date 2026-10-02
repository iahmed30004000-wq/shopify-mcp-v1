import 'package:flutter/material.dart';

import '../tokens.dart';
import 'madar_button.dart';
import 'ornaments.dart';

/// Section title in Reem Kufi with a small star ornament, optional subtitle
/// and an optional trailing ghost action ("See all ›", mirrored in RTL).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.ornament = true,
    this.padding = const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xl, Space.gutter, Space.m),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool ornament;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (ornament) ...[const IslamicStar(size: 15, glow: true), const SizedBox(width: Space.s + 2)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: text.headlineSmall!.copyWith(color: t.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    // On the bare backdrop: secondary, not tertiary, contrast.
                    style: text.bodySmall!.copyWith(color: t.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            MadarButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              trailingIcon: Icons.chevron_right_rounded,
            ),
        ],
      ),
    );
  }
}
