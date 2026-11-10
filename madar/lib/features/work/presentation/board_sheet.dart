import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show SwatchPicker, kitInputDecoration;
import '../../../core/sound/sound_api.dart';
import '../data/work_models.dart';
import 'widgets/work_widgets.dart';
import 'work_labels.dart';

/// What the board editor returns.
@immutable
class BoardDraft {
  const BoardDraft({required this.name, this.country, this.color});

  final String name;

  /// ISO code of a listed country, or the label as typed.
  final String? country;
  final int? color;
}

/// Creates or edits a board: name, country / business label and colour.
Future<BoardDraft?> showBoardSheet(BuildContext context, {WorkBoard? board}) =>
    showInteractionSheet<BoardDraft>(context, builder: (_) => BoardSheet(board: board));

class BoardSheet extends StatefulWidget {
  const BoardSheet({super.key, this.board});

  final WorkBoard? board;

  @override
  State<BoardSheet> createState() => _BoardSheetState();
}

class _BoardSheetState extends State<BoardSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.board?.name ?? '');
  late final TextEditingController _label = TextEditingController(
    text: _isCode(widget.board?.country) ? '' : (widget.board?.country ?? ''),
  );
  late String? _code = _isCode(widget.board?.country) ? widget.board!.country!.toUpperCase() : null;
  late int? _color = widget.board?.color ?? CuratedPalette.colors.first.toARGB32();
  bool _tried = false;

  static bool _isCode(String? s) => s != null && kWorkCountries.contains(s.trim().toUpperCase());

  @override
  void dispose() {
    _name.dispose();
    _label.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _tried = true);
      Fx.fire(Sfx.error);
      return;
    }
    final label = _label.text.trim();
    Navigator.of(context).pop(BoardDraft(name: name, country: _code ?? (label.isEmpty ? null : label), color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final t = context.tokens;
    final editing = widget.board != null;
    final nameError = _tried && _name.text.trim().isEmpty;
    return InteractionSheetFrame(
      title: editing ? l.workEditBoard : l.workNewBoard,
      icon: Icons.view_kanban_rounded,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(label: l.actionCancel, onPressed: () => Navigator.of(context).maybePop(), sfx: Sfx.sheetClose),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            flex: 2,
            child: SheetButton(
              label: editing ? l.workSave : l.workCreate,
              primary: true,
              icon: Icons.check_rounded,
              onPressed: _save,
              sfx: Sfx.complete,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetSectionLabel(l.workBoardName, icon: Icons.title_rounded),
          TextField(
            controller: _name,
            autofocus: !editing,
            maxLength: 60,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: kitInputDecoration(context, hint: l.workBoardNameHint, error: nameError),
          ),
          if (nameError)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.xs, start: Space.xs),
              child: Text(l.fieldRequired, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.danger)),
            ),
          SheetSectionLabel(l.workBoardCountry, icon: Icons.flag_rounded),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final code in kWorkCountries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Space.s),
                    child: MadarChip(
                      label: texts.countryName(code)!,
                      selected: _code == code,
                      dense: true,
                      onSelected: (on) => setState(() {
                        _code = on ? code : null;
                        if (on) _label.clear();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.s),
          TextField(
            controller: _label,
            maxLength: 40,
            onChanged: (v) => setState(() {
              if (v.trim().isNotEmpty) _code = null;
            }),
            decoration: kitInputDecoration(context, hint: l.workBoardCountryHint),
          ),
          SheetSectionLabel(l.workBoardColor, icon: Icons.palette_rounded),
          SwatchPicker(
            colors: CuratedPalette.colors,
            value: _color,
            onChanged: (c) => setState(() => _color = c),
          ),
        ],
      ),
    );
  }
}
