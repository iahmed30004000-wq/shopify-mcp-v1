import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/madar_button.dart';

/// A screen with nothing in it yet: art, one sentence that teaches, and the
/// button for the first thing to do. The [art] is any widget (the app passes
/// the picture later; until then an icon is fine).
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.art,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.actionIcon,
    this.artHeight = 140,
  });

  final Widget art;

  /// One sentence – what this place is for and why it is empty.
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final double artHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(Space.xl),
      decoration: BoxDecoration(
        color: Color.alphaBlend(t.glassFill, t.space2),
        borderRadius: BorderRadius.circular(t.radiusL),
        border: Border.all(color: t.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: SizedBox(height: artHeight, child: Center(child: art))),
          const SizedBox(height: Space.l),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: Space.xl),
          MadarButton(label: actionLabel, icon: actionIcon, onPressed: onAction),
        ],
      ),
    );
  }
}
