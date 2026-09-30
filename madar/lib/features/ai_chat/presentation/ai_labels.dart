import 'package:flutter/material.dart';

import '../../../core/i18n/gen/app_localizations.dart';
import '../../data/data.dart' show SummarySectionId;
import '../domain/ai_models.dart';

/// Localised names and messages of the AI chat.
extension AiChatLabels on L10n {
  String aiService(AiProviderId p) => switch (p) {
    AiProviderId.anthropic => aiChatServiceAnthropic,
    AiProviderId.openai => aiChatServiceOpenai,
  };

  /// A clear, actionable message for [kind].
  String aiError(AiErrorKind kind, {required AiProviderId provider, required String model}) {
    final service = aiService(provider);
    return switch (kind) {
      AiErrorKind.noKey => aiChatErrorNoKey(service),
      AiErrorKind.badKey => aiChatErrorBadKey(service),
      AiErrorKind.forbidden => aiChatErrorForbidden,
      AiErrorKind.rateLimited => aiChatErrorRateLimited,
      AiErrorKind.quotaExceeded => aiChatErrorQuota(service),
      AiErrorKind.overloaded => aiChatErrorOverloaded(service),
      AiErrorKind.serverError => aiChatErrorServer(service),
      AiErrorKind.modelNotFound => aiChatErrorModelNotFound(model),
      AiErrorKind.temperatureUnsupported => aiChatErrorTemperature,
      AiErrorKind.contextTooLong => aiChatErrorContextTooLong,
      AiErrorKind.badRequest => aiChatErrorBadRequest(service),
      AiErrorKind.network => aiChatErrorNetwork,
      AiErrorKind.timeout => aiChatErrorTimeout,
      AiErrorKind.badResponse => aiChatErrorBadResponse,
      AiErrorKind.unknown => aiChatErrorUnknown,
    };
  }

  /// The localised summary section titles (as the summary builder writes
  /// them), to recognise the sections of an approved summary.
  Map<SummarySectionId, String> summaryTitles() => {
    SummarySectionId.profile: dataSumProfile,
    SummarySectionId.faith: dataSumFaith,
    SummarySectionId.health: dataSumHealth,
    SummarySectionId.money: dataSumMoney,
    SummarySectionId.family: dataSumFamily,
    SummarySectionId.work: dataSumWork,
    SummarySectionId.growth: dataSumGrowth,
    SummarySectionId.body: dataSumBody,
    SummarySectionId.travel: dataSumTravel,
    SummarySectionId.custom: dataSumCustom,
  };
}

/// Errors that the settings screen fixes (key, model, temperature).
bool aiErrorWantsSettings(AiErrorKind kind) => switch (kind) {
  AiErrorKind.noKey ||
  AiErrorKind.badKey ||
  AiErrorKind.forbidden ||
  AiErrorKind.modelNotFound ||
  AiErrorKind.temperatureUnsupported ||
  AiErrorKind.quotaExceeded => true,
  _ => false,
};

IconData summarySectionIcon(SummarySectionId? id) => switch (id) {
  SummarySectionId.profile => Icons.person_outline_rounded,
  SummarySectionId.faith => Icons.mosque_outlined,
  SummarySectionId.health => Icons.favorite_border_rounded,
  SummarySectionId.money => Icons.account_balance_wallet_outlined,
  SummarySectionId.family => Icons.diversity_3_rounded,
  SummarySectionId.work => Icons.work_outline_rounded,
  SummarySectionId.growth => Icons.spa_outlined,
  SummarySectionId.body => Icons.fitness_center_rounded,
  SummarySectionId.travel => Icons.flight_takeoff_rounded,
  SummarySectionId.custom => Icons.dashboard_customize_outlined,
  null => Icons.notes_rounded,
};

IconData aiServiceIcon(AiProviderId p) => switch (p) {
  AiProviderId.anthropic => Icons.auto_awesome_rounded,
  AiProviderId.openai => Icons.blur_on_rounded,
};

/// A readable model name: the provider's own name when "Refresh models"
/// brought one, else a tidy form of the id ("claude-sonnet-5-5" →
/// "Claude Sonnet 5.5", "gpt-6.1-sol" → "GPT-6.1 Sol").
String aiModelLabel(String id, {String? displayName}) {
  if (displayName != null && displayName.trim().isNotEmpty) return displayName.trim();
  final claude = RegExp(r'^claude-([a-z]+)-(\d+)(?:-(\d{1,2}))?(?:-\d{8})?$').firstMatch(id);
  if (claude != null) {
    final family = claude[1]!;
    final version = claude[3] == null ? claude[2]! : '${claude[2]}.${claude[3]}';
    return 'Claude ${family[0].toUpperCase()}${family.substring(1)} $version';
  }
  final gpt = RegExp(r'^gpt-([\d.]+)(?:-([a-z]+))?$').firstMatch(id);
  if (gpt != null) {
    final tier = gpt[2];
    return tier == null ? 'GPT-${gpt[1]}' : 'GPT-${gpt[1]} ${tier[0].toUpperCase()}${tier.substring(1)}';
  }
  return id;
}
