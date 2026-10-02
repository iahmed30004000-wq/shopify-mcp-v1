import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/adhkar_providers.dart';
import '../../data/dhikr_audio.dart';
import '../../data/dhikr_playback.dart';
import '../../domain/adhkar_models.dart';
import 'dhikr_text.dart';

/// What the reader's options sheet asked for.
enum AdhkarReaderAction { recount, restart, markDone, audio }

/// Reading options: text size (live preview of the current dhikr), virtue
/// and meaning switches, the recording of the current dhikr, recount,
/// restart, mark the set done.
Future<AdhkarReaderAction?> showAdhkarReaderOptions(
  BuildContext context, {
  required Dhikr current,
  required bool complete,
}) => showInteractionSheet<AdhkarReaderAction>(
  context,
  builder: (_) => _ReaderOptionsSheet(current: current, complete: complete),
);

class _ReaderOptionsSheet extends ConsumerStatefulWidget {
  const _ReaderOptionsSheet({required this.current, required this.complete});

  final Dhikr current;
  final bool complete;

  @override
  ConsumerState<_ReaderOptionsSheet> createState() => _ReaderOptionsSheetState();
}

class _ReaderOptionsSheetState extends ConsumerState<_ReaderOptionsSheet> {
  double? _scale;

  AdhkarReaderPrefs get _prefs => ref.read(adhkarReaderPrefsProvider).value ?? const AdhkarReaderPrefs();

  Future<void> _save(AdhkarReaderPrefs p) => ref.read(adhkarReaderPrefsWriterProvider)(p);

  void _step(double delta) {
    final next = ((_scale ?? _prefs.textScale) + delta).clamp(AdhkarReaderPrefs.minScale, AdhkarReaderPrefs.maxScale);
    setState(() => _scale = next);
    unawaited(_save(_prefs.copyWith(textScale: next)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final prefs = ref.watch(adhkarReaderPrefsProvider).value ?? const AdhkarReaderPrefs();
    final scale = _scale ?? prefs.textScale;
    void pick(AdhkarReaderAction a) => Navigator.of(context).pop(a);
    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          MadarSwitch(value: value, onChanged: onChanged, semanticLabel: label),
        ],
      ),
    );
    return InteractionSheetFrame(
      title: l.adhkarOptionsTitle,
      icon: Icons.tune_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.adhkarTextSize, style: text.titleSmall)),
              Text(fmt.formatPercent(scale), style: text.labelLarge!.copyWith(color: t.accent)),
            ],
          ),
          Row(
            children: [
              MadarButton.icon(
                icon: Icons.text_decrease_rounded,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.ghost,
                semanticLabel: l.adhkarTextSizeSmaller,
                onPressed: scale <= AdhkarReaderPrefs.minScale ? null : () => _step(-0.1),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: t.accent,
                    inactiveTrackColor: t.glassBorder,
                    thumbColor: t.accent,
                    overlayColor: t.accentSoft,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: scale,
                    min: AdhkarReaderPrefs.minScale,
                    max: AdhkarReaderPrefs.maxScale,
                    divisions: 10,
                    label: fmt.formatPercent(scale),
                    onChanged: (v) {
                      if ((v - scale).abs() > 0.01) Fx.fire(Sfx.countTick, volume: 0.5);
                      setState(() => _scale = v);
                    },
                    onChangeEnd: (v) => unawaited(_save(prefs.copyWith(textScale: v))),
                  ),
                ),
              ),
              MadarButton.icon(
                icon: Icons.text_increase_rounded,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.ghost,
                semanticLabel: l.adhkarTextSizeLarger,
                onPressed: scale >= AdhkarReaderPrefs.maxScale ? null : () => _step(0.1),
              ),
            ],
          ),
          GlassCard(
            glow: false,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l, vertical: Space.s),
            child: DhikrText(dhikr: widget.current, scale: scale, maxLines: 2),
          ),
          const SizedBox(height: Space.m),
          toggle(l.adhkarShowVirtue, prefs.showVirtue, (v) => unawaited(_save(prefs.copyWith(showVirtue: v)))),
          if (Localizations.localeOf(context).languageCode == 'en')
            toggle(
              l.adhkarShowTranslation,
              prefs.showTranslation,
              (v) => unawaited(_save(prefs.copyWith(showTranslation: v))),
            ),
          const MadarDivider(),
          SheetButton(
            label: l.adhkarAudioTitle,
            icon: Icons.graphic_eq_rounded,
            onPressed: () => pick(AdhkarReaderAction.audio),
          ),
          const SizedBox(height: Space.s),
          SheetButton(
            label: l.adhkarRecountCurrent,
            icon: Icons.replay_rounded,
            onPressed: () => pick(AdhkarReaderAction.recount),
          ),
          const SizedBox(height: Space.s),
          SheetButton(
            label: l.adhkarRestartSet,
            icon: Icons.restart_alt_rounded,
            onPressed: () => pick(AdhkarReaderAction.restart),
          ),
          if (!widget.complete) ...[
            const SizedBox(height: Space.s),
            SheetButton(
              label: l.adhkarMarkSetDone,
              icon: Icons.done_all_rounded,
              primary: true,
              sfx: null,
              onPressed: () => pick(AdhkarReaderAction.markDone),
            ),
          ],
        ],
      ),
    );
  }
}

/// A dhikr's recording: attach a file from the device (copied into the
/// app's private storage), play, replace or remove it (with undo).
Future<void> showDhikrAudioSheet(BuildContext context, {required Dhikr dhikr}) =>
    showInteractionSheet<void>(context, builder: (_) => DhikrAudioSheet(dhikr: dhikr));

class DhikrAudioSheet extends ConsumerStatefulWidget {
  const DhikrAudioSheet({super.key, required this.dhikr});

  final Dhikr dhikr;

  @override
  ConsumerState<DhikrAudioSheet> createState() => _DhikrAudioSheetState();
}

class _DhikrAudioSheetState extends ConsumerState<DhikrAudioSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _attach() async {
    final l = L10n.of(context);
    setState(() => _busy = true);
    try {
      final picked = await ref.read(dhikrAudioPickerProvider)();
      if (picked == null) return;
      ref.read(dhikrPlaybackProvider.notifier).stop();
      await ref.read(dhikrAudioStoreProvider).attach(widget.dhikr.id, picked);
      Fx.fire(Sfx.complete);
      if (mounted) setState(() => _error = null);
    } on DhikrAudioException catch (e) {
      Fx.fire(Sfx.error);
      if (mounted) {
        setState(
          () => _error = switch (e.problem) {
            DhikrAudioProblem.unsupported => l.adhkarAudioUnsupported,
            DhikrAudioProblem.tooLarge => l.adhkarAudioTooLarge,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l = L10n.of(context);
    ref.read(dhikrPlaybackProvider.notifier).stop();
    final undo = await ref.read(dhikrAudioStoreProvider).remove(widget.dhikr.id);
    Fx.fire(Sfx.delete);
    if (undo == null || !mounted) return;
    unawaited(showUndoToast(context, UndoableAction(label: l.adhkarAudioRemoved, undo: undo)));
  }

  Future<void> _toggle() async {
    final l = L10n.of(context);
    final ok = await ref.read(dhikrPlaybackProvider.notifier).toggle(widget.dhikr.id);
    if (!ok) {
      Fx.fire(Sfx.error);
      if (mounted) setState(() => _error = l.adhkarAudioUnavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final info = ref.watch(dhikrAudioInfoProvider).value?[widget.dhikr.id];
    final playing = ref.watch(dhikrPlaybackProvider) == widget.dhikr.id;
    return InteractionSheetFrame(
      title: l.adhkarAudioTitle,
      icon: Icons.graphic_eq_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            glow: false,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l, vertical: Space.s),
            child: DhikrText(dhikr: widget.dhikr, scale: 0.72, maxLines: 2),
          ),
          const SizedBox(height: Space.m),
          if (info == null)
            Text(l.adhkarAudioNone, style: text.bodyMedium!.copyWith(color: t.textSecondary))
          else
            GlassCard(
              glow: playing,
              glowColor: t.accentGlow,
              padding: const EdgeInsetsDirectional.all(Space.m),
              child: Row(
                children: [
                  MadarButton.icon(
                    icon: playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    variant: MadarButtonVariant.primary,
                    semanticLabel: playing ? l.adhkarAudioStop : l.adhkarAudioPlay,
                    onPressed: () => unawaited(_toggle()),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Text(
                      l.adhkarAudioFile(
                        fmt.isolate(info.originalName),
                        info.duration == null ? '—' : fmt.formatDuration(info.duration!, seconds: true),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: Space.s),
            Text(_error!, style: text.bodySmall!.copyWith(color: t.danger)),
          ],
          const SizedBox(height: Space.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, size: 16, color: t.textTertiary),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(l.adhkarAudioPolicy, style: text.bodySmall!.copyWith(color: t.textTertiary)),
              ),
            ],
          ),
        ],
      ),
      footer: Row(
        children: [
          if (info != null) ...[
            Expanded(
              child: SheetButton(
                label: l.adhkarAudioRemove,
                icon: Icons.delete_outline_rounded,
                tone: t.danger,
                sfx: null,
                onPressed: _busy ? null : () => unawaited(_remove()),
              ),
            ),
            const SizedBox(width: Space.s),
          ],
          Expanded(
            child: SheetButton(
              label: info == null ? l.adhkarAudioAttach : l.adhkarAudioReplace,
              icon: Icons.attach_file_rounded,
              primary: true,
              enabled: !_busy,
              onPressed: _busy ? null : () => unawaited(_attach()),
            ),
          ),
        ],
      ),
    );
  }
}
