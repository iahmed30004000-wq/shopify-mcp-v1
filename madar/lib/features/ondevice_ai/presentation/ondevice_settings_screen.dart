/// Settings › «الذكاء على الجوال» (Part 15): what THIS phone can run and why,
/// the three ways with the active one marked, his choice (automatic or one
/// way), the optional model files, and the two promises: nothing leaves the
/// phone on the on-device ways, and the model never gives a religious ruling.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../data/model_download_manager.dart';
import '../data/ondevice_providers.dart';
import '../domain/capability_check.dart';
import '../domain/model_catalog.dart';
import '../domain/model_path.dart';
import 'ondevice_labels.dart';

/// The automatic choice plus the three ways, as the pills show them.
enum _Choice {
  auto(null),
  aicore(ModelPath.aicore),
  engine(ModelPath.inAppEngine),
  bridge(ModelPath.bridge);

  const _Choice(this.path);

  final ModelPath? path;

  static _Choice of(ModelPath? p) => values.firstWhere((c) => c.path == p);
}

class OnDeviceSettingsScreen extends ConsumerWidget {
  const OnDeviceSettingsScreen({super.key});

  static const Key phoneCard = ValueKey('ondevice-phone');
  static const Key reasonText = ValueKey('ondevice-reason');
  static const Key measureNote = ValueKey('ondevice-measure-note');
  static const Key recheckButton = ValueKey('ondevice-recheck');
  static const Key choiceRow = ValueKey('ondevice-choice');
  static const Key wifiSwitch = ValueKey('ondevice-wifi-only');
  static const Key privacyLocal = ValueKey('ondevice-privacy-local');
  static const Key privacyReligious = ValueKey('ondevice-privacy-religious');
  static Key pathTile(ModelPath p) => ValueKey('ondevice-path-${p.name}');
  static Key activeMark(ModelPath p) => ValueKey('ondevice-active-${p.name}');
  static Key modelCard(String id) => ValueKey('ondevice-model-$id');
  static Key downloadButton(String id) => ValueKey('ondevice-download-$id');
  static Key cancelButton(String id) => ValueKey('ondevice-cancel-$id');
  static Key removeButton(String id) => ValueKey('ondevice-remove-$id');
  static Key progressBar(String id) => ValueKey('ondevice-progress-$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final powerSaver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final choice = ref.watch(pathChoiceProvider);
    final caps = ref.watch(deviceCapabilitiesProvider).value;
    final prefs = ref.watch(onDevicePrefsProvider).value ?? const PathPrefs();
    final measured = ref.watch(onDeviceEngineMeasuredProvider);

    return MadarScaffold(
      title: l.ondeviceTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: !powerSaver,
      backdropSeed: 0.61,
      body: SettingsListView(
        children: [
          SettingsSection(
            title: l.ondeviceSectionPhone,
            seed: 0.05,
            children: [
              _PhoneCard(choice: choice.value, caps: caps, loading: choice.isLoading),
              if (!measured) SettingsNote(l.ondeviceNeedsMeasure, key: measureNote, icon: Icons.straighten_rounded),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.m),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MadarButton(
                    key: recheckButton,
                    label: l.ondeviceRecheck,
                    icon: Icons.refresh_rounded,
                    variant: MadarButtonVariant.secondary,
                    size: MadarButtonSize.small,
                    onPressed: () => ref.invalidate(deviceCapabilitiesProvider),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: l.ondeviceSectionPaths,
            seed: 0.12,
            children: [for (final p in ModelPath.values) _PathTile(path: p, choice: choice.value)],
          ),
          SettingsSection(
            title: l.ondeviceSectionChoice,
            seed: 0.2,
            children: [_ChoiceTile(selected: prefs.forced)],
          ),
          SettingsSection(
            title: l.ondeviceSectionModels,
            seed: 0.3,
            children: [
              SettingsNote(l.ondeviceModelsNote, icon: Icons.fingerprint_rounded),
              MergeSemantics(
                child: SettingsTile(
                  icon: Icons.wifi_rounded,
                  title: l.ondeviceWifiOnly,
                  subtitle: l.ondeviceWifiOnlyHint,
                  trailing: MadarSwitch(
                    key: wifiSwitch,
                    value: prefs.wifiOnly,
                    semanticLabel: l.ondeviceWifiOnly,
                    onChanged: (v) => ref.read(onDevicePrefsProvider.notifier).change((s) => s.copyWith(wifiOnly: v)),
                  ),
                ),
              ),
              for (final e in ref.watch(modelCatalogProvider)) _ModelTile(entry: e, wifiOnly: prefs.wifiOnly),
            ],
          ),
          SettingsSection(
            title: l.ondeviceSectionPrivacy,
            seed: 0.4,
            children: [
              SettingsNote(l.ondevicePrivacyLocal, key: privacyLocal, icon: Icons.lock_outline_rounded),
              SettingsNote(l.ondevicePrivacyReligious, key: privacyReligious, icon: Icons.menu_book_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

/// The chosen way, why, and the phone's numbers.
class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.choice, required this.caps, required this.loading});

  final PathChoice? choice;
  final DeviceCapabilities? caps;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final c = choice;
    if (c == null) {
      return SettingsTile(
        key: OnDeviceSettingsScreen.phoneCard,
        icon: Icons.smartphone_rounded,
        title: l.ondeviceChecking,
        subtitle: loading ? null : OnDeviceLabels.reason(l, const PathReason(PathReasonCode.bridgeOnly)),
      );
    }
    final blocker = c.reason.blocker;
    final blockerLine = blocker == null || c.reason.code == PathReasonCode.userForced
        ? null
        : OnDeviceLabels.block(l, fmt, blocker);
    final facts = <(String, String)>[];
    if (caps case final k?) {
      String gb(int? v) => v == null ? l.ondeviceFactUnknown : l.ondeviceFactGb(OnDeviceLabels.gb(fmt, v));
      facts
        ..add((
          l.ondeviceFactAndroid,
          k.sdkInt == null ? l.ondeviceFactUnknown : l.ondeviceFactAndroidValue(fmt.formatInt(k.sdkInt!, grouping: false)),
        ))
        ..add((
          l.ondeviceFactMemory,
          k.totalRamBytes == null
              ? l.ondeviceFactUnknown
              : l.ondeviceFactMemoryValue(
                  k.availableRamBytes == null ? l.ondeviceFactUnknown : OnDeviceLabels.gb(fmt, k.availableRamBytes!),
                  OnDeviceLabels.gb(fmt, k.totalRamBytes!),
                ),
        ))
        ..add((l.ondeviceFactStorage, gb(k.freeStorageBytes)))
        ..add((l.ondeviceFactHeat, OnDeviceLabels.heat(l, k.thermal)));
    }
    return Padding(
      key: OnDeviceSettingsScreen.phoneCard,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsIcon(
                c.path.runsOnPhone ? Icons.memory_rounded : Icons.swap_horiz_rounded,
                color: c.path.runsOnPhone ? t.success : t.gold,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(OnDeviceLabels.pathName(l, c.path), style: text.titleMedium!.copyWith(height: 1.3)),
                    Text(
                      OnDeviceLabels.reason(l, c.reason),
                      key: OnDeviceSettingsScreen.reasonText,
                      style: text.bodyMedium!.copyWith(height: 1.4),
                    ),
                    if (blockerLine != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: Space.xs),
                        child: Text(blockerLine, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.4)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (facts.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            for (final f in facts)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xxs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(f.$1, style: text.bodySmall!.copyWith(color: t.textTertiary))),
                    const SizedBox(width: Space.s),
                    Flexible(
                      child: Text(f.$2, textAlign: TextAlign.end, style: text.bodySmall!.copyWith(height: 1.35)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// One of the three ways: its name, what it is, and whether it is the one in
/// use, possible, or why it is not possible now.
class _PathTile extends StatelessWidget {
  const _PathTile({required this.path, required this.choice});

  final ModelPath path;
  final PathChoice? choice;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final c = choice;
    final active = c?.path == path;
    final block = c?.blocks[path];
    final status = c == null
        ? null
        : active
        ? l.ondevicePathActive
        : block == null
        ? l.ondevicePathPossible
        : '${l.ondevicePathNotNow}: ${OnDeviceLabels.block(l, fmt, block)}';
    return SettingsTile(
      key: OnDeviceSettingsScreen.pathTile(path),
      icon: switch (path) {
        ModelPath.aicore => Icons.android_rounded,
        ModelPath.inAppEngine => Icons.memory_rounded,
        ModelPath.bridge => Icons.swap_horiz_rounded,
      },
      iconColor: active ? t.success : null,
      title: OnDeviceLabels.pathName(l, path),
      subtitle: status == null ? OnDeviceLabels.pathHint(l, path) : '${OnDeviceLabels.pathHint(l, path)}\n$status',
      semanticLabel: active ? '${OnDeviceLabels.pathName(l, path)}, ${l.ondevicePathActive}' : null,
      trailing: active
          ? Icon(Icons.check_circle_rounded, key: OnDeviceSettingsScreen.activeMark(path), color: t.success)
          : null,
    );
  }
}

class _ChoiceTile extends ConsumerWidget {
  const _ChoiceTile({required this.selected});

  final ModelPath? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    return Column(
      key: OnDeviceSettingsScreen.choiceRow,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsTile(icon: Icons.tune_rounded, title: l.ondeviceSectionChoice, subtitle: l.ondeviceChoiceHint),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.l),
          child: ChoicePills<_Choice>.single(
            options: [for (final c in _Choice.values) ChoiceOption(value: c, label: OnDeviceLabels.pathShort(l, c.path))],
            selected: _Choice.of(selected),
            dense: true,
            onChanged: (v) {
              if (v == null) return;
              final path = v.path;
              ref
                  .read(onDevicePrefsProvider.notifier)
                  .change((s) => path == null ? s.copyWith(clearForced: true) : s.copyWith(forced: path));
            },
          ),
        ),
      ],
    );
  }
}

class _ModelTile extends ConsumerWidget {
  const _ModelTile({required this.entry, required this.wifiOnly});

  final ModelCatalogEntry entry;
  final bool wifiOnly;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ref.read(modelDownloadManagerProvider).start(entry, wifiOnly: wifiOnly);
    final refusal = result.refusal;
    if (refusal == null) return;
    final message = OnDeviceLabels.refusedStart(l, refusal);
    if (message != null) messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.ondeviceRemoveConfirmTitle),
        content: Text(l.ondeviceRemoveConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.actionCancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.ondeviceRemove)),
        ],
      ),
    );
    if (sure != true) return;
    await ref.read(modelDownloadManagerProvider).remove(entry);
    messenger?.showSnackBar(SnackBar(content: Text(l.ondeviceRemoved)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(modelInstallsProvider.select((m) => m[entry.id])) ?? ModelInstallState.none(entry.id);
    final size = entry.sizeBytes == null || entry.sizeBytes! <= 0
        ? l.ondeviceModelSizeUnknown
        : l.ondeviceModelSize(OnDeviceLabels.gb(fmt, entry.sizeBytes!));
    final line = OnDeviceLabels.installLine(l, fmt, state);
    final manager = ref.read(modelDownloadManagerProvider);
    final canStart = !entry.unverified && !state.isBusy && state.status != ModelInstallStatus.installed;

    return Column(
      key: OnDeviceSettingsScreen.modelCard(entry.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SettingsTile(
          icon: entry.kind == ModelKind.language ? Icons.psychology_alt_rounded : Icons.graphic_eq_rounded,
          title: BidiIsolate.ltr(entry.displayName),
          subtitle: '${OnDeviceLabels.kind(l, entry.kind)} · $size\n${l.ondeviceModelLicense(BidiIsolate.ltr(entry.license))}',
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l + 36 + Space.m, 0, Space.l, Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.unverified)
                Text(l.ondeviceModelUnverified, style: text.bodySmall!.copyWith(color: t.warning, height: 1.4)),
              if (line != null) Text(line, style: text.bodySmall!.copyWith(height: 1.4)),
              if (state.isBusy)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
                  child: LinearProgressIndicator(
                    key: OnDeviceSettingsScreen.progressBar(entry.id),
                    value: state.status == ModelInstallStatus.verifying ? null : state.fraction,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(height: Space.s),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.xs,
                children: [
                  if (state.status != ModelInstallStatus.installed && !state.isBusy)
                    MadarButton(
                      key: OnDeviceSettingsScreen.downloadButton(entry.id),
                      label: wifiOnly ? l.ondeviceDownloadWifi : l.ondeviceDownload,
                      icon: Icons.download_rounded,
                      size: MadarButtonSize.small,
                      onPressed: canStart ? () => _start(context, ref) : null,
                    ),
                  if (state.isBusy)
                    MadarButton(
                      key: OnDeviceSettingsScreen.cancelButton(entry.id),
                      label: l.actionCancel,
                      icon: Icons.close_rounded,
                      variant: MadarButtonVariant.secondary,
                      size: MadarButtonSize.small,
                      onPressed: () => manager.cancel(entry.id),
                    ),
                  if (state.status == ModelInstallStatus.installed ||
                      state.status == ModelInstallStatus.paused ||
                      state.status == ModelInstallStatus.failed)
                    MadarButton(
                      key: OnDeviceSettingsScreen.removeButton(entry.id),
                      label: l.ondeviceRemove,
                      icon: Icons.delete_outline_rounded,
                      variant: MadarButtonVariant.danger,
                      size: MadarButtonSize.small,
                      onPressed: () => _remove(context, ref),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
