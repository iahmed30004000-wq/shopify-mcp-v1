import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../data/ai_chat_providers.dart';
import '../data/conversation_store.dart';
import '../domain/ai_models.dart';
import '../domain/ai_settings.dart';
import 'ai_labels.dart';
import 'widgets/key_sheet.dart';
import 'widgets/model_sheet.dart';

/// Settings › AI: service, keys (masked, in secure storage), model, reply
/// length and temperature, plus the privacy promises and "delete all chats".
class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  static Key keyRow(AiProviderId p) => ValueKey('ai-settings-key-${p.name}');
  static const Key modelRow = ValueKey('ai-settings-model');
  static const Key temperatureSwitch = ValueKey('ai-settings-temperature-default');

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final store = ref.read(conversationStoreProvider);
    final removed = await store.deleteAll();
    if (removed.isEmpty || !context.mounted) return;
    Fx.fire(Sfx.delete);
    showUndoToast(context, UndoableAction(label: l.aiChatDeletedAll, undo: () => store.restore(removed)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(aiSettingsProvider).value ?? const AiSettings();
    final hints = ref.watch(aiKeyHintsProvider).value ?? const <AiProviderId, String?>{};
    final powerSaver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final ctrl = ref.read(aiSettingsProvider.notifier);
    final p = settings.provider;
    final temperature = settings.temperature;

    return MadarScaffold(
      title: l.aiChatSettingsTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: !powerSaver,
      backdropSeed: 0.47,
      body: SettingsListView(
        children: [
          StaggerIn(
            id: 'ai-settings',
            fade: false,
            children: [
              SettingsSection(
                title: l.aiChatSettingsServiceModel,
                seed: 0.1,
                children: [
                  SettingsChoiceTile<AiProviderId>(
                    icon: aiServiceIcon(p),
                    title: l.aiChatSettingsService,
                    subtitle: l.aiService(p),
                    options: [for (final s in AiProviderId.values) ChoiceOption(value: s, label: l.aiService(s))],
                    selected: p,
                    onChanged: (v) => ctrl.change((s) => s.copyWith(provider: v)),
                  ),
                  SettingsTile(
                    key: modelRow,
                    icon: Icons.memory_rounded,
                    title: l.aiChatSettingsModel,
                    // The id on its own line: it never breaks at its hyphens.
                    subtitle:
                        '${aiModelLabel(settings.model, displayName: settings.displayNameOf(p, settings.model))}'
                        '\n${BidiIsolate.ltr(settings.model)}',
                    navigates: true,
                    onTap: () => showModelPickerSheet(context),
                  ),
                ],
              ),
              SettingsSection(
                title: l.aiChatSettingsKeys,
                seed: 0.2,
                children: [
                  for (final s in AiProviderId.values)
                    SettingsTile(
                      key: keyRow(s),
                      icon: hints[s] != null ? Icons.lock_rounded : Icons.key_rounded,
                      iconColor: hints[s] != null ? t.success : t.gold,
                      title: l.aiChatKeyTitle(l.aiService(s)),
                      subtitle: hints[s] != null
                          ? l.aiChatKeySaved(BidiIsolate.ltr('••••${hints[s]}'))
                          : l.aiChatKeyNotSet,
                      navigates: true,
                      onTap: () => showAiKeySheet(context, s),
                    ),
                  SettingsNote(l.aiChatPrivacyKeys, icon: Icons.shield_moon_outlined),
                ],
              ),
              SettingsSection(
                title: l.aiChatSettingsReply,
                seed: 0.3,
                children: [
                  SettingsChoiceTile<int>(
                    icon: Icons.short_text_rounded,
                    title: l.aiChatMaxTokens,
                    subtitle: l.aiChatMaxTokensNote,
                    options: [
                      for (final n in AiSettings.maxTokenChoices) ChoiceOption(value: n, label: fmt.formatInt(n)),
                    ],
                    selected: AiSettings.maxTokenChoices.contains(settings.maxTokens)
                        ? settings.maxTokens
                        : AiSettings.defaultMaxTokens,
                    onChanged: (v) => ctrl.change((s) => s.copyWith(maxTokens: v)),
                  ),
                  SettingsTile(
                    icon: Icons.thermostat_rounded,
                    title: l.aiChatTemperature,
                    subtitle: l.aiChatTemperatureDefault,
                    trailing: MadarSwitch(
                      key: temperatureSwitch,
                      value: temperature == null,
                      semanticLabel: l.aiChatTemperatureDefault,
                      onChanged: (v) => ctrl.change((s) => s.copyWith(temperature: () => v ? null : 0.7)),
                    ),
                  ),
                  AnimatedSize(
                    duration: context.motion(MadarMotion.medium),
                    curve: MadarMotion.emphasized,
                    alignment: AlignmentDirectional.topCenter,
                    child: temperature == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.xs),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: temperature,
                                    divisions: 10,
                                    activeColor: t.accent,
                                    inactiveColor: t.glassBorder.withValues(alpha: 0.5),
                                    thumbColor: t.gold,
                                    semanticFormatterCallback: (v) => fmt.formatNumber(v, maxDecimals: 1),
                                    onChanged: (v) => ctrl.change((s) => s.copyWith(temperature: () => v)),
                                  ),
                                ),
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    fmt.formatNumber(temperature, decimals: 1),
                                    textAlign: TextAlign.end,
                                    style: text.labelLarge!.copyWith(color: t.accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  SettingsNote(l.aiChatTemperatureNote),
                ],
              ),
              SettingsSection(
                title: l.aiChatSettingsPrivacy,
                seed: 0.4,
                children: [
                  SettingsNote(l.aiChatPrivacyCalls, icon: Icons.wifi_off_rounded),
                  SettingsNote(
                    l.aiChatPrivacyHistory(fmt.formatInt(ConversationStore.maxConversations)),
                    icon: Icons.lock_outline_rounded,
                  ),
                  SettingsTile(
                    icon: Icons.delete_sweep_outlined,
                    iconColor: t.danger,
                    title: l.aiChatDeleteAll,
                    onTap: () => _deleteAll(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
