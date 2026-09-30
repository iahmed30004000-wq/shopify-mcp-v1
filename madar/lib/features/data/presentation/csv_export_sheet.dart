import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../data/data_providers.dart';
import '../data/data_repository.dart';
import '../domain/csv_export.dart';
import '../domain/export_range.dart';
import 'widgets/data_widgets.dart';
import 'widgets/file_panel.dart';

/// Opens the spreadsheet export: pick a table and a date range, then share
/// or save the CSV.
Future<void> showCsvExportSheet(BuildContext context, {DataCsvKind initialKind = DataCsvKind.labs}) =>
    showInteractionSheet<void>(context, builder: (_) => CsvExportSheet(initialKind: initialKind));

class CsvExportSheet extends ConsumerStatefulWidget {
  const CsvExportSheet({super.key, this.initialKind = DataCsvKind.labs});

  final DataCsvKind initialKind;

  @override
  ConsumerState<CsvExportSheet> createState() => _CsvExportSheetState();
}

class _CsvExportSheetState extends ConsumerState<CsvExportSheet> {
  late DataCsvKind _kind = widget.initialKind;
  ExportRangePreset _preset = ExportRangePreset.days90;
  ExportDateRange? _custom;
  Map<DataCsvKind, int>? _counts;
  DataFile? _file;
  bool _busy = false;
  bool _failed = false;

  DateTime get _now => ref.read(dataClockProvider)();
  ExportDateRange get _range => ExportDateRange.forPreset(_preset, _now, custom: _custom);

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final range = _range;
    try {
      final counts = await ref.read(dataExportRepositoryProvider).csvCounts(range: range);
      if (mounted && range == _range) setState(() => _counts = counts);
    } catch (_) {
      if (mounted) setState(() => _counts = const {});
    }
  }

  static String kindLabel(L10n l, DataCsvKind k) => switch (k) {
    DataCsvKind.labs => l.dataCsvLabs,
    DataCsvKind.transactions => l.dataCsvTransactions,
    DataCsvKind.pain => l.dataCsvPain,
    DataCsvKind.mood => l.dataCsvMood,
  };

  static IconData kindIcon(DataCsvKind k) => switch (k) {
    DataCsvKind.labs => Icons.biotech_rounded,
    DataCsvKind.transactions => Icons.account_balance_wallet_rounded,
    DataCsvKind.pain => Icons.healing_rounded,
    DataCsvKind.mood => Icons.mood_rounded,
  };

  Future<void> _pickCustom() async {
    final now = _now;
    final current = _custom;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: current?.from != null && current?.to != null
          ? DateTimeRange(start: current!.from!, end: current.to!)
          : DateTimeRange(start: DateTime(now.year, now.month - 1, now.day), end: ExportDateRange.dayOf(now)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _custom = ExportDateRange(from: picked.start, to: picked.end);
      _preset = ExportRangePreset.custom;
      _counts = null;
    });
    await _loadCounts();
  }

  Future<void> _build() async {
    if (_busy) return;
    final l = L10n.of(context);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final file = await ref.read(dataExportRepositoryProvider).csvExport(_kind, l, _now, range: _range);
      if (!mounted) return;
      Fx.fire(Sfx.sparkle);
      setState(() {
        _file = file;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      Fx.fire(Sfx.error);
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  String _rangeText(L10n l, MadarFormatter fmt) {
    final r = _range;
    if (r.isAll) return l.dataRangeAllTime;
    final from = r.from == null ? '…' : fmt.formatDate(r.from!);
    final to = r.to == null ? '…' : fmt.formatDate(r.to!);
    return l.dataRangeFromTo(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final file = _file;
    final count = _counts?[_kind];

    final Widget body = file != null
        ? DataFilePanel(file: file, subject: kindLabel(l, _kind))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.dataCsvWhat, style: text.labelLarge!.copyWith(color: t.textSecondary)),
              const SizedBox(height: Space.s),
              ChoicePills<DataCsvKind>.single(
                options: [
                  for (final k in DataCsvKind.values)
                    ChoiceOption(
                      value: k,
                      icon: kindIcon(k),
                      label: _counts == null ? kindLabel(l, k) : '${kindLabel(l, k)} · ${fmt.formatInt(_counts![k] ?? 0)}',
                    ),
                ],
                selected: _kind,
                onChanged: (k) {
                  if (k != null) setState(() => _kind = k);
                },
              ),
              const SizedBox(height: Space.l),
              Text(l.dataCsvWhen, style: text.labelLarge!.copyWith(color: t.textSecondary)),
              const SizedBox(height: Space.s),
              ChoicePills<ExportRangePreset>.single(
                options: [
                  ChoiceOption(value: ExportRangePreset.days30, label: fmt.localizeDigits(l.dataRange30)),
                  ChoiceOption(value: ExportRangePreset.days90, label: fmt.localizeDigits(l.dataRange90)),
                  ChoiceOption(value: ExportRangePreset.year, label: fmt.localizeDigits(l.dataRangeYear)),
                  ChoiceOption(value: ExportRangePreset.all, label: l.dataRangeAll),
                  ChoiceOption(value: ExportRangePreset.custom, label: l.dataRangeCustom, icon: Icons.date_range_rounded),
                ],
                selected: _preset,
                onChanged: (p) {
                  if (p == null) return;
                  if (p == ExportRangePreset.custom) {
                    _pickCustom();
                    return;
                  }
                  setState(() {
                    _preset = p;
                    _counts = null;
                  });
                  _loadCounts();
                },
              ),
              const SizedBox(height: Space.m),
              Row(
                children: [
                  Icon(Icons.event_rounded, size: 16, color: t.textTertiary),
                  const SizedBox(width: Space.xs),
                  Expanded(child: Text(_rangeText(l, fmt), style: text.bodySmall!.copyWith(color: t.textSecondary))),
                ],
              ),
              const SizedBox(height: Space.l),
              DataNote(text: l.dataCsvFormatNote, icon: Icons.table_rows_rounded),
              if (_failed) ...[
                const SizedBox(height: Space.s),
                DataNote(text: l.dataExportFailed, icon: Icons.error_outline_rounded, color: t.danger, dense: true),
              ],
            ],
          );

    return InteractionSheetFrame(
      title: l.dataCsvSheetTitle,
      subtitle: l.dataCsvSheetSubtitle,
      icon: Icons.table_chart_rounded,
      body: AnimatedSwitcher(
        duration: context.motion(MadarMotion.medium),
        child: KeyedSubtree(key: ValueKey(file == null), child: body),
      ),
      footer: file != null
          ? SheetButton(label: l.dataDoneAction, onPressed: () => Navigator.of(context).maybePop())
          : _busy
          ? Center(child: OrbitLoader(size: 32, color: t.accent))
          : SheetButton(
              label: count == null ? l.dataCsvCreate : fmt.localizeDigits(l.dataCsvCreateRows(count)),
              icon: Icons.file_download_done_rounded,
              primary: true,
              enabled: count != null && count > 0,
              onPressed: _build,
            ),
    );
  }
}
