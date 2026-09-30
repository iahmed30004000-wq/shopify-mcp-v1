import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/packing.dart';
import '../../travel_texts.dart';
import 'travel_widgets.dart';

/// The packing summary: the ring (with the count), what is left, and the
/// list tools (from a template, save as a template, unpack all).
class PackingSummary extends StatelessWidget {
  const PackingSummary({
    super.key,
    required this.progress,
    required this.ringKey,
    required this.onFromTemplate,
    required this.onSaveAsTemplate,
    required this.onUnpackAll,
  });

  final PackingProgress progress;

  /// Celebrations burst from the ring.
  final GlobalKey ringKey;
  final VoidCallback onFromTemplate;
  final VoidCallback? onSaveAsTemplate;
  final VoidCallback? onUnpackAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final p = progress;
    return GlassCard(
      glow: p.complete,
      glowColor: t.success,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.m, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              KeyedSubtree(
                key: ringKey,
                child: PackingRing(
                  progress: p,
                  size: 76,
                  label: p.isEmpty || p.complete ? null : tx.fmt.localizeDigits('${p.packed}/${p.total}'),
                  semanticLabel: tx.packedCount(p),
                ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.travelPackingTitle, style: text.titleLarge),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: context.motion(MadarMotion.short),
                      child: Text(
                        p.isEmpty ? l.travelPackingEmptyBody : tx.remaining(p),
                        key: ValueKey('${p.packed}/${p.total}'),
                        style: text.bodyMedium!.copyWith(color: p.complete ? t.success : t.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              MadarButton(
                label: l.travelFromTemplate,
                icon: Icons.playlist_add_rounded,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.secondary,
                sfx: Sfx.sheetOpen,
                onPressed: onFromTemplate,
              ),
              if (onSaveAsTemplate != null)
                MadarButton(
                  label: l.travelSaveAsTemplate,
                  icon: Icons.bookmark_add_rounded,
                  size: MadarButtonSize.small,
                  variant: MadarButtonVariant.ghost,
                  sfx: Sfx.sheetOpen,
                  onPressed: onSaveAsTemplate,
                ),
              if (onUnpackAll != null)
                MadarButton(
                  label: l.travelUnpackAll,
                  icon: Icons.unarchive_rounded,
                  size: MadarButtonSize.small,
                  variant: MadarButtonVariant.ghost,
                  sfx: Sfx.tap,
                  onPressed: onUnpackAll,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A category header inside the packing list (not draggable).
class PackingCategoryHeader extends StatelessWidget {
  const PackingCategoryHeader({super.key, required this.category, required this.progress});

  final String category;
  final PackingProgress progress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final done = progress.complete;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.s, 0),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Icon(categoryIcon(category), size: 18, color: done ? t.success : t.gold),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text(
                tx.category(category),
                style: text.titleSmall!.copyWith(color: done ? t.success : t.gold, letterSpacing: 0.2),
              ),
            ),
            Text(
              BidiIsolate.ltr(tx.fmt.localizeDigits('${progress.packed}/${progress.total}')),
              style: text.labelMedium!.copyWith(color: done ? t.success : t.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A packing item: a check that fills when packed, the item (struck
/// through once packed) and the drag handle.
class PackingItemTile extends StatelessWidget {
  const PackingItemTile({super.key, required this.item, this.dragHandle, this.onToggle});

  final TripItemRow item;
  final Widget? dragHandle;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final packed = item.packed;
    final duration = context.motion(MadarMotion.short);
    final uiStart = Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    return GlassCard(
      glow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xs, Space.xs, Space.xs),
      child: Row(
        children: [
          MadarPressable(
            onTap: onToggle,
            sfx: null,
            toggled: packed,
            semanticLabel: packed ? l.travelItemPacked : l.travelItemNotPacked,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(Space.s),
              child: AnimatedContainer(
                duration: duration,
                curve: MadarMotion.standard,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: packed ? t.success.withValues(alpha: 0.2) : Colors.transparent,
                  border: Border.all(color: packed ? t.success : t.textTertiary, width: 1.6),
                  boxShadow: packed && t.isDark ? [BoxShadow(color: t.success.withValues(alpha: 0.35), blurRadius: 8)] : null,
                ),
                child: AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: packed
                      ? Icon(Icons.check_rounded, key: const ValueKey('on'), size: 16, color: t.success)
                      : const SizedBox(key: ValueKey('off')),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: AnimatedOpacity(
              opacity: packed ? 0.6 : 1,
              duration: duration,
              child: Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: BidiIsolate.directionOf(item.body),
                textAlign: uiStart,
                style: text.bodyLarge!.copyWith(
                  color: packed ? t.textSecondary : t.textPrimary,
                  decoration: packed ? TextDecoration.lineThrough : null,
                  decorationColor: t.textTertiary,
                ),
              ),
            ),
          ),
          dragHandle ?? const SizedBox(width: Space.s),
        ],
      ),
    );
  }
}

/// "Add an item" with its category (tap the icon to change it).
class PackingAddRow extends StatefulWidget {
  const PackingAddRow({super.key, required this.category, required this.onPickCategory, required this.onAdd});

  final String category;
  final VoidCallback onPickCategory;
  final void Function(String body) onAdd;

  @override
  State<PackingAddRow> createState() => _PackingAddRowState();
}

class _PackingAddRowState extends State<PackingAddRow> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    widget.onAdd(body);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      glow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xs, Space.xs, Space.xs),
      child: Row(
        children: [
          MadarPressable(
            onTap: widget.onPickCategory,
            sfx: Sfx.sheetOpen,
            semanticLabel: l.travelAddItemIn(tx.category(widget.category)),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(Space.s),
              child: Icon(categoryIcon(widget.category), color: t.accent, size: 22),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: kitInputDecoration(context, hint: l.travelAddItemTo(tx.category(widget.category))).copyWith(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: text.bodyMedium!.copyWith(color: t.textTertiary),
              ),
            ),
          ),
          MadarButton.icon(
            icon: Icons.add_rounded,
            semanticLabel: l.travelAddItem,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.primary,
            sfx: Sfx.tap,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
