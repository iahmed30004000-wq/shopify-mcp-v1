import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/record_list.dart';
import '../list_texts.dart';

/// The ring of a list: ticked over total, green and ticked once it is all
/// done.
class ListRing extends StatelessWidget {
  const ListRing({super.key, required this.totals, this.size = 76, this.label, this.semanticLabel});

  final ListTotals totals;
  final double size;

  /// The text inside («٢/٥»); nothing shows a tick when complete.
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final done = totals.complete;
    return ProgressRing(
      value: totals.fraction,
      size: size,
      strokeWidth: size >= 64 ? 7 : 4,
      color: done ? t.success : t.accent,
      gradientEnd: done ? Color.lerp(t.success, t.gold, 0.4) : t.gold,
      semanticLabel: semanticLabel,
      child: label == null || done
          ? (done ? Icon(Icons.check_rounded, color: t.success, size: size * 0.4) : null)
          : Text(
              label!,
              textDirection: TextDirection.ltr,
              style: (size >= 64 ? text.titleMedium : text.labelSmall)!.copyWith(
                color: t.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

/// One line of a list: a check that fills when it is ticked, his words
/// (struck through once ticked), how much and what it costs, and the drag
/// handle.
class ListItemTile extends StatelessWidget {
  const ListItemTile({
    super.key,
    required this.line,
    required this.texts,
    this.listCurrency,
    this.dragHandle,
    this.onToggle,
  });

  final ListLine line;
  final ListTexts texts;

  /// The currency its price is in (null = the base currency).
  final String? listCurrency;
  final Widget? dragHandle;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final done = line.done;
    final duration = context.motion(MadarMotion.short);
    final uiStart = Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    final meta = texts.itemMeta(line, listCurrency);
    return GlassCard(
      glow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xs, Space.xs, Space.xs),
      child: Row(
        children: [
          MadarPressable(
            onTap: onToggle,
            sfx: null,
            toggled: done,
            semanticLabel: done ? l.listsItemTicked : l.listsItemOpen,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(Space.s),
              child: AnimatedContainer(
                duration: duration,
                curve: MadarMotion.standard,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? t.success.withValues(alpha: 0.2) : Colors.transparent,
                  border: Border.all(color: done ? t.success : t.textTertiary, width: 1.6),
                  boxShadow: done && t.isDark
                      ? [BoxShadow(color: t.success.withValues(alpha: 0.35), blurRadius: 8)]
                      : null,
                ),
                child: AnimatedSwitcher(
                  duration: duration,
                  transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                  child: done
                      ? Icon(Icons.check_rounded, key: const ValueKey('on'), size: 16, color: t.success)
                      : const SizedBox(key: ValueKey('off')),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: BidiIsolate.directionOf(line.title),
                  textAlign: uiStart,
                  style: text.bodyLarge!.copyWith(
                    color: done ? t.textSecondary : t.textPrimary,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: t.textTertiary,
                  ),
                ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2),
                    child: Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: uiStart,
                      style: text.bodySmall!.copyWith(color: done ? t.textTertiary : t.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          dragHandle ?? const SizedBox(width: Space.s),
        ],
      ),
    );
  }
}

/// "Add an item" at the top of a list: he types, presses done, and the
/// field stays focused for the next one.
class ListAddRow extends StatefulWidget {
  const ListAddRow({super.key, required this.onAdd, this.hint, this.addLabel, this.enabled = true});

  final void Function(String title) onAdd;
  final String? hint;
  final String? addLabel;
  final bool enabled;

  @override
  State<ListAddRow> createState() => _ListAddRowState();
}

class _ListAddRowState extends State<ListAddRow> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    widget.onAdd(title);
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final hint = widget.hint ?? l.listsAddItemHint;
    return GlassCard(
      glow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs, Space.xs, Space.xs),
      child: Row(
        children: [
          Icon(Icons.playlist_add_rounded, color: t.accent, size: 22),
          const SizedBox(width: Space.s),
          Expanded(
            child: TextField(
              key: const ValueKey('lists.add.field'),
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: kitInputDecoration(context, hint: hint).copyWith(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: text.bodyMedium!.copyWith(color: t.textTertiary),
              ),
            ),
          ),
          MadarButton.icon(
            key: const ValueKey('lists.add.button'),
            icon: Icons.add_rounded,
            semanticLabel: widget.addLabel ?? l.listsAddItem,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.primary,
            sfx: Sfx.tap,
            onPressed: widget.enabled ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// One list on its host's screen: the ring, the name, what is left and
/// what it costs, plus the "posted" mark once its ticked part became an
/// expense.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.name, required this.totals, required this.texts, this.currency, this.posted = false, this.amountMilli});

  final String name;
  final ListTotals totals;
  final ListTexts texts;
  final String? currency;

  /// Already turned into one money entry.
  final bool posted;

  /// What was posted (when [posted]), else what the ticked part is worth.
  final int? amountMilli;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final amount = amountMilli;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.xs, Space.s + 2),
      child: Row(
        children: [
          ListRing(totals: totals, size: 48, label: texts.progress(totals)),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: BidiIsolate.directionOf(name),
                  style: text.titleSmall!.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  texts.status(totals),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: totals.complete ? t.success : t.textSecondary),
                ),
                if (posted || (amount != null && amount != 0)) ...[
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      if (posted)
                        MadarChip(label: l.listsPostedBadge, icon: Icons.receipt_long_rounded, selected: true, dense: true),
                      if (amount != null && amount != 0)
                        Text(
                          posted ? texts.money(amount, currency) : texts.l.listsTickedAmount(texts.money(amount, currency)),
                          style: text.labelMedium!.copyWith(color: t.gold),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.xs),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
        ],
      ),
    );
  }
}

/// The tile a host record's own screen shows to reach its lists («قائمة
/// الأغراض · ٢ من ٥»). Tapping it opens the host's lists.
class ListsHostTile extends StatelessWidget {
  const ListsHostTile({
    super.key,
    required this.title,
    required this.onOpen,
    this.subtitle,
    this.icon = Icons.checklist_rtl_rounded,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final sub = subtitle;
    return GlassCard(
      glow: false,
      onTap: onOpen,
      semanticLabel: [title, ?sub].join(', '),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          Icon(icon, size: 20, color: t.gold),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: text.titleSmall),
                if (sub != null && sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2),
                    child: Text(sub, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                  ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
        ],
      ),
    );
  }
}
