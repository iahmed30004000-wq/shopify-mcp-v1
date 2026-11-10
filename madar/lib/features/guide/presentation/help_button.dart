import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/pressable.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/guide_entry.dart';
import 'guide_scope.dart';
import 'guide_sheet.dart';

/// The «؟» button for a screen's app bar: opens the guide sheet. 48 dp.
///
/// Give it an [entryId] (read through the nearest [GuideScope]) or a ready
/// [entry]. Pass [onReplayTour] when the screen has a coach tour.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, this.entryId, this.entry, this.onReplayTour, this.lookup})
    : assert(entryId != null || entry != null, 'Give an entryId or an entry');

  final String? entryId;
  final GuideEntry? entry;
  final VoidCallback? onReplayTour;

  /// Resolves related entries when [entry] is given directly.
  final GuideEntry? Function(String id)? lookup;

  static const double size = 48;

  void _open(BuildContext context) {
    final direct = entry;
    if (direct != null) {
      showGuideSheet(context, entry: direct, lookup: lookup, onReplayTour: onReplayTour);
    } else {
      showGuideSheetById(context, entryId!, onReplayTour: onReplayTour);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = L10n.of(context);
    return SizedBox.square(
      dimension: size,
      child: MadarPressable(
        onTap: () => _open(context),
        semanticLabel: l10n.guideHelpTooltip,
        excludeChildSemantics: true,
        child: Center(
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.accentSoft,
              border: Border.all(color: t.accent.withValues(alpha: 0.6), width: 1),
            ),
            child: Text(
              l10n.guideHelpGlyph,
              textScaler: TextScaler.noScaling,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.accent, fontWeight: FontWeight.w700, height: 1),
            ),
          ),
        ),
      ),
    );
  }
}
