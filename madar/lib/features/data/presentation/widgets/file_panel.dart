import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/data_providers.dart';
import '../../data/data_repository.dart';
import 'data_widgets.dart';

/// How a file left Madar.
enum DataDelivery { shared, saved }

/// Icon for a file by extension.
IconData dataFileIcon(DataFile file) => switch (file.extension) {
  'csv' => Icons.table_chart_rounded,
  'md' => Icons.auto_awesome_rounded,
  'json' => Icons.data_object_rounded,
  _ => Icons.lock_rounded,
};

/// A ready file: its name, size and whether it is encrypted, with Share and
/// Save buttons. Sharing and saving only ever happen here, on the user's tap.
class DataFilePanel extends ConsumerStatefulWidget {
  const DataFilePanel({super.key, required this.file, this.subject, this.onDelivered, this.showActions = true});

  final DataFile file;

  /// Share-sheet subject line.
  final String? subject;
  final ValueChanged<DataDelivery>? onDelivered;

  /// False when the host renders its own buttons (see [DataFileActions]).
  final bool showActions;

  @override
  ConsumerState<DataFilePanel> createState() => _DataFilePanelState();
}

class _DataFilePanelState extends ConsumerState<DataFilePanel> {
  DataDelivery? _done;
  bool _failed = false;
  bool _busy = false;

  Future<void> _deliver(DataDelivery how) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final bridge = ref.read(dataFileBridgeProvider);
    bool ok;
    try {
      ok = how == DataDelivery.shared
          ? await bridge.share(widget.file, subject: widget.subject)
          : await bridge.save(widget.file);
    } catch (_) {
      ok = false;
      if (mounted) setState(() => _failed = true);
      Fx.fire(Sfx.error);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _done = how;
    });
    if (ok) {
      Fx.fire(Sfx.complete);
      widget.onDelivered?.call(how);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final f = widget.file;
    final meta = [
      formatDataSize(l, fmt, f.size),
      if (f.records != null) recordsText(l, fmt, f.records!),
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsetsDirectional.all(Space.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusM),
            color: t.space0.withValues(alpha: t.isDark ? 0.3 : 0.45),
            border: Border.all(color: t.glassBorder.withValues(alpha: 0.6), width: 0.8),
          ),
          child: Row(
            children: [
              DataIconBadge(dataFileIcon(f), color: f.encrypted ? t.success : t.accent, size: 44),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      BidiIsolate.ltr(f.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall!.copyWith(color: t.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(meta, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        DataNote(
          text: f.encrypted ? l.dataFileEncryptedNote : l.dataFilePlainNote,
          icon: f.encrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
          color: f.encrypted ? t.success : t.warning,
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.emphasized,
          alignment: AlignmentDirectional.topCenter,
          child: _done == null && !_failed
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(top: Space.s),
                  child: _failed
                      ? DataNote(text: l.dataFileSendFailed, icon: Icons.error_outline_rounded, color: t.danger, dense: true)
                      : DataNote(
                          text: _done == DataDelivery.shared ? l.dataFileShared : l.dataFileSaved,
                          icon: Icons.check_circle_rounded,
                          color: t.success,
                          dense: true,
                        ),
                ),
        ),
        if (widget.showActions) ...[
          const SizedBox(height: Space.l),
          Row(
            children: [
              Expanded(
                child: SheetButton(
                  label: l.dataSaveAction,
                  icon: Icons.save_alt_rounded,
                  enabled: !_busy,
                  onPressed: () => _deliver(DataDelivery.saved),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: SheetButton(
                  label: l.dataShareAction,
                  icon: Icons.ios_share_rounded,
                  primary: true,
                  enabled: !_busy,
                  onPressed: () => _deliver(DataDelivery.shared),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Opens a sheet presenting a ready [file] (share / save / done).
Future<void> showDataFileSheet(
  BuildContext context, {
  required DataFile file,
  String? title,
  String? subject,
  ValueChanged<DataDelivery>? onDelivered,
}) {
  return showInteractionSheet<void>(
    context,
    builder: (context) {
      final l = L10n.of(context);
      return InteractionSheetFrame(
        title: title ?? l.dataFileReadyTitle,
        subtitle: l.dataFileReadySubtitle,
        icon: dataFileIcon(file),
        body: DataFilePanel(file: file, subject: subject, onDelivered: onDelivered),
      );
    },
  );
}
