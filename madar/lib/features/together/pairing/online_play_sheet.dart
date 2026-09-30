/// "Online play": the user's own Firebase project – entered here, validated,
/// kept in secure storage – the switch that turns online play on, the
/// one-time setup steps and the security rules to paste.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show FieldShell, kitInputDecoration;
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../data/together_providers.dart';
import '../domain/play_modes.dart';
import '../transport/online/online_config.dart';
import '../transport/online/rtdb.dart';
import '../transport/online/security_rules.dart';
import '../transport/pairing_state.dart';
import '../transport/together_net_providers.dart';
import 'pairing_texts.dart';

Future<void> showOnlinePlaySheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const OnlinePlaySheet());

/// A row for the Together settings (or the app's Settings): online play's
/// state; opens [showOnlinePlaySheet].
class OnlinePlayTile extends ConsumerWidget {
  const OnlinePlayTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final l = PairingTexts.of(context).l;
    final settings = ref.watch(togetherSettingsProvider).value ?? const TogetherSettings();
    final config = ref.watch(onlineConfigProvider).value;
    final state = config == null
        ? l.togetherNetOnlineNotSetUp
        : settings.onlineEnabled
        ? l.togetherNetOnlineOn
        : l.togetherNetOnlineOff;
    return GlassCard(
      key: const ValueKey('together-online-tile'),
      onTap: () => unawaited(showOnlinePlaySheet(context)),
      semanticLabel: '${l.togetherSettingsOnline}: $state',
      child: Row(
        children: [
          Icon(Icons.public_rounded, color: t.accent),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.togetherSettingsOnline, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(state, style: text.bodySmall?.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.textTertiary, textDirection: Directionality.of(context)),
        ],
      ),
    );
  }
}

class OnlinePlaySheet extends ConsumerStatefulWidget {
  const OnlinePlaySheet({super.key});

  @override
  ConsumerState<OnlinePlaySheet> createState() => _OnlinePlaySheetState();
}

class _OnlinePlaySheetState extends ConsumerState<OnlinePlaySheet> {
  final Map<OnlineConfigField, TextEditingController> _fields = {
    for (final f in OnlineConfigField.values) f: TextEditingController(),
  };
  bool _submitted = false;
  bool _busy = false;
  OnlineConfig? _saved;
  String? _status;
  bool _statusGood = true;

  @override
  void initState() {
    super.initState();
    for (final c in _fields.values) {
      c.addListener(_changed);
    }
    unawaited(_load());
  }

  void _changed() => setState(() {});

  Future<void> _load() async {
    final config = await ref.read(onlineConfigStoreProvider).read();
    if (!mounted || config == null) return;
    _fill(
      apiKey: config.apiKey,
      appId: config.appId,
      projectId: config.projectId,
      databaseUrl: config.databaseUrl,
      senderId: config.messagingSenderId,
    );
    setState(() => _saved = config);
  }

  void _fill({String? apiKey, String? appId, String? projectId, String? databaseUrl, String? senderId}) {
    void set(OnlineConfigField f, String? v) {
      if (v != null) _fields[f]!.text = v;
    }

    set(OnlineConfigField.apiKey, apiKey);
    set(OnlineConfigField.appId, appId);
    set(OnlineConfigField.projectId, projectId);
    set(OnlineConfigField.databaseUrl, databaseUrl);
    set(OnlineConfigField.senderId, senderId);
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(OnlineConfigField f) => _fields[f]!.text;

  Map<OnlineConfigField, OnlineConfigProblem> get _problems => OnlineConfig.validate(
    apiKey: _v(OnlineConfigField.apiKey),
    appId: _v(OnlineConfigField.appId),
    projectId: _v(OnlineConfigField.projectId),
    databaseUrl: _v(OnlineConfigField.databaseUrl),
    senderId: _v(OnlineConfigField.senderId),
  );

  OnlineConfig? get _draft => OnlineConfig.tryCreate(
    apiKey: _v(OnlineConfigField.apiKey),
    appId: _v(OnlineConfigField.appId),
    projectId: _v(OnlineConfigField.projectId),
    databaseUrl: _v(OnlineConfigField.databaseUrl),
    senderId: _v(OnlineConfigField.senderId),
  );

  void _say(String message, {bool good = true}) {
    if (!mounted) return;
    setState(() {
      _status = message;
      _statusGood = good;
    });
  }

  Future<void> _save() async {
    final l = PairingTexts.of(context).l;
    setState(() => _submitted = true);
    final config = _draft;
    if (config == null) {
      Fx.fire(Sfx.error);
      return;
    }
    await ref.read(onlineConfigStoreProvider).write(config);
    ref.invalidate(onlineConfigProvider);
    Fx.fire(Sfx.complete);
    setState(() => _saved = config);
    _say(l.togetherNetSaved);
  }

  Future<void> _remove() async {
    final l = PairingTexts.of(context).l;
    await ref.read(onlineConfigStoreProvider).clear();
    ref.invalidate(onlineConfigProvider);
    final repo = ref.read(togetherRepositoryProvider);
    final settings = await repo.settings();
    if (settings.onlineEnabled) await repo.saveSettings(settings.copyWith(onlineEnabled: false));
    for (final c in _fields.values) {
      c.clear();
    }
    setState(() {
      _saved = null;
      _submitted = false;
    });
    _say(l.togetherNetRemoved);
  }

  Future<void> _paste() async {
    final l = PairingTexts.of(context).l;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final draft = OnlineConfigDraft.parse(data?.text ?? '');
    if (draft == null) {
      Fx.fire(Sfx.error);
      _say(l.togetherNetPasteNothing, good: false);
      return;
    }
    _fill(
      apiKey: draft.apiKey,
      appId: draft.appId,
      projectId: draft.projectId,
      databaseUrl: draft.databaseUrl,
      senderId: draft.senderId,
    );
    Fx.fire(Sfx.drop);
    _say(l.togetherNetPasted);
  }

  Future<void> _copyRules() async {
    final l = PairingTexts.of(context).l;
    await Clipboard.setData(const ClipboardData(text: OnlineSecurityRules.json));
    _say(l.togetherNetRulesCopied);
  }

  Future<void> _test() async {
    final px = PairingTexts.of(context);
    setState(() => _submitted = true);
    final config = _draft;
    if (config == null) {
      Fx.fire(Sfx.error);
      return;
    }
    setState(() => _busy = true);
    _say(px.l.togetherNetTesting);
    try {
      final client = await ref.read(rtdbClientFactoryProvider)(config);
      try {
        await client.signIn();
        // Readable by any signed-in user under the online-play rules only.
        await client.read('rooms/000000/gm');
      } finally {
        await client.close();
      }
      Fx.fire(Sfx.complete);
      _say(px.l.togetherNetTestOk);
    } on RtdbException catch (e) {
      Fx.fire(Sfx.error);
      _say(
        px.failure(switch (e.kind) {
          RtdbErrorKind.permissionDenied => PairingFailure.rules,
          RtdbErrorKind.network => PairingFailure.network,
          RtdbErrorKind.setup => PairingFailure.setup,
          RtdbErrorKind.signIn => PairingFailure.signIn,
          RtdbErrorKind.unknown => PairingFailure.unknown,
        }),
        good: false,
      );
    } on Object {
      Fx.fire(Sfx.error);
      _say(px.l.togetherNetFailUnknown, good: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setEnabled(bool on) async {
    final l = PairingTexts.of(context).l;
    final repo = ref.read(togetherRepositoryProvider);
    if (on && await ref.read(onlineConfigStoreProvider).read() == null) {
      Fx.fire(Sfx.error);
      _say(l.togetherNetEnableNeedsConfig, good: false);
      return;
    }
    final settings = await repo.settings();
    await repo.saveSettings(settings.copyWith(onlineEnabled: on));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final px = PairingTexts.of(context);
    final l = px.l;
    final settings = ref.watch(togetherSettingsProvider).value ?? const TogetherSettings();
    final enabled = settings.onlineEnabled && _saved != null;
    final problems = _problems;

    Widget field(OnlineConfigField f, {bool optional = false, TextInputType? keyboard}) {
      final problem = problems[f];
      final show = problem != null && (_submitted || (_v(f).isNotEmpty && problem != OnlineConfigProblem.missing));
      return Padding(
        padding: const EdgeInsets.only(bottom: Space.m),
        child: FieldShell(
          label: px.field(f),
          optional: optional,
          error: show ? px.problem(problem) : null,
          child: TextField(
            key: ValueKey('together-online-${f.name}'),
            controller: _fields[f],
            textDirection: TextDirection.ltr,
            keyboardType: keyboard ?? TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            style: text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            decoration: kitInputDecoration(context, error: show),
          ),
        ),
      );
    }

    Widget step(int n, String s) => Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.gold, width: 1),
              color: t.gold.withValues(alpha: 0.1),
            ),
            child: Text(px.digits('$n'), style: text.labelSmall?.copyWith(color: t.gold)),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(s, style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );

    return InteractionSheetFrame(
      title: l.togetherSettingsOnline,
      icon: Icons.public_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.togetherNetOnlineIntroSheet, style: text.bodyMedium?.copyWith(color: t.textSecondary, height: 1.45)),
          const SizedBox(height: Space.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.togetherNetEnable, style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(l.togetherNetEnableHint, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: Space.m),
              MadarSwitch(
                key: const ValueKey('together-online-switch'),
                value: enabled,
                onChanged: (v) => unawaited(_setEnabled(v)),
                semanticLabel: l.togetherNetEnable,
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          GlassCard(
            padding: const EdgeInsets.all(Space.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.checklist_rounded, size: 18, color: t.accent),
                    const SizedBox(width: Space.s),
                    Text(l.togetherNetStepsTitle, style: text.titleSmall),
                  ],
                ),
                const SizedBox(height: Space.m),
                step(1, l.togetherNetStep1),
                step(2, l.togetherNetStep2),
                step(3, l.togetherNetStep3),
                step(4, l.togetherNetStep4),
                step(5, l.togetherNetStep5),
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    MadarButton(
                      key: const ValueKey('together-online-rules'),
                      label: l.togetherNetCopyRules,
                      icon: Icons.shield_rounded,
                      variant: MadarButtonVariant.secondary,
                      size: MadarButtonSize.small,
                      onPressed: () => unawaited(_copyRules()),
                    ),
                    MadarButton(
                      key: const ValueKey('together-online-paste'),
                      label: l.togetherNetPasteConfig,
                      icon: Icons.content_paste_rounded,
                      variant: MadarButtonVariant.secondary,
                      size: MadarButtonSize.small,
                      onPressed: () => unawaited(_paste()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          field(OnlineConfigField.apiKey),
          field(OnlineConfigField.appId),
          field(OnlineConfigField.projectId),
          field(OnlineConfigField.databaseUrl, keyboard: TextInputType.url),
          field(OnlineConfigField.senderId, optional: true, keyboard: TextInputType.number),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            child: _status == null
                ? const SizedBox.shrink()
                : Semantics(
                    key: ValueKey(_status),
                    liveRegion: true,
                    child: Row(
                      children: [
                        Icon(
                          _statusGood ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          size: 18,
                          color: _statusGood ? t.success : t.warning,
                        ),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: Text(
                            _status!,
                            style: text.bodySmall?.copyWith(color: _statusGood ? t.success : t.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: Space.m),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_rounded, size: 16, color: t.textTertiary),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(l.togetherNetStoredSecurely, style: text.bodySmall?.copyWith(color: t.textTertiary)),
              ),
            ],
          ),
          if (_saved != null) ...[
            const SizedBox(height: Space.l),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MadarButton(
                key: const ValueKey('together-online-remove'),
                label: l.togetherNetRemove,
                icon: Icons.delete_outline_rounded,
                variant: MadarButtonVariant.danger,
                size: MadarButtonSize.small,
                sfx: Sfx.delete,
                onPressed: () => unawaited(_remove()),
              ),
            ),
          ],
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              key: const ValueKey('together-online-test'),
              label: _busy ? l.togetherNetTesting : l.togetherNetTest,
              icon: Icons.wifi_tethering_rounded,
              enabled: !_busy,
              onPressed: () => unawaited(_test()),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: SheetButton(
              key: const ValueKey('together-online-save'),
              label: l.togetherNetSave,
              icon: Icons.save_rounded,
              primary: true,
              sfx: null,
              onPressed: () => unawaited(_save()),
            ),
          ),
        ],
      ),
    );
  }
}
