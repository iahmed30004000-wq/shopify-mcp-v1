import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/saved_games/player/game_player_controller.dart';
import 'package:madar/features/saved_games/player/game_scripts.dart';
import 'package:madar/features/saved_games/saved_games.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'saved_games_fakes.dart';

class RecordingDialogs implements GamePageDialogs {
  final List<String> shown = [];

  @override
  Future<void> alert(String host, String message) async => shown.add('alert:$host:$message');

  @override
  Future<bool> confirm(String host, String message) async {
    shown.add('confirm:$host:$message');
    return true;
  }

  @override
  Future<String?> prompt(String host, String message, String? defaultText) async {
    shown.add('prompt:$host:$message');
    return 'answer';
  }
}

final SavedWebGame artifact = SavedWebGame(
  id: 'g1',
  title: 'Double Feature',
  url: Uri.parse('https://claude.ai/public/artifacts/abc'),
  art: const GameArt(glyph: 0, hue: 0),
  addedAt: DateTime(2026, 9, 1),
);

/// Android-style result of the hush script.
String hushResult(int sealed, {bool blind = false}) =>
    '"{\\"sealed\\":$sealed,\\"blind\\":$blind,\\"media\\":1,\\"ctx\\":1}"';

/// Android-style result of the tracker installed before the page's scripts.
const String trackedEarly = '"{\\"early\\":true}"';

void main() {
  late FakeWebViewPlatform platform;
  late FakeSessionPlatform session;
  late RecordingDialogs dialogs;
  late List<Uri> external;
  late int cleared;

  GamePlayerController make({SavedWebGame? game}) => GamePlayerController(
    game: game ?? artifact,
    dialogs: dialogs,
    platform: session,
    onExternalRequest: (u) async => external.add(u),
    onCleared: () async => cleared++,
    rehushInterval: const Duration(seconds: 2),
  );

  setUp(() {
    platform = FakeWebViewPlatform();
    WebViewPlatform.instance = platform;
    session = FakeSessionPlatform();
    dialogs = RecordingDialogs();
    external = [];
    cleared = 0;
  });

  testWidgets('configures a locked-down WebView and loads the original link', (tester) async {
    final c = make();
    await c.start();
    final web = platform.last;
    expect(web.jsMode, JavaScriptMode.unrestricted);
    expect(web.channels, isEmpty, reason: 'no JavaScript bridge to the app');
    expect(web.delegate, isNotNull);
    expect(web.zoom, isFalse);
    expect(web.overScroll, WebViewOverScrollMode.never);
    expect(web.onAlert, isNotNull);
    expect(web.onConfirm, isNotNull);
    expect(web.onPrompt, isNotNull);
    expect(web.loads, ['https://claude.ai/public/artifacts/abc']);
    expect(web.htmlLoads, isEmpty);
    // Camera / microphone / geolocation requests are denied.
    final request = FakePermissionRequest();
    web.permissionHandler!(request);
    expect(request.granted, isFalse);
    // Site logins are never answered from a game.
    var cancelled = false;
    web.delegate!.onAuth!(HttpAuthRequest(onProceed: (_) {}, onCancel: () => cancelled = true, host: 'claude.ai'));
    expect(cancelled, isTrue);
    c.dispose();
  });

  testWidgets('navigation: inside the origin loads, outside asks, dangerous is blocked', (tester) async {
    final c = make();
    await c.start();
    final web = platform.last;
    expect(await web.navigate('https://claude.ai/public/artifacts/other'), NavigationDecision.navigate);
    expect(await web.navigate('https://www.claudeusercontent.com/x', main: false), NavigationDecision.navigate);
    expect(await web.navigate('intent://x#Intent;end'), NavigationDecision.prevent);
    expect(await web.navigate('javascript:alert(1)'), NavigationDecision.prevent);
    expect(await web.navigate('file:///sdcard/a.html', main: false), NavigationDecision.prevent);
    expect(external, isEmpty);
    // First page done: another origin asks (once while a question is open).
    web.pageFinished('https://claude.ai/public/artifacts/abc');
    await tester.pump();
    expect(await web.navigate('https://www.anthropic.com/'), NavigationDecision.prevent);
    expect(external, [Uri.parse('https://www.anthropic.com/')]);
    c.dispose();
  });

  testWidgets('a redirect during the first load is adopted as the game origin', (tester) async {
    final c = make(game: artifact.copyWith(url: Uri.parse('https://example.com/')));
    await c.start();
    final web = platform.last;
    expect(await web.navigate('https://www.example.com/'), NavigationDecision.navigate);
    web.pageFinished('https://www.example.com/');
    await tester.pump();
    expect(c.origins.contains(Uri.parse('https://www.example.com/level2')), isTrue);
    expect(await web.navigate('https://www.example.com/level2'), NavigationDecision.navigate);
    expect(await web.navigate('https://tracker.example.net/'), NavigationDecision.prevent);
    expect(external, hasLength(1));
    c.dispose();
  });

  testWidgets('loading → ready installs audio tracking; errors show offline / failed / insecure', (tester) async {
    final c = make();
    await c.start();
    final web = platform.last;
    expect(c.phase, GamePhase.loading);
    web.progress(40);
    expect(c.progress, 40);
    web.pageFinished('https://claude.ai/public/artifacts/abc');
    await tester.pump();
    expect(c.phase, GamePhase.ready);
    expect(web.scripts, contains(GameScripts.trackAudio));

    // A sub-resource error is ignored.
    web.error(WebResourceErrorType.hostLookup, main: false);
    expect(c.phase, GamePhase.ready);

    final offline = make();
    await offline.start();
    platform.last.error(WebResourceErrorType.hostLookup);
    platform.last.pageFinished('https://claude.ai/public/artifacts/abc');
    expect(offline.phase, GamePhase.offline);
    await offline.retry();
    expect(offline.phase, GamePhase.loading);
    expect(platform.last.loads, hasLength(2));

    final failed = make();
    await failed.start();
    platform.last.error(WebResourceErrorType.badUrl);
    expect(failed.phase, GamePhase.failed);

    final insecure = make();
    await insecure.start();
    final ssl = FakeSslError();
    platform.last.delegate!.onSsl!(ssl);
    await tester.pump();
    expect(ssl.cancelled, isTrue);
    expect(ssl.proceeded, isFalse);
    expect(insecure.phase, GamePhase.insecure);
    for (final x in [c, offline, failed, insecure]) {
      x.dispose();
    }
  });

  testWidgets('prayer mute hushes in place when every sound source is reachable, then resumes', (tester) async {
    final c = make();
    await c.start();
    final web = platform.last
      ..result = (s) => s == GameScripts.trackAudio ? trackedEarly : (s.contains('sealed') ? hushResult(0) : '""');
    web
      ..pageStarted('https://claude.ai/public/artifacts/abc')
      ..pageFinished('https://claude.ai/public/artifacts/abc');
    await tester.pump();
    await c.setPrayerMuted(true);
    expect(c.prayerHushed, isTrue);
    expect(c.phase, GamePhase.ready);
    expect(web.scripts, contains(GameScripts.hush(pause: true, hide: true)));
    expect(web.htmlLoads, isEmpty);
    // Periodic re-hush catches media the game starts later.
    final before = web.scripts.length;
    await tester.pump(const Duration(seconds: 3));
    expect(web.scripts.length, greaterThan(before));
    await c.setPrayerMuted(false);
    expect(c.prayerHushed, isFalse);
    expect(web.scripts.last, GameScripts.unhush);
    c.dispose();
  });

  testWidgets('prayer mute unloads a game whose sound is out of reach and reloads it after', (tester) async {
    final c = make();
    await c.start();
    final web = platform.last..result = (s) => s.contains('sealed') ? hushResult(1) : '""';
    web.pageFinished('https://claude.ai/public/artifacts/abc');
    await tester.pump();
    web.current = 'https://claude.ai/public/artifacts/abc?level=3';
    await c.setPrayerMuted(true);
    expect(c.phase, GamePhase.resting);
    expect(web.htmlLoads.last.$1, GameScripts.restPage);
    // Nothing navigates while resting.
    expect(await web.navigate('https://claude.ai/public/artifacts/abc'), NavigationDecision.prevent);
    await c.setPrayerMuted(false);
    expect(c.phase, GamePhase.loading);
    expect(web.loads.last, 'https://claude.ai/public/artifacts/abc?level=3');
    c.dispose();
  });

  testWidgets('a game opened during prayer waits, then loads when the mute lifts', (tester) async {
    final c = make();
    await c.setPrayerMuted(true);
    await c.start();
    final web = platform.last;
    expect(web.loads, isEmpty, reason: 'nothing may sound during prayer');
    expect(web.htmlLoads.last.$1, GameScripts.restPage);
    expect(c.phase, GamePhase.resting);
    await c.retry();
    expect(web.loads, isEmpty);
    await c.setPrayerMuted(false);
    expect(web.loads, ['https://claude.ai/public/artifacts/abc']);
    expect(c.phase, GamePhase.loading);
    c.dispose();
  });

  testWidgets('prayer during a data clear holds it, then finishes it before the game loads', (tester) async {
    final c = make();
    await c.start(clearFirst: true);
    final web = platform.last..result = (s) => s == GameScripts.clearedProbe ? '"done"' : '""';
    await c.setPrayerMuted(true);
    expect(c.phase, GamePhase.resting);
    web.pageFinished('about:blank');
    await tester.pump(const Duration(seconds: 9));
    expect(cleared, 0);
    expect(web.loads, isEmpty);
    await c.setPrayerMuted(false);
    expect(c.phase, GamePhase.clearing);
    web.pageFinished('https://claude.ai/');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(cleared, 1);
    expect(web.loads, ['https://claude.ai/public/artifacts/abc']);
    c.dispose();
  });

  testWidgets('the Mute button mutes without pausing and reports sealed frames', (tester) async {
    final c = make();
    await c.start();
    final web = platform.last..result = (s) => s.contains('sealed') ? hushResult(2) : '""';
    web.pageFinished('https://claude.ai/public/artifacts/abc');
    await tester.pump();
    await c.setUserMuted(true);
    expect(c.userMuted, isTrue);
    expect(web.scripts, contains(GameScripts.hush(pause: false, hide: false)));
    expect(c.sealedAudio, isTrue);
    await c.setUserMuted(false);
    expect(web.scripts.last, GameScripts.unhush);
    // Leaving the app pauses (strict hush), returning restores.
    await c.setBackground(true);
    expect(web.scripts.last, GameScripts.hush(pause: true, hide: true));
    await c.setBackground(false);
    expect(web.scripts.last, GameScripts.unhush);
    c.dispose();
  });

  testWidgets('clear site data runs at the game origin, then loads the game fresh', (tester) async {
    final c = make();
    final web0 = platform;
    await c.start(clearFirst: true);
    final web = web0.last..result = (s) => s == GameScripts.clearedProbe ? '"done"' : '""';
    expect(c.phase, GamePhase.clearing);
    expect(web.htmlLoads.single.$2, 'https://claude.ai/');
    expect(web.htmlLoads.single.$1, GameScripts.clearSiteDataPage);
    expect(web.loads, isEmpty);
    web.pageFinished('https://claude.ai/');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(cleared, 1);
    expect(web.loads, ['https://claude.ai/public/artifacts/abc']);
    expect(c.phase, GamePhase.loading);
    c.dispose();
  });

  testWidgets('clearing from the player covers every origin the game used', (tester) async {
    final c = make(game: artifact.copyWith(url: Uri.parse('https://example.com/')));
    await c.start();
    final web = platform.last..result = (s) => s == GameScripts.clearedProbe ? '"done"' : '""';
    expect(await web.navigate('https://www.example.com/'), NavigationDecision.navigate);
    web.pageFinished('https://www.example.com/');
    await tester.pump();
    await c.clearSiteData();
    web.pageFinished('https://example.com/');
    await tester.pump();
    web.pageFinished('https://www.example.com/');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(web.htmlLoads.map((h) => h.$2), ['https://example.com/', 'https://www.example.com/']);
    expect(cleared, 1);
    expect(web.loads.last, 'https://example.com/');
    c.dispose();
  });

  testWidgets('page dialogs are forwarded with the host, and a flood is cut off', (tester) async {
    final c = make();
    await c.start();
    final web = platform.last;
    web.pageFinished('https://claude.ai/public/artifacts/abc');
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await web.onAlert!(JavaScriptAlertDialogRequest(message: 'hi $i', url: 'https://claude.ai/x'));
    }
    expect(dialogs.shown, ['alert:claude.ai:hi 0', 'alert:claude.ai:hi 1', 'alert:claude.ai:hi 2']);
    c.dispose();
  });

  test('decodes Android-quoted script results', () {
    expect(decodeJsString('"done"'), 'done');
    expect(decodeJsString('done'), 'done');
    expect(decodeJsObject(hushResult(3))!['sealed'], 3);
    expect(decodeJsObject('{"sealed":0}')!['sealed'], 0);
    expect(decodeJsObject('nope'), isNull);
    expect(decodeJsObject(null), isNull);
  });

  test('hush scripts interpolate only booleans', () {
    expect(GameScripts.hush(pause: true, hide: false), contains('var PAUSE = true, HIDE = false;'));
    expect(GameScripts.hush(pause: false, hide: true), contains('var PAUSE = false, HIDE = true;'));
  });

  test('orientation locks per game', () {
    expect(orientationsFor(GameOrientation.portrait), [DeviceOrientation.portraitUp]);
    expect(orientationsFor(GameOrientation.landscape), hasLength(2));
    expect(orientationsFor(GameOrientation.auto), hasLength(3));
  });
}
