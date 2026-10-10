import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/routing/routes.dart';
import '../../../ai_chat/ai_chat.dart' show AskAiEntry;
import 'life_hubs.dart' show LifeHubs;

/// "Ask about Money" at the foot of a world's hub: it opens a **new** AI
/// chat with a question about that world already typed into the field.
///
/// Nothing is sent and no network call is made by opening it: the prompt is
/// a draft he can change or delete, and the first Send shows him exactly
/// what would be shared before anything leaves the phone.
///
/// Every world that the AI summary has a section for gets one – Faith,
/// Health, Money and the five life worlds (Work, Family, Travel, Growth and
/// the Body). A custom world of his own has no prompt, so it has no entry.
class PlanetAskAi extends StatelessWidget {
  const PlanetAskAi({super.key, required this.planetKey, required this.area});

  /// The world's key (`'money'`, `'body'` …).
  final String planetKey;

  /// The world's name, for "Ask about {area}".
  final String area;

  /// Whether [planetKey] has an Ask-AI entry.
  static bool supports(String planetKey) =>
      planetKey == 'faith' || planetKey == 'health' || planetKey == 'money' || LifeHubs.has(planetKey);

  /// The question typed into the new chat for [planetKey] (null: none).
  static String? promptOf(L10n l, String planetKey) => switch (planetKey) {
    'faith' => l.systemShellAskFaithPrompt,
    'health' => l.systemShellAskHealthPrompt,
    'money' => l.systemShellAskMoneyPrompt,
    'work' => l.systemShellAskWorkPrompt,
    'family' => l.systemShellAskFamilyPrompt,
    'travel' => l.systemShellAskTravelPrompt,
    'growth' => l.systemShellAskGrowthPrompt,
    'body' => l.systemShellAskBodyPrompt,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final prompt = promptOf(L10n.of(context), planetKey);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, 0),
      child: AskAiEntry(
        area: area,
        prompt: prompt,
        seed: 0.37,
        onOpen: () => unawaited(context.push<void>(AppRoutes.aiOf(draft: prompt))),
      ),
    );
  }
}
