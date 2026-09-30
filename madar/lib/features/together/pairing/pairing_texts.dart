import 'package:flutter/widgets.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../transport/online/online_config.dart';
import '../transport/pairing_state.dart';
import '../transport/turn_alerts.dart';

/// The pairing's user-facing texts (names bidi-isolated inside sentences).
class PairingTexts {
  const PairingTexts(this.l, this.fmt);

  factory PairingTexts.of(BuildContext context) => PairingTexts(L10n.of(context), MadarFormatter.of(context));

  final L10n l;
  final MadarFormatter fmt;

  String name(String raw) => fmt.isolate(raw);

  /// Digits in the reader's style (a code, a token).
  String digits(String s) => fmt.localizeDigits(s);

  String failure(PairingFailure f) => switch (f) {
    PairingFailure.radioOff => l.togetherNetFailRadio,
    PairingFailure.declinedByPeer => l.togetherNetFailDeclined,
    PairingFailure.notFound => l.togetherNetFailNotFound,
    PairingFailure.expired => l.togetherNetFailExpired,
    PairingFailure.taken => l.togetherNetFailTaken,
    PairingFailure.differentGame => l.togetherNetFailDifferentGame,
    PairingFailure.network => l.togetherNetFailNetwork,
    PairingFailure.setup => l.togetherNetFailSetup,
    PairingFailure.signIn => l.togetherNetFailSignIn,
    PairingFailure.rules => l.togetherNetFailRules,
    PairingFailure.peerLeft => l.togetherNetFailPeerLeft,
    PairingFailure.unknown => l.togetherNetFailUnknown,
  };

  String field(OnlineConfigField f) => switch (f) {
    OnlineConfigField.apiKey => l.togetherNetFieldApiKey,
    OnlineConfigField.appId => l.togetherNetFieldAppId,
    OnlineConfigField.projectId => l.togetherNetFieldProjectId,
    OnlineConfigField.databaseUrl => l.togetherNetFieldDatabaseUrl,
    OnlineConfigField.senderId => l.togetherNetFieldSenderId,
  };

  String problem(OnlineConfigProblem p) => switch (p) {
    OnlineConfigProblem.missing => l.togetherNetErrMissing,
    OnlineConfigProblem.format => l.togetherNetErrFormat,
    OnlineConfigProblem.mismatch => l.togetherNetErrMismatch,
  };

  /// "Your turn" in [gameName] after [peerName] played.
  TogetherTurnTexts turn({required String gameName, required String peerName}) => TogetherTurnTexts(
    groupName: l.togetherNetTurnGroup,
    channelName: l.togetherNetTurnChannel,
    channelDescription: l.togetherNetTurnChannelBody,
    title: l.togetherNetTurnTitle(gameName),
    body: l.togetherNetTurnBody(peerName),
  );
}
