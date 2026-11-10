// The shared bottom of a colouring board (design 08b): colour swatches (64 dp),
// «خلصت», eraser and undo, «ابدأ من جديد» and the privacy line.
import 'package:flutter/material.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../learn/ui/kids_tokens.dart';
import '../../learn/ui/kids_widgets.dart';
import 'palette.dart';

class ColouringControls extends StatelessWidget {
  const ColouringControls({
    super.key,
    required this.selected,
    required this.eraser,
    required this.canUndo,
    required this.onSelect,
    required this.onEraser,
    required this.onUndo,
    required this.onClear,
    required this.onDone,
  });

  final int selected;
  final bool eraser;
  final bool canUndo;
  final ValueChanged<int> onSelect;
  final VoidCallback onEraser;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: kColouringColours.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _Swatch(
              colour: kColouringColours[i],
              selected: !eraser && i == selected,
              label: l.kidsColSwatch(i + 1),
              onTap: () => onSelect(i),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: KidsButton(
                  label: l.kidsColDone,
                  icon: Icons.check_rounded,
                  kind: KidsButtonKind.teal,
                  onTap: onDone,
                ),
              ),
              const SizedBox(width: 12),
              KidsRoundButton(
                icon: Icons.auto_fix_normal_rounded,
                semanticLabel: l.kidsColEraser,
                background: eraser ? KidsColors.sun300 : KidsColors.paper,
                lip: eraser ? KidsColors.sun700 : KidsColors.sand2,
                onTap: onEraser,
              ),
              const SizedBox(width: 12),
              KidsRoundButton(icon: Icons.rotate_left_rounded, semanticLabel: l.kidsColUndo, onTap: canUndo ? onUndo : null),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: KidsButton(
            label: l.kidsColClear,
            icon: Icons.refresh_rounded,
            kind: KidsButtonKind.paper,
            onTap: onClear,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_rounded, color: KidsColors.teal700, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(l.kidsColSaved, style: KidsType.bodyText(16, color: KidsColors.ink2)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colour, required this.selected, required this.label, required this.onTap});

  final Color colour;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? KidsColors.night900 : Colors.transparent, width: 4),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colour,
            boxShadow: [BoxShadow(color: colour.withValues(alpha: 0.45), offset: const Offset(0, 3))],
          ),
        ),
      ),
    ),
  );
}
