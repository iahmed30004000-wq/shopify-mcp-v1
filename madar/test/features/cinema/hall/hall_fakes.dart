// Test doubles for the Madar Cinema hall.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/hall/cinema_records.dart';
import 'package:madar/features/saved_games/saved_games.dart';

import '../../../helpers/screenshot_harness.dart';

class FakeSession implements GameSessionPlatform {
  final List<String> calls = [];

  @override
  Future<void> enter(GameOrientation orientation) async => calls.add('enter ${orientation.name}');
  @override
  Future<void> exit() async => calls.add('exit');
  @override
  Future<void> reassert() async => calls.add('reassert');
  @override
  Future<bool> pauseWebView(int webViewId) async => false;
  @override
  Future<void> resumeWebView(int webViewId) async {}
  @override
  Future<void> hardenWebView(int webViewId) async {}
  @override
  Stream<int> get rendererGone => const Stream.empty();
}

/// The hall's providers with in-memory stores.
class HallTestEnv {
  HallTestEnv({CinemaRecords records = CinemaRecords.empty}) : store = MemoryCinemaRecordsStore(records);

  final MemoryCinemaRecordsStore store;
  final FakeSession session = FakeSession();
  final MemorySavedWebGamesStore savedGames = MemorySavedWebGamesStore();
  late final PrayerMuteController mute = PrayerMuteController(SilentSoundService());

  List<Override> get overrides => [
    cinemaRecordsStoreProvider.overrideWithValue(store),
    savedWebGamesStoreProvider.overrideWithValue(savedGames),
    gameSessionPlatformProvider.overrideWithValue(session),
    prayerMuteProvider.overrideWithValue(mute),
  ];

  Widget app(Widget home, {Locale locale = const Locale('ar')}) => ProviderScope(
    overrides: overrides,
    child: madarScreenshotApp(home: home, locale: locale),
  );
}
