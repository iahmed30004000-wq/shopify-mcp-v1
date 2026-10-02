import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart' show KitChip;
import '../../../../../core/sound/sound_api.dart';

/// One option of [showChoiceSheet].
class ChoiceItem<T> {
  const ChoiceItem({required this.value, required this.label, this.icon, this.color});

  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
}

/// A glass sheet of chips: pick several ([multi]) or one. Returns the new
/// selection (empty = "all"), or null when dismissed.
Future<Set<T>?> showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<ChoiceItem<T>> items,
  required Set<T> selected,
  bool multi = true,
  IconData? icon,
  String? emptyText,
  Widget? header,
}) {
  return showInteractionSheet<Set<T>>(
    context,
    builder: (_) => _ChoiceSheet<T>(
      title: title,
      items: items,
      selected: selected,
      multi: multi,
      icon: icon,
      emptyText: emptyText,
      header: header,
    ),
  );
}

class _ChoiceSheet<T> extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.multi,
    this.icon,
    this.emptyText,
    this.header,
  });

  final String title;
  final List<ChoiceItem<T>> items;
  final Set<T> selected;
  final bool multi;
  final IconData? icon;
  final String? emptyText;
  final Widget? header;

  @override
  State<_ChoiceSheet<T>> createState() => _ChoiceSheetState<T>();
}

class _ChoiceSheetState<T> extends State<_ChoiceSheet<T>> {
  late Set<T> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    return InteractionSheetFrame(
      title: widget.title,
      icon: widget.icon,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?widget.header,
          if (widget.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xl),
              child: Text(
                widget.emptyText ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textSecondary),
              ),
            )
          else
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                KitChip(
                  label: l.ledgerAll,
                  selected: _selected.isEmpty,
                  sfx: Sfx.tap,
                  onTap: () {
                    if (widget.multi) {
                      setState(() => _selected = {});
                    } else {
                      Navigator.of(context).pop(<T>{});
                    }
                  },
                ),
                for (final item in widget.items)
                  KitChip(
                    label: item.label,
                    icon: item.icon,
                    swatch: item.color,
                    showCheck: widget.multi,
                    selected: _selected.contains(item.value),
                    onTap: () {
                      if (!widget.multi) {
                        Navigator.of(context).pop({item.value});
                        return;
                      }
                      setState(() {
                        _selected = {..._selected};
                        if (!_selected.remove(item.value)) _selected.add(item.value);
                      });
                    },
                  ),
              ],
            ),
        ],
      ),
      footer: widget.multi
          ? SizedBox(
              width: double.infinity,
              child: SheetButton(
                label: l.ledgerApply,
                icon: Icons.check_rounded,
                primary: true,
                sfx: Sfx.complete,
                onPressed: () => Navigator.of(context).pop(_selected),
              ),
            )
          : null,
    );
  }
}

/// A chip label for a selection: "All", the single choice, or "first +n".
String choiceSummary(L10n l, MadarFormatter f, List<String> labels) {
  if (labels.isEmpty) return l.ledgerAll;
  if (labels.length == 1) return labels.single;
  return l.ledgerFilterMore(labels.first, f.formatInt(labels.length - 1));
}
