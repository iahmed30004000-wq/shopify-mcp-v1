import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/quran/quran_catalog.dart';
import '../../../core/sound/sound_api.dart';
import 'wird_labels.dart';

/// Picks a surah (search by Arabic or English name, or number); returns its
/// number or null.
Future<int?> showSurahPicker(BuildContext context, {required QuranCatalog catalog, int? selected}) =>
    showInteractionSheet<int>(
      context,
      builder: (_) => _SurahPicker(catalog: catalog, selected: selected),
    );

/// Folds Arabic letter variants and strips marks for search (أ/إ/آ/ٱ → ا,
/// ة → ه, ى → ي), and maps any digits to Western.
String surahSearchKey(String s) {
  final b = StringBuffer();
  for (final r in Digits.toWestern(s).toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    if (RegExp('[ً-ٰٟـ\'\\-]').hasMatch(ch)) continue;
    b.write(switch (ch) {
      'أ' || 'إ' || 'آ' || 'ٱ' => 'ا',
      'ة' => 'ه',
      'ى' => 'ي',
      _ => ch,
    });
  }
  return b.toString().replaceAll(' ', '');
}

class _SurahPicker extends StatefulWidget {
  const _SurahPicker({required this.catalog, this.selected});

  final QuranCatalog catalog;
  final int? selected;

  @override
  State<_SurahPicker> createState() => _SurahPickerState();
}

class _SurahPickerState extends State<_SurahPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final texts = WirdTexts(l, fmt, widget.catalog);
    final q = surahSearchKey(_query.trim());
    final matches = [
      for (var s = 1; s <= widget.catalog.surahCount; s++)
        if (q.isEmpty ||
            '$s' == q ||
            surahSearchKey(widget.catalog.surahName(s, arabic: true)).contains(q) ||
            surahSearchKey(widget.catalog.surahName(s, arabic: false)).contains(q))
          s,
    ];
    return InteractionSheetFrame(
      title: l.wirdChooseSurah,
      icon: Icons.menu_book_rounded,
      toolbar: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, Space.s),
        child: TextField(
          autofocus: false,
          onChanged: (v) => setState(() => _query = v),
          decoration: kitInputDecoration(
            context,
            hint: l.wirdSearchSurah,
          ).copyWith(prefixIcon: Icon(Icons.search_rounded, color: t.textSecondary)),
        ),
      ),
      body: Column(
        children: [
          for (final s in matches)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
              child: MadarPressable(
                onTap: () => Navigator.of(context).pop(s),
                sfx: Sfx.tap,
                selected: s == widget.selected,
                semanticLabel: '${texts.number(s)} ${texts.surah(s)}',
                child: Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.m, Space.s),
                  decoration: BoxDecoration(
                    color: s == widget.selected ? t.accentSoft : null,
                    borderRadius: BorderRadius.circular(t.radiusM),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            IslamicStar(size: 34, filled: false, color: t.brass),
                            Text(texts.number(s), style: text.labelSmall!.copyWith(color: t.textPrimary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: Space.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.catalog.surahName(s, arabic: true), style: text.titleMedium),
                            Text(
                              '${widget.catalog.surahName(s, arabic: false)}${l.wirdSep}'
                              '${fmt.localizeDigits(l.wirdUnitAyat(widget.catalog.ayahCount(s)))}',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
