import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/interaction/sheets/field_inputs.dart' show KitChip;
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';

/// The medication tracker's editors in the interaction kit's edit-sheet
/// style: Cancel / Save footer, and – with unsaved changes – a "Discard
/// changes?" bar instead of closing on a drag or a tap outside.
class MedsEditorFrame extends StatefulWidget {
  const MedsEditorFrame({
    super.key,
    required this.title,
    required this.icon,
    required this.body,
    required this.dirty,
    required this.onSave,
    this.subtitle,
    this.canSave = true,
    this.onRejectedSave,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget body;
  final bool dirty;
  final bool canSave;
  final VoidCallback onSave;

  /// A tap on the disabled Save (show what is missing).
  final VoidCallback? onRejectedSave;

  @override
  State<MedsEditorFrame> createState() => _MedsEditorFrameState();
}

class _MedsEditorFrameState extends State<MedsEditorFrame> {
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final footer = AnimatedSize(
      duration: context.motion(MadarMotion.short),
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: context.motion(MadarMotion.short),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
        ),
        child: _confirming ? _discardBar(l) : _actionBar(l),
      ),
    );
    return PopScope<Object?>(
      canPop: !widget.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Fx.fire(Sfx.error);
        setState(() => _confirming = true);
      },
      child: InteractionSheetFrame(
        title: widget.title,
        subtitle: widget.subtitle,
        icon: widget.icon,
        body: widget.body,
        footer: footer,
      ),
    );
  }

  Widget _actionBar(L10n l) => Row(
    key: const ValueKey('actions'),
    children: [
      Expanded(
        flex: 2,
        child: SheetButton(label: l.actionCancel, onPressed: () => Navigator.of(context).maybePop()),
      ),
      const SizedBox(width: Space.m),
      Expanded(
        flex: 3,
        child: SheetButton(
          label: l.medsSave,
          icon: Icons.check_rounded,
          primary: true,
          enabled: widget.canSave,
          onPressed: widget.onSave,
          onDisabledTap: () {
            Fx.fire(Sfx.error);
            widget.onRejectedSave?.call();
          },
        ),
      ),
    ],
  );

  Widget _discardBar(L10n l) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      key: const ValueKey('discard'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: t.warning, size: 20),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${l.interactionDiscardTitle}  ', style: text.titleMedium),
                      TextSpan(text: l.interactionDiscardBody, style: text.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        Row(
          children: [
            Expanded(
              child: SheetButton(
                label: l.interactionDiscardConfirm,
                tone: t.danger,
                sfx: Sfx.delete,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: SheetButton(
                label: l.interactionKeepEditing,
                primary: true,
                onPressed: () => setState(() => _confirming = false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A row of chips (single choice).
class MedsChoiceRow<T> extends StatelessWidget {
  const MedsChoiceRow({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.icon,
    this.dense = true,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) label;
  final IconData? Function(T value)? icon;
  final ValueChanged<T> onSelected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Space.s,
      runSpacing: Space.s,
      children: [
        for (final v in values)
          KitChip(
            label: label(v),
            icon: icon?.call(v),
            selected: v == selected,
            dense: dense,
            onTap: () => onSelected(v),
          ),
      ],
    );
  }
}
