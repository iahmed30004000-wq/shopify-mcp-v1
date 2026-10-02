import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../../import/import_screen.dart';
import '../data/backup_service.dart';
import '../data/data_providers.dart';
import '../data/file_bridge.dart';
import 'backup_sheet.dart';
import 'csv_export_sheet.dart';
import 'export_preview_sheet.dart';
import 'restore_flow.dart';
import 'widgets/data_widgets.dart';
import 'widgets/file_panel.dart';

/// When a backup last left the phone (null = never).
final lastBackupAtProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  final raw = await ref.watch(repositoriesProvider).keyValues.getJson(lastBackupKey);
  return raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
});

/// Records in the database right now.
final dataRecordCountProvider = FutureProvider.autoDispose<int>(
  (ref) async => (await ref.watch(backupServiceProvider).currentCounts()).values.fold<int>(0, (a, b) => a + b),
);

/// "Your data": encrypted backup and restore, exports (AI-ready summary,
/// CSV, full JSON) and the prototype import – everything that moves data in
/// or out of Madar, always on the user's explicit action.
class DataCentreScreen extends ConsumerStatefulWidget {
  const DataCentreScreen({super.key, this.onOpenImport, this.onOpenRestore, this.onRestored});

  /// Opens the prototype import (defaults to pushing [ImportScreen]).
  final VoidCallback? onOpenImport;

  /// Opens the restore flow (defaults to pushing [RestoreFlow]).
  final VoidCallback? onOpenRestore;

  /// Forwarded to the default [RestoreFlow].
  final ValueChanged<RestoreResult>? onRestored;

  @override
  ConsumerState<DataCentreScreen> createState() => _DataCentreScreenState();
}

class _DataCentreScreenState extends ConsumerState<DataCentreScreen> {
  bool _jsonBusy = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(dataFileBridgeProvider) is PlatformDataFileBridge) PlatformDataFileBridge.cleanShareCache();
  }

  void _refresh() {
    ref.invalidate(lastBackupAtProvider);
    ref.invalidate(dataRecordCountProvider);
    ref.invalidate(safetyCopiesProvider);
  }

  Future<void> _backup() async {
    await showBackupSheet(context);
    if (mounted) _refresh();
  }

  Future<void> _restore() async {
    final open = widget.onOpenRestore;
    if (open != null) {
      open();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RestoreFlow(onRestored: widget.onRestored)),
    );
    if (mounted) _refresh();
  }

  void _import() {
    final open = widget.onOpenImport;
    if (open != null) {
      open();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ImportScreen()));
  }

  Future<void> _json() async {
    if (_jsonBusy) return;
    final l = L10n.of(context);
    setState(() => _jsonBusy = true);
    try {
      final file = await ref.read(dataExportRepositoryProvider).jsonExport(ref.read(dataClockProvider)());
      if (!mounted) return;
      setState(() => _jsonBusy = false);
      await showDataFileSheet(context, file: file, subject: l.dataExportJsonTitle);
    } catch (_) {
      Fx.fire(Sfx.error);
      if (mounted) setState(() => _jsonBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final lastBackup = ref.watch(lastBackupAtProvider).value;
    final records = ref.watch(dataRecordCountProvider).value;
    final copies = ref.watch(safetyCopiesProvider).value ?? const <SafetyCopy>[];
    final now = ref.watch(dataClockProvider)();

    String lastBackupText() {
      if (lastBackup == null) return l.dataLastBackupNever;
      final days = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastBackup.year, lastBackup.month, lastBackup.day))
          .inDays;
      return days <= 0 ? l.dataLastBackupToday : fmt.localizeDigits(l.dataLastBackupDaysAgo(days));
    }

    final children = <Widget>[
      // ------------------------------------------------------------ hero --
      GlassPanel(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.xl, Space.xl, Space.l),
        child: Column(
          children: [
            const DataEmblem(icon: Icons.shield_rounded, size: 92),
            const SizedBox(height: Space.l),
            Text(l.dataHeroTitle, textAlign: TextAlign.center, style: text.headlineSmall!.copyWith(color: t.textPrimary)),
            const SizedBox(height: Space.s),
            Text(
              l.dataHeroBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.55),
            ),
            const SizedBox(height: Space.l),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: l.dataStatRecords,
                    value: records == null ? '…' : fmt.formatInt(records),
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: StatTile(
                    label: l.dataStatLastBackup,
                    value: lastBackupText(),
                    icon: Icons.history_rounded,
                    color: lastBackup == null ? t.warning : t.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      // ---------------------------------------------------------- backup --
      SectionHeader(
        title: l.dataBackupSection,
        subtitle: l.dataBackupSectionHint,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
      ),
      GlassPanel(
        padding: const EdgeInsetsDirectional.all(Space.l),
        seed: 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardHeading(icon: Icons.lock_rounded, color: t.success, title: l.dataBackupCreateTitle, body: l.dataBackupCreateBody),
            const SizedBox(height: Space.l),
            MadarButton(
              label: l.dataBackupCreateAction,
              icon: Icons.lock_rounded,
              expand: true,
              sfx: Sfx.sheetOpen,
              onPressed: _backup,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.l),
              child: Divider(height: 1, thickness: 0.6, color: t.glassBorder.withValues(alpha: 0.35)),
            ),
            _CardHeading(icon: Icons.settings_backup_restore_rounded, title: l.dataRestoreTitle, body: l.dataRestoreBody),
            const SizedBox(height: Space.l),
            MadarButton(
              label: l.dataRestoreAction,
              icon: Icons.file_open_rounded,
              variant: MadarButtonVariant.secondary,
              expand: true,
              sfx: Sfx.navigate,
              onPressed: _restore,
            ),
            if (copies.isNotEmpty) ...[
              const SizedBox(height: Space.m),
              DataNote(
                text: fmt.localizeDigits(
                  l.dataSafetyCopiesLine(copies.length, fmt.formatDate(copies.first.createdAt.toLocal())),
                ),
                icon: Icons.history_rounded,
                color: t.gold,
                dense: true,
              ),
            ],
          ],
        ),
      ),

      // ---------------------------------------------------------- export --
      SectionHeader(
        title: l.dataExportSection,
        subtitle: l.dataExportSectionHint,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
      ),
      DataGroup(
        seed: 2,
        children: [
          DataTile(
            icon: Icons.auto_awesome_rounded,
            iconColor: t.gold,
            title: l.dataExportSummaryTitle,
            subtitle: l.dataExportSummaryBody,
            onTap: () => showExportPreviewSheet(context),
          ),
          DataTile(
            icon: Icons.table_chart_rounded,
            title: l.dataExportCsvTitle,
            subtitle: l.dataExportCsvBody,
            onTap: () => showCsvExportSheet(context),
          ),
          DataTile(
            icon: Icons.data_object_rounded,
            iconColor: t.secondary,
            title: l.dataExportJsonTitle,
            subtitle: l.dataExportJsonBody,
            busy: _jsonBusy,
            onTap: _json,
          ),
        ],
      ),
      const SizedBox(height: Space.m),
      DataNote(text: l.dataExportPlainWarning, icon: Icons.lock_open_rounded, color: t.warning),

      // ---------------------------------------------------------- import --
      SectionHeader(
        title: l.dataImportSection,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
      ),
      DataGroup(
        seed: 3,
        children: [
          DataTile(icon: Icons.move_to_inbox_rounded, title: l.dataImportTitle, subtitle: l.dataImportBody, onTap: _import),
        ],
      ),
      const SizedBox(height: Space.l),
      Center(
        child: Text(
          l.dataFooter,
          textAlign: TextAlign.center,
          style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.5),
        ),
      ),
    ];

    return MadarScaffold(
      title: l.dataCentreTitle,
      body: EntranceChoreo(
        id: 'data-centre',
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxl),
          children: [for (var i = 0; i < children.length; i++) StaggerItem(index: i, child: children[i])],
        ),
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.title, required this.body, this.color});

  final IconData icon;
  final String title;
  final String body;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DataIconBadge(icon, color: color),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium!.copyWith(color: t.textPrimary)),
              const SizedBox(height: Space.xxs),
              Text(body, style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.5)),
            ],
          ),
        ),
      ],
    );
  }
}
