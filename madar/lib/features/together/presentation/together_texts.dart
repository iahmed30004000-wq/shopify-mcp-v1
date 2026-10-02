import 'package:flutter/material.dart';

import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../domain/match_record.dart';
import '../domain/play_modes.dart';
import '../domain/player_profile.dart';
import '../domain/trophies.dart';

/// Every user-facing Together text: localised, numbers in the user's digit
/// style, names bidi-isolated so a Latin name never scrambles an Arabic
/// sentence (and the other way round).
class TogetherTexts {
  const TogetherTexts(this.l, this.fmt);

  factory TogetherTexts.of(BuildContext context) => TogetherTexts(L10n.of(context), MadarFormatter.of(context));

  final L10n l;
  final MadarFormatter fmt;

  bool get arabic => fmt.languageCode == 'ar';

  String n(int v) => fmt.formatInt(v, grouping: v.abs() >= 10000);

  String digits(String s) => fmt.localizeDigits(s);

  /// Short facts on one line: "10 matches · 1 draw" / "١٠ مباريات، تعادل
  /// واحد" (a middle dot beside Arabic-Indic digits reads as a zero).
  String facts(Iterable<String> parts) => parts.join(l.commonFactSeparator);

  /// The player's name, or the localised "Player 1" / "Player 2".
  String rawName(TogetherProfile p) => p.name.isNotEmpty ? p.name : l.togetherPlayerDefault(n(p.slot.index + 1));

  /// [rawName], bidi-isolated for use inside sentences.
  String name(TogetherProfile p) => fmt.isolate(rawName(p));

  /// The player's title (preset or typed), or null.
  String? title(TogetherProfile p) {
    final t = p.title;
    if (t != null) return titleOf(t);
    return p.customTitle.isEmpty ? null : p.customTitle;
  }

  String titleOf(PlayerTitle t) => switch (t) {
    PlayerTitle.strategist => l.togetherTitleStrategist,
    PlayerTitle.cardShark => l.togetherTitleCardShark,
    PlayerTitle.luckyStar => l.togetherTitleLuckyStar,
    PlayerTitle.challenger => l.togetherTitleChallenger,
    PlayerTitle.grandmaster => l.togetherTitleGrandmaster,
    PlayerTitle.quizWhiz => l.togetherTitleQuizWhiz,
    PlayerTitle.comebackKing => l.togetherTitleComebackKing,
    PlayerTitle.lightning => l.togetherTitleLightning,
    PlayerTitle.peacemaker => l.togetherTitlePeacemaker,
    PlayerTitle.dreamer => l.togetherTitleDreamer,
  };

  // ------------------------------------------------------------------ modes

  String mode(PlayMode m) => switch (m) {
    PlayMode.passAndPlay => l.togetherModePassAndPlay,
    PlayMode.splitScreen => l.togetherModeSplitScreen,
    PlayMode.nearby => l.togetherModeNearby,
    PlayMode.online => l.togetherModeOnline,
  };

  String modeBody(PlayMode m) => switch (m) {
    PlayMode.passAndPlay => l.togetherModePassAndPlayBody,
    PlayMode.splitScreen => l.togetherModeSplitScreenBody,
    PlayMode.nearby => l.togetherModeNearbyBody,
    PlayMode.online => l.togetherModeOnlineBody,
  };

  String? availability(ModeAvailability a) => switch (a) {
    ModeAvailability.available => null,
    ModeAvailability.unsupported => l.togetherModeUnsupported,
    ModeAvailability.comingSoon => l.togetherComingSoon,
    ModeAvailability.disabled => l.togetherModeDisabled,
  };

  String layout(SplitLayout s) => switch (s) {
    SplitLayout.faceToFace => l.togetherLayoutFaceToFace,
    SplitLayout.sideBySide => l.togetherLayoutSideBySide,
    SplitLayout.endToEnd => l.togetherLayoutEndToEnd,
  };

  // ------------------------------------------------------------------ games

  String game(String id) => switch (id) {
    'tarneeb' => l.togetherGameTarneeb,
    'trix' => l.togetherGameTrix,
    'basra' => l.togetherGameBasra,
    'konkan' => l.togetherGameKonkan,
    'backgammon' => l.togetherGameBackgammon,
    'chess' => l.togetherGameChess,
    'dominoes' => l.togetherGameDominoes,
    'ludo' => l.togetherGameLudo,
    'fourInARow' => l.togetherGameFourInARow,
    'wordDuel' => l.togetherGameWordDuel,
    'quizDuel' => l.togetherGameQuizDuel,
    'drawGuess' => l.togetherGameDrawGuess,
    'miniGolf' => l.togetherGameMiniGolf,
    'knowMe' => l.togetherGameKnowMe,
    'airHockey' => l.togetherGameAirHockey,
    'beachVolley' => l.togetherGameBeachVolley,
    'kartDash' => l.togetherGameKartDash,
    'snowballFight' => l.togetherGameSnowballFight,
    'paddleDuel' => l.togetherGamePaddleDuel,
    'tankDuel' => l.togetherGameTankDuel,
    'metropolisCoop' => l.togetherGameMetropolisCoop,
    _ => l.togetherGameUnknown,
  };

  // ---------------------------------------------------------------- results

  String outcome(MatchRecord r, TogetherProfiles players) => switch (r.outcome) {
    MatchOutcome.oneWon => l.togetherResultWon(name(players.one)),
    MatchOutcome.twoWon => l.togetherResultWon(name(players.two)),
    MatchOutcome.draw => l.togetherResultDraw,
    MatchOutcome.teamWon => l.togetherResultTeamWon,
    MatchOutcome.teamLost => l.togetherResultTeamLost,
  };

  /// "7 – 5" with player one's score first (at the reading start).
  String score(int a, int b) => digits('$a – $b');

  String matches(int count) => digits(l.togetherMatchesCount(count));

  String draws(int count) => digits(l.togetherDrawsCount(count));

  String days(int count) => digits(l.togetherDaysCount(count));

  String date(DateTime d) => fmt.formatDate(d, style: MadarDateStyle.dayMonth);

  // --------------------------------------------------------------- trophies

  String trophy(TrophyId id) => switch (id) {
    TrophyId.firstMatch => l.togetherTrophyFirstMatch,
    TrophyId.matches10 => l.togetherTrophyMatches10,
    TrophyId.matches50 => l.togetherTrophyMatches50,
    TrophyId.matches100 => l.togetherTrophyMatches100,
    TrophyId.matches250 => l.togetherTrophyMatches250,
    TrophyId.dayStreak3 => l.togetherTrophyDayStreak3,
    TrophyId.dayStreak7 => l.togetherTrophyDayStreak7,
    TrophyId.dayStreak30 => l.togetherTrophyDayStreak30,
    TrophyId.winStreak3 => l.togetherTrophyWinStreak3,
    TrophyId.winStreak5 => l.togetherTrophyWinStreak5,
    TrophyId.winStreak10 => l.togetherTrophyWinStreak10,
    TrophyId.explorer5 => l.togetherTrophyExplorer5,
    TrophyId.explorer10 => l.togetherTrophyExplorer10,
    TrophyId.coopWins5 => l.togetherTrophyCoopWins5,
    TrophyId.coopWins25 => l.togetherTrophyCoopWins25,
    TrophyId.marathon => l.togetherTrophyMarathon,
    TrophyId.photoFinish => l.togetherTrophyPhotoFinish,
    TrophyId.nailBiter => l.togetherTrophyNailBiter,
    TrophyId.perfectBalance => l.togetherTrophyPerfectBalance,
    TrophyId.gameMaster => l.togetherTrophyGameMaster,
    TrophyId.mindReader => l.togetherTrophyMindReader,
    TrophyId.challengeChampions => l.togetherTrophyChallengeChampions,
    TrophyId.dreamCameTrue => l.togetherTrophyDreamCameTrue,
  };

  /// What the trophy is for ([gameId] names the game of a per-game trophy).
  String trophyDescription(TrophyId id, {String? gameId}) {
    final c = n(id.target);
    final text = switch (id) {
      TrophyId.firstMatch => l.togetherTrophyFirstMatchDesc,
      TrophyId.matches10 => l.togetherTrophyMatches10Desc(c),
      TrophyId.matches50 => l.togetherTrophyMatches50Desc(c),
      TrophyId.matches100 => l.togetherTrophyMatches100Desc(c),
      TrophyId.matches250 => l.togetherTrophyMatches250Desc(c),
      TrophyId.dayStreak3 => l.togetherTrophyDayStreak3Desc(c),
      TrophyId.dayStreak7 => l.togetherTrophyDayStreak7Desc(c),
      TrophyId.dayStreak30 => l.togetherTrophyDayStreak30Desc(c),
      TrophyId.winStreak3 => l.togetherTrophyWinStreak3Desc(c),
      TrophyId.winStreak5 => l.togetherTrophyWinStreak5Desc(c),
      TrophyId.winStreak10 => l.togetherTrophyWinStreak10Desc(c),
      TrophyId.explorer5 => l.togetherTrophyExplorer5Desc(c),
      TrophyId.explorer10 => l.togetherTrophyExplorer10Desc(c),
      TrophyId.coopWins5 => l.togetherTrophyCoopWins5Desc(c),
      TrophyId.coopWins25 => l.togetherTrophyCoopWins25Desc(c),
      TrophyId.marathon => l.togetherTrophyMarathonDesc(c),
      TrophyId.photoFinish => l.togetherTrophyPhotoFinishDesc,
      TrophyId.nailBiter => l.togetherTrophyNailBiterDesc,
      TrophyId.perfectBalance => l.togetherTrophyPerfectBalanceDesc(c),
      TrophyId.gameMaster => l.togetherTrophyGameMasterDesc(c, fmt.isolate(gameId == null ? '…' : game(gameId))),
      TrophyId.mindReader => l.togetherTrophyMindReaderDesc,
      TrophyId.challengeChampions => l.togetherTrophyChallengeChampionsDesc,
      TrophyId.dreamCameTrue => l.togetherTrophyDreamCameTrueDesc,
    };
    return digits(text);
  }

  String tier(TrophyTier t) => switch (t) {
    TrophyTier.bronze => l.togetherTierBronze,
    TrophyTier.silver => l.togetherTierSilver,
    TrophyTier.gold => l.togetherTierGold,
    TrophyTier.legendary => l.togetherTierLegendary,
  };

  String progress(TrophyProgress p) => digits(l.togetherProgressOf(n(p.current), n(p.target)));
}
