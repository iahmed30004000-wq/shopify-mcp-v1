import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../application/adhan_providers.dart';
import '../data/adhan_audio.dart';
import '../data/muezzin_library.dart';
import '../domain/adhan_settings.dart';
import '../domain/adhan_sound.dart';

/// Picks the adhan sound of Fajr ([fajr]) or of the other four prayers:
/// Madar's tanbih tones, the recordings the user attached (rename / delete
/// with undo by long-press) or silence. A tap selects and previews; the
/// play button only previews. "Attach a recording" copies an audio file in.
Future<void> showMuezzinPicker(BuildContext context, {required bool fajr}) async {
  final container = ProviderScope.containerOf(context);
  await showInteractionSheet<void>(context, builder: (_) => _MuezzinPicker(fajr: fajr));
  unawaited(container.read(adhanAudioProvider).stop());
}

class _MuezzinPicker extends ConsumerStatefulWidget {
  const _MuezzinPicker({required this.fajr});

  final bool fajr;

  @override
  ConsumerState<_MuezzinPicker> createState() => _MuezzinPickerState();
}

class _MuezzinPickerState extends ConsumerState<_MuezzinPicker> {
  String? _note;
  bool _importing = false;

  AdhanSoundRef _current(AdhanSettings s) => widget.fajr ? s.fajrSound : s.sound;

  Future<void> _select(AdhanSoundRef ref0, AdhanSettings settings) async {
    final changed = _current(settings) != ref0;
    await ref
        .read(adhanSettingsProvider.notifier)
        .change((s) => widget.fajr ? s.copyWith(fajrSound: ref0) : s.copyWith(sound: ref0));
    Fx.fire(changed ? Sfx.toggleOn : Sfx.tap);
    await _preview(ref0, settings, force: true);
  }

  Future<void> _preview(AdhanSoundRef sound, AdhanSettings settings, {bool force = false}) async {
    final audio = ref.read(adhanAudioProvider);
    if (!force && audio.playing.value == sound) {
      await audio.stop();
      return;
    }
    final m = settings.muezzinById(sound.fileId);
    if (m != null && !m.playableInApp) {
      setState(() => _note = L10n.of(context).adhanMuezzinNoPreview);
      await audio.stop();
      return;
    }
    await audio.play(sound, muezzin: m);
  }

  Future<void> _attach() async {
    if (_importing) return;
    final l = L10n.of(context);
    setState(() {
      _importing = true;
      _note = null;
    });
    final result = await ref.read(muezzinLibraryProvider).pickAndImport();
    if (!mounted) return;
    final m = result.muezzin;
    if (m != null) {
      final sound = AdhanSoundRef.file(m.id);
      await ref
          .read(adhanSettingsProvider.notifier)
          .change((s) => (widget.fajr ? s.copyWith(fajrSound: sound) : s.copyWith(sound: sound)).withMuezzin(m));
      Fx.fire(Sfx.complete);
      if (mounted) setState(() => _note = l.adhanMuezzinAdded(m.name));
    } else if (result.error != MuezzinImportError.cancelled) {
      Fx.fire(Sfx.error);
      setState(() {
        _note = switch (result.error) {
          MuezzinImportError.unsupported => l.adhanMuezzinUnsupported,
          MuezzinImportError.tooLarge => l.adhanMuezzinTooLarge,
          _ => l.adhanMuezzinUnreadable,
        };
      });
    }
    if (mounted) setState(() => _importing = false);
  }

  Future<void> _rename(CustomMuezzin m) async {
    final l = L10n.of(context);
    final values = await showEditSheet(
      context,
      title: l.adhanMuezzinRenameTitle,
      icon: Icons.drive_file_rename_outline_rounded,
      fields: [FieldSpec.text('name', l.adhanMuezzinNameField, required: true, maxLength: 40, autofocus: true)],
      initial: {'name': m.name},
    );
    final name = (values?['name'] as String?)?.trim();
    if (name == null || name.isEmpty || name == m.name) return;
    await ref.read(adhanSettingsProvider.notifier).change((s) => s.withMuezzin(m.copyWith(name: name)));
  }

  Future<UndoableAction?> _delete(CustomMuezzin m) async {
    final l = L10n.of(context);
    final container = ProviderScope.containerOf(context);
    final controller = ref.read(adhanSettingsProvider.notifier);
    final before = await controller.change((s) => s);
    await controller.change((s) => s.withoutMuezzin(m.id));
    // The file goes once the undo window has passed and nothing uses it.
    Timer(const Duration(seconds: 20), () {
      final now = container.read(adhanSettingsProvider).value;
      if (now != null && now.muezzinById(m.id) == null) unawaited(container.read(muezzinLibraryProvider).delete(m));
    });
    return UndoableAction(
      label: l.adhanMuezzinDeleted(m.name),
      undo: () async {
        await controller.change((s) => s.withMuezzin(m).copyWith(fajrSound: before.fajrSound, sound: before.sound));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final texts = ref.watch(adhanTextsProvider);
    final settings = ref.watch(adhanSettingsProvider).value ?? const AdhanSettings();
    final audio = ref.watch(adhanAudioProvider);
    final current = _current(settings);
    final fmt = MadarFormatter.of(context);

    Widget option(AdhanSoundRef sound, {required String title, String? subtitle, CustomMuezzin? muezzin}) {
      final row = _SoundRow(
        selected: current == sound,
        title: title,
        subtitle: subtitle,
        icon: switch (sound.kind) {
          AdhanSoundKind.tone => Icons.notifications_active_outlined,
          AdhanSoundKind.file => Icons.record_voice_over_rounded,
          AdhanSoundKind.silent => Icons.vibration_rounded,
        },
        audio: audio,
        sound: sound,
        canPreview: sound.kind != AdhanSoundKind.silent && (muezzin == null || muezzin.playableInApp),
        onPreview: () => unawaited(_preview(sound, settings)),
        selectedLabel: l.adhanSelected,
        listenLabel: l.adhanListen,
        stopLabel: l.adhanListenStop,
      );
      if (muezzin == null) {
        return MadarPressable(
          onTap: () => unawaited(_select(sound, settings)),
          sfx: null,
          selected: current == sound,
          semanticLabel: title,
          child: row,
        );
      }
      return ActionableItem(
        key: ValueKey(muezzin.id),
        onTap: () => unawaited(_select(sound, settings)),
        swipeEnabled: false,
        semanticLabel: title,
        borderRadius: BorderRadius.circular(t.radiusM),
        actions: ItemActions(onEdit: () => _rename(muezzin), onDelete: () => _delete(muezzin)),
        child: row,
      );
    }

    Widget header(String title, String hint) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, Space.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall!.copyWith(color: t.gold)),
          const SizedBox(height: 2),
          Text(hint, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.4)),
        ],
      ),
    );

    return InteractionSheetFrame(
      title: widget.fajr ? l.adhanPickerTitleFajr : l.adhanPickerTitleOthers,
      subtitle: widget.fajr ? null : l.adhanMuezzinOthers,
      icon: Icons.record_voice_over_rounded,
      footer: SheetButton(label: l.adhanDone, primary: true, onPressed: () => Navigator.of(context).maybePop()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header(l.adhanPickerTones, l.adhanPickerTonesHint),
          for (final tone in TanbihTone.calls)
            option(AdhanSoundRef.tone(tone), title: texts.toneName(tone), subtitle: texts.toneDescription(tone)),
          option(const AdhanSoundRef.silent(), title: l.adhanSilent, subtitle: l.adhanSilentHint),
          header(l.adhanPickerYours, l.adhanPickerYoursHint),
          if (settings.muezzins.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xs, Space.xs, Space.s),
              child: Text(l.adhanPickerEmpty, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            ),
          for (final m in settings.muezzins)
            option(
              AdhanSoundRef.file(m.id),
              title: m.name,
              subtitle: m.length == null ? null : fmt.formatDuration(m.length!, seconds: true),
              muezzin: m,
            ),
          const SizedBox(height: Space.s),
          MadarButton(
            label: l.adhanPickerAttach,
            icon: Icons.attach_file_rounded,
            onPressed: _importing ? null : () => unawaited(_attach()),
            loading: _importing,
            variant: MadarButtonVariant.secondary,
            expand: true,
          ),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.medium),
            child: _note == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    key: ValueKey(_note),
                    padding: const EdgeInsetsDirectional.only(top: Space.m),
                    child: Text(_note!, style: text.bodySmall!.copyWith(color: t.accent)),
                  ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Space.l),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: t.textTertiary),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(l.adhanPickerNote, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.audio,
    required this.sound,
    required this.canPreview,
    required this.onPreview,
    required this.selectedLabel,
    required this.listenLabel,
    required this.stopLabel,
  });

  final bool selected;
  final String title;
  final String? subtitle;
  final IconData icon;
  final AdhanAudio audio;
  final AdhanSoundRef sound;
  final bool canPreview;
  final VoidCallback onPreview;
  final String selectedLabel;
  final String listenLabel;
  final String stopLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: context.motion(MadarMotion.medium),
      margin: const EdgeInsetsDirectional.only(bottom: Space.s),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.s, Space.m),
      decoration: BoxDecoration(
        color: selected ? t.accentSoft : t.glassFill,
        borderRadius: BorderRadius.circular(t.radiusM),
        border: Border.all(
          color: selected ? t.accent.withValues(alpha: 0.7) : t.glassBorder,
          width: selected ? 1.2 : 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? t.accent : t.textTertiary,
            size: 22,
          ),
          const SizedBox(width: Space.m),
          Icon(icon, size: 18, color: selected ? t.gold : t.textSecondary),
          const SizedBox(width: Space.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: text.titleMedium!.copyWith(height: 1.3)),
                if (subtitle != null)
                  Text(subtitle!, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.35)),
              ],
            ),
          ),
          if (canPreview)
            ValueListenableBuilder<AdhanSoundRef?>(
              valueListenable: audio.playing,
              builder: (context, playing, _) {
                final on = playing == sound;
                return MadarButton.icon(
                  icon: on ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  onPressed: onPreview,
                  semanticLabel: on ? stopLabel : listenLabel,
                  variant: on ? MadarButtonVariant.primary : MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                );
              },
            ),
        ],
      ),
    );
  }
}
