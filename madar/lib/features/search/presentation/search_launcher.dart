import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import 'global_search_screen.dart';

/// A compact way into the global search, for the home panel and app bars:
/// a glass "Search Madar" pill ([SearchLauncher.new]) or a round icon
/// button ([SearchLauncher.icon]).
///
/// Opens [GlobalSearchScreen] with [onOpen] when given (e.g. the app's
/// router), else pushes it on the nearest navigator.
class SearchLauncher extends StatelessWidget {
  const SearchLauncher({super.key, this.onOpen, this.hint}) : compact = false;

  const SearchLauncher.icon({super.key, this.onOpen}) : compact = true, hint = null;

  final VoidCallback? onOpen;

  /// The pill's text (default «ابحث في مَدار» / "Search Madar").
  final String? hint;

  /// The round icon button instead of the pill.
  final bool compact;

  void _open(BuildContext context) {
    final open = onOpen;
    if (open != null) {
      open();
    } else {
      GlobalSearchScreen.open(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    if (compact) {
      return MadarButton.icon(
        icon: Icons.search_rounded,
        onPressed: () => _open(context),
        semanticLabel: l.searchLauncherTooltip,
        variant: MadarButtonVariant.ghost,
      );
    }
    final text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: () => _open(context),
      semanticLabel: l.searchLauncherTooltip,
      borderRadius: BorderRadius.circular(t.radiusXL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: t.accent, size: 22),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(
              hint ?? l.searchLauncherHint,
              style: text.bodyMedium!.copyWith(color: t.textTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.auto_awesome_rounded, color: t.gold.withValues(alpha: 0.8), size: 16),
        ],
      ),
    );
  }
}
