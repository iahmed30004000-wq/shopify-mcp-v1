import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/madar_button.dart';
import '../../../core/design/widgets/pressable.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/sheets/sheet.dart';
import '../domain/guide_entry.dart';
import 'guide_scope.dart';

/// Opens the guide sheet for [entry] over the current screen.
///
/// [lookup] resolves the entries it points to (the «ممكن يفيدك كمان» links);
/// [onReplayTour] shows the «replay» button, for a screen that has a tour.
Future<void> showGuideSheet(
  BuildContext context, {
  required GuideEntry entry,
  GuideEntry? Function(String id)? lookup,
  VoidCallback? onReplayTour,
}) {
  return showInteractionSheet<void>(
    context,
    builder: (_) => GuideSheet(entry: entry, lookup: lookup, onReplayTour: onReplayTour),
  );
}

/// Opens the guide sheet for the entry [id] from the nearest [GuideScope].
/// Does nothing when the scope or the entry is missing.
Future<void> showGuideSheetById(BuildContext context, String id, {VoidCallback? onReplayTour}) async {
  final scope = GuideScope.maybeOf(context);
  final entry = scope?.entry(context, id);
  if (scope == null || entry == null) return;
  final resolve = scope.resolverFor(context);
  return showGuideSheet(
    context,
    entry: entry,
    lookup: (other) => scope.registry.entry(other, resolve),
    onReplayTour: onReplayTour,
  );
}

/// What a screen is for, one example, the things to do here, and where to go
/// next. Related links open in the same sheet, with a way back.
class GuideSheet extends StatefulWidget {
  const GuideSheet({super.key, required this.entry, this.lookup, this.onReplayTour});

  final GuideEntry entry;
  final GuideEntry? Function(String id)? lookup;

  /// Shown (as «replay the quick tour») only on the first entry, never on a
  /// related one: its tour belongs to its own screen.
  final VoidCallback? onReplayTour;

  @override
  State<GuideSheet> createState() => _GuideSheetState();
}

class _GuideSheetState extends State<GuideSheet> {
  late final List<GuideEntry> _stack = [widget.entry];

  // A new entry starts at its top, not where the last one was scrolled to.
  final ScrollController _scroll = ScrollController();

  GuideEntry get _shown => _stack.last;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _show(void Function() change) {
    setState(change);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _open(GuideEntry e) => _show(() => _stack.add(e));

  void _back() => _show(_stack.removeLast);

  void _replay() {
    final replay = widget.onReplayTour;
    Navigator.of(context).pop();
    // After the sheet has left, so the tour measures the real screen.
    if (replay != null) WidgetsBinding.instance.addPostFrameCallback((_) => replay());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final e = _shown;
    final related = [for (final id in e.related) ?widget.lookup?.call(id)];
    final canReplay = _stack.length == 1 && e.hasTour && widget.onReplayTour != null;

    Widget heading(String label) => Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.s),
      child: Semantics(
        header: true,
        child: Text(label, style: text.labelLarge?.copyWith(color: t.textSecondary)),
      ),
    );

    return InteractionSheetFrame(
      title: e.title,
      scrollController: _scroll,
      icon: Icons.help_outline_rounded,
      footer: canReplay
          ? MadarButton(
              label: l10n.guideReplayTour,
              icon: Icons.play_circle_outline_rounded,
              variant: MadarButtonVariant.secondary,
              expand: true,
              onPressed: _replay,
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_stack.length > 1)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MadarButton(
                label: l10n.guideSheetBack,
                icon: Icons.arrow_back_rounded,
                variant: MadarButtonVariant.ghost,
                onPressed: _back,
              ),
            ),
          heading(l10n.guideSheetPurposeHeading),
          Text(e.purpose, style: text.bodyLarge),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Space.l),
            child: _ExampleCard(label: l10n.guideSheetExampleHeading, text: e.example),
          ),
          heading(l10n.guideSheetDoHeading),
          for (final item in e.doItems) _DoItem(text: item),
          if (related.isNotEmpty) ...[
            heading(l10n.guideSheetRelatedHeading),
            for (final r in related) _RelatedLink(entry: r, onTap: () => _open(r)),
          ],
        ],
      ),
    );
  }
}

/// The example in a highlighted card: the part people remember.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(Space.l),
        decoration: BoxDecoration(
          color: Color.alphaBlend(t.accentSoft, t.space2),
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: t.accent.withValues(alpha: 0.55), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(Icons.lightbulb_outline_rounded, color: t.gold, size: 22)),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: style.labelMedium?.copyWith(color: t.gold, fontWeight: FontWeight.w700)),
                  const SizedBox(height: Space.xs),
                  Text(text, style: style.bodyLarge?.copyWith(color: t.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoItem extends StatelessWidget {
  const _DoItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(top: 2),
              child: Icon(Icons.check_circle_outline_rounded, color: t.accent, size: 20),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _RelatedLink extends StatelessWidget {
  const _RelatedLink({required this.entry, required this.onTap});

  final GuideEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MadarPressable(
      onTap: onTap,
      semanticLabel: entry.title,
      excludeChildSemantics: true,
      minTapTarget: MadarPressable.minTouchTarget,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: t.accent, fontWeight: FontWeight.w600),
              ),
            ),
            // Mirrors itself in RTL.
            Icon(Icons.chevron_right_rounded, color: t.accent, textDirection: Directionality.of(context)),
          ],
        ),
      ),
    );
  }
}
