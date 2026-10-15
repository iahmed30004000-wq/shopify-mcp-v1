/// In-app AI chat with the user's own Anthropic or OpenAI key.
///
/// * Keys live only in encrypted secure storage ([AiKeyStore]); the app
///   shows their last four characters, nothing else. Each key goes only to
///   its own service, over TLS, to api.anthropic.com / api.openai.com
///   ([AiHostPolicy]).
/// * Nothing reaches the network at all until the owner turns the chat's
///   own switch on (`AiSettings.outsideAllowed`, Settings › AI, off on a
///   fresh install): every request passes through [AiOutsideGate].
/// * A call happens only on an explicit tap (Send, Regenerate, Try again,
///   Test key, Refresh models) – never in the background.
/// * The first Send of a conversation opens the summary preview
///   (`showExportPreviewSheet` in select mode) so the user sees and trims
///   exactly what is shared; after that the "will send" strip above the
///   field always shows the sections, message count and approximate size,
///   and "What will be sent" shows the exact request.
/// * His health, his medication, his food and his family never leave the
///   phone through the chat – not even with the switch on and nothing
///   trimmed in the preview. The summary the chat builds has no health,
///   family or body section at all (`ChatSummaryScope`, built with
///   `forChat: true`), and [ChatContextFilter] cuts them again where the
///   request's text is assembled. The file round trip (`ai_bridge`) is
///   his own and unaffected: there he hands the file over himself.
/// * Conversations are stored encrypted in the database (`key_values`,
///   bounded).
///
/// Screens to route: [AiChatScreen], [AiChatListScreen], [AiSettingsScreen].
/// Hub entry points: [AskAiEntry] (card) and [AskAiButton] (app bar).
library;

export 'data/ai_chat_providers.dart'
    show
        AiContextPicker,
        AiKeyHintsController,
        AiProviderRegistry,
        AiSettingsController,
        aiClockProvider,
        aiContextPickerProvider,
        aiIdProvider,
        aiKeyHintsProvider,
        aiKeyStoreProvider,
        aiOutsideAllowedProvider,
        aiProviderRegistryProvider,
        aiSecretStoreProvider,
        aiSettingsProvider,
        aiTransportProvider,
        conversationIndexProvider,
        conversationStoreProvider;
export 'data/ai_provider.dart' show AiProvider, HttpAiProvider;
export 'data/anthropic_provider.dart' show AnthropicProvider;
export 'data/conversation_store.dart' show ConversationStore;
export 'data/key_store.dart' show AiKeyProblem, AiKeyStore;
export 'data/openai_provider.dart' show OpenAiProvider;
export 'data/transport.dart'
    show
        AiCancelToken,
        AiCancelledException,
        AiHostNotAllowedException,
        AiHostPolicy,
        AiHttpRequest,
        AiHttpResponse,
        AiInvalidHeaderException,
        AiOutsideGate,
        AiOutsideOffException,
        AiTransport,
        IoAiTransport;
export 'domain/ai_models.dart';
export 'domain/ai_settings.dart';
export 'domain/context_filter.dart' show ChatContextFilter;
export 'domain/conversation.dart';
export 'domain/payload.dart';
export 'presentation/ai_chat_list_screen.dart' show AiChatListScreen;
export 'presentation/ai_chat_screen.dart' show AiChatScreen;
export 'presentation/ai_settings_screen.dart' show AiSettingsScreen;
export 'presentation/ask_ai_entry.dart' show AskAiButton, AskAiEntry, openAskAi;
export 'presentation/widgets/off_card.dart' show AiOffCard, AiOffStrip;
