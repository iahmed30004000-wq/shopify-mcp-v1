// Shared fixtures for the Together Mode tests: a tiny deterministic
// turn-based game with a strict key whitelist, a leaky variant that tries to
// smuggle personal data, async helpers and the widget-test app.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/together/together.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Lets microtasks, stream hops and loopback deliveries run.
Future<void> settle([int rounds = 30]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// State of [RaceGame]: players add 1 or 2 in turn; whoever reaches [goal]
/// wins. The start value comes from the shared seed.
@immutable
class RaceState {
  const RaceState({required this.n, required this.toMove, required this.goal, this.hist = const []});

  final int n;
  final int toMove;
  final int goal;
  final List<int> hist;

  bool get over => n >= goal;
}

/// A tiny, deterministic turn-based game with a strict key whitelist.
class RaceGame extends TogetherGameAdapter<RaceState, int> {
  const RaceGame({this.gameId = 'race', this.gameVersion = 1, this.startOffset = 0});

  @override
  final String gameId;

  @override
  final int gameVersion;

  /// Changes the rules (a "different version" of the same game).
  final int startOffset;

  static const Set<String> keys = {'n', 'p', 'goal', 'hist', 'add'};

  @override
  TogetherGameKind get kind => TogetherGameKind.turnBased;

  @override
  GameDataPolicy get policy => const GameDataPolicy(allowedKeys: keys);

  @override
  int get seatCount => 2;

  @override
  RaceState initialState({required int seed, required GameData config}) {
    final goal = config.value is Map ? (config.map['goal'] as int? ?? 12) : 12;
    return RaceState(n: seed % 5 + startOffset, toMove: 0, goal: goal);
  }

  @override
  int? seatToMove(RaceState state) => state.over ? null : state.toMove;

  @override
  String? validateMove(RaceState state, int seat, int move) {
    if (state.over) return 'matchOver';
    if (seat != state.toMove) return 'notYourTurn';
    return move == 1 || move == 2 ? null : 'illegalMove';
  }

  @override
  RaceState applyMove(RaceState state, int seat, int move) =>
      RaceState(n: state.n + move, toMove: 1 - state.toMove, goal: state.goal, hist: [...state.hist, move]);

  @override
  SeatOutcome? outcome(RaceState state) {
    if (!state.over) return null;
    final winner = 1 - state.toMove;
    final w = state.hist.length;
    return SeatOutcome.win(winner, scores: winner == 0 ? [w, w - 1] : [w - 1, w]);
  }

  @override
  Object? encodeState(RaceState state) => {'n': state.n, 'p': state.toMove, 'goal': state.goal, 'hist': state.hist};

  @override
  RaceState decodeState(Object? json) {
    final m = json! as Map;
    return RaceState(
      n: m['n'] as int,
      toMove: m['p'] as int,
      goal: m['goal'] as int,
      hist: [for (final v in m['hist'] as List) v as int],
    );
  }

  @override
  Object? encodeMove(int move) => {'add': move};

  @override
  int decodeMove(Object? json) => (json! as Map)['add'] as int;
}

/// A buggy / malicious game encoding that tries to attach personal data to
/// its moves.
class LeakyRaceGame extends RaceGame {
  const LeakyRaceGame(this.extra, {this.strict = true});

  final Map<String, Object?> extra;

  /// With the game's key whitelist (else only the standard policy).
  final bool strict;

  @override
  GameDataPolicy get policy => strict ? super.policy : GameDataPolicy.standard;

  @override
  Object? encodeMove(int move) => {'add': move, ...extra};
}

/// A connected host + guest pair over a loopback link.
class SessionPair {
  SessionPair({
    TogetherGameAdapter<RaceState, int> host = const RaceGame(),
    TogetherGameAdapter<RaceState, int> guest = const RaceGame(),
    Duration latency = Duration.zero,
  }) : link = LoopbackLink(latency: latency) {
    this.host = TogetherSession<RaceState, int>(
      adapter: host,
      transport: link.host,
      recorder: (r) async {
        hostRecords.add(r);
        return null;
      },
    );
    this.guest = TogetherSession<RaceState, int>(
      adapter: guest,
      transport: link.guest,
      role: SessionRole.guest,
      recorder: (r) async {
        guestRecords.add(r);
        return null;
      },
    );
  }

  final LoopbackLink link;
  late final TogetherSession<RaceState, int> host;
  late final TogetherSession<RaceState, int> guest;
  final List<MatchRecord> hostRecords = [];
  final List<MatchRecord> guestRecords = [];

  void dispose() {
    host.dispose();
    guest.dispose();
  }
}

// ------------------------------------------------------------ widget app

/// Fixed "now" of the widget tests: Wednesday 30 Sep 2026, 20:00.
final DateTime togetherNow = DateTime(2026, 9, 30, 20);

class TogetherTestEnv {
  TogetherTestEnv(this.db, this.haptics, this.secure);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final RecordingSecureScreen secure;
  late ProviderContainer container;

  TogetherRepository get repo => TogetherRepository(db);
}

/// The widget-test app around [home]: in-memory database, fixed clock,
/// silent sound + recording haptics, recording FLAG_SECURE hook.
Future<(Widget, TogetherTestEnv)> buildTogetherApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(TogetherRepository repo)? seed,
}) async {
  SharedPreferences.setMockInitialValues({
    'madar.settings.v1': jsonEncode(AppSettings(languageCode: locale.languageCode, onboarded: true).toJson()),
  });
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode, seed: false);
  if (seed != null) await tester.runAsync(() => seed(TogetherRepository(db)));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final secure = RecordingSecureScreen();
  final env = TogetherTestEnv(db, haptics, secure);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      togetherClockProvider.overrideWithValue(() => togetherNow),
      togetherSecureScreenProvider.overrideWithValue(secure),
      ...overrides,
    ],
    child: Consumer(
      builder: (context, ref, _) {
        env.container = ProviderScope.containerOf(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildMadarTheme(theme, arabic: arabic),
          locale: locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          builder: (context, child) => MadarFormatScope(
            digits: DigitStyle.auto,
            child: MotionScope(
              reduced: reducedMotion,
              child: CelebrationOverlay(child: child!),
            ),
          ),
          home: home,
        );
      },
    ),
  );
  return (app, env);
}

Future<TogetherTestEnv> pumpTogetherApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(TogetherRepository repo)? seed,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildTogetherApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    reducedMotion: reducedMotion,
    overrides: overrides,
    seed: seed,
  );
  await tester.pumpWidget(app);
  await settleTogether(tester);
  return env;
}

/// Lets database streams deliver and finite animations finish.
Future<void> settleTogether(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

/// A history with generic players: rivalries in three games, a co-op run,
/// a draw and a close finish – enough to earn several trophies.
Future<void> seedTogetherHistory(TogetherRepository repo, {DateTime? now}) async {
  final end = now ?? togetherNow;
  var i = 0;
  Future<void> rec(String game, MatchOutcome o, {int? a, int? b, int daysAgo = 0, PlayMode mode = PlayMode.passAndPlay}) =>
      repo.recordMatch(
        MatchRecord(
          id: 'seed-${i++}',
          gameId: game,
          endedAt: end.subtract(Duration(days: daysAgo, minutes: 90 - i)),
          outcome: o,
          scoreOne: a,
          scoreTwo: b,
          mode: mode,
        ),
      );
  await rec('chess', MatchOutcome.oneWon, daysAgo: 3);
  await rec('basra', MatchOutcome.twoWon, a: 88, b: 101, daysAgo: 3);
  await rec('fourInARow', MatchOutcome.twoWon, daysAgo: 2);
  await rec('fourInARow', MatchOutcome.oneWon, daysAgo: 2);
  await rec('basra', MatchOutcome.twoWon, a: 97, b: 98, daysAgo: 1);
  await rec('metropolisCoop', MatchOutcome.teamWon, daysAgo: 1, mode: PlayMode.splitScreen);
  await rec('chess', MatchOutcome.draw, daysAgo: 1);
  await rec('airHockey', MatchOutcome.twoWon, a: 5, b: 7, mode: PlayMode.splitScreen);
  await rec('basra', MatchOutcome.twoWon, a: 76, b: 104);
  await rec('tarneeb', MatchOutcome.teamWon, a: 41, b: 41);
}
