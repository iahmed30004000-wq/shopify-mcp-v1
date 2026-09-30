import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/saved_games/domain/game_url.dart';
import 'package:madar/features/saved_games/domain/navigation_policy.dart';
import 'package:madar/features/saved_games/domain/page_meta.dart';
import 'package:madar/features/saved_games/domain/saved_web_game.dart';
import 'package:madar/features/saved_games/presentation/game_art.dart';

GameUrlError? err(String s) => validateGameUrl(s).error;
String? ok(String s) => validateGameUrl(s).url?.toString();

void main() {
  group('validateGameUrl', () {
    test('accepts https links and claude.ai artifacts, normalised', () {
      expect(
        ok('https://claude.ai/public/artifacts/0f1e2d3c-4b5a-6978-8899-aabbccddeeff'),
        'https://claude.ai/public/artifacts/0f1e2d3c-4b5a-6978-8899-aabbccddeeff',
      );
      expect(
        ok('  HTTPS://Games.Example.ORG:443/Play?level=2#start  '),
        'https://games.example.org/Play?level=2#start',
      );
      expect(ok('https://example.com'), 'https://example.com/');
      expect(ok('https://example.com:8443/x'), 'https://example.com:8443/x');
      expect(ok('https://192.168.1.20/game'), 'https://192.168.1.20/game');
    });

    test('adds https to a bare host and to host:port', () {
      expect(ok('claude.ai/public/artifacts/abc'), 'https://claude.ai/public/artifacts/abc');
      expect(ok('example.com:8443/x'), 'https://example.com:8443/x');
      expect(ok('//example.com/x'), 'https://example.com/x');
    });

    test('takes the link out of shared text', () {
      expect(ok('Try this game! https://claude.ai/public/artifacts/abc.'), 'https://claude.ai/public/artifacts/abc');
      expect(ok('جرّب: https://example.com/play، رائعة'), 'https://example.com/play');
      expect(extractSharedUrl('see (https://example.com/a_(b))'), 'https://example.com/a_(b)');
      expect(extractSharedUrl('no link here'), isNull);
    });

    test('rejects http with a notHttps error and offers the https version', () {
      expect(err('http://example.com/game'), GameUrlError.notHttps);
      expect(err('HTTP://example.com'), GameUrlError.notHttps);
      expect(err('shared: http://example.com/x'), GameUrlError.notHttps);
      expect(httpsVersionOf('http://example.com/game?x=1'), 'https://example.com/game?x=1');
      expect(httpsVersionOf('https://example.com'), isNull);
    });

    test('rejects javascript:, data:, file:, intent:, content: and other schemes', () {
      for (final s in [
        'javascript:alert(1)',
        'JavaScript:alert(document.cookie)',
        ' javascript://example.com/%0Aalert(1)',
        'data:text/html,<script>alert(1)</script>',
        'data:text/html;base64,PHNjcmlwdD4=',
        'file:///sdcard/Download/game.html',
        'file://localhost/etc/hosts',
        'intent://scan/#Intent;scheme=zxing;package=com.example;end',
        'content://com.android.providers.downloads/1',
        'about:blank',
        'blob:https://example.com/uuid',
        'ftp://example.com/game',
        'mailto:someone@example.com',
        'market://details?id=com.example',
        'ws://example.com/socket',
        'chrome://settings',
      ]) {
        expect(err(s), GameUrlError.unsupportedScheme, reason: s);
      }
    });

    test('rejects credentials, bad hosts, spaces, empty and huge input', () {
      expect(err(''), GameUrlError.empty);
      expect(err('   '), GameUrlError.empty);
      expect(err('https://user:pass@example.com/'), GameUrlError.credentials);
      expect(err('https://claude.ai@evil.example/'), GameUrlError.credentials);
      expect(err('https://localhost/game'), GameUrlError.malformed);
      expect(err('https://'), GameUrlError.malformed);
      expect(err('https:example.com'), GameUrlError.malformed);
      expect(err('https://exa mple.com'), GameUrlError.malformed);
      expect(err('https://-bad-.com'), GameUrlError.malformed);
      expect(err('https://example.123'), GameUrlError.malformed);
      expect(err('https://999.1.1.1/'), GameUrlError.malformed);
      expect(err('https://example.com:99999/'), GameUrlError.malformed);
      expect(err('not a link'), GameUrlError.malformed);
      expect(err('https://example.com/${'a' * 2100}'), GameUrlError.tooLong);
    });

    test('recognises Claude artifacts for the badge only', () {
      expect(isClaudeArtifactUrl(Uri.parse('https://claude.ai/public/artifacts/abc')), isTrue);
      expect(isClaudeArtifactUrl(Uri.parse('https://abc.claude.site/')), isTrue);
      expect(isClaudeArtifactUrl(Uri.parse('https://claude.ai/chat/abc')), isFalse);
      expect(isClaudeArtifactUrl(Uri.parse('https://notclaude.ai/public/artifacts/abc')), isFalse);
    });
  });

  group('origin policy (decideGameNavigation)', () {
    final home = GameOrigins(Uri.parse('https://claude.ai/public/artifacts/abc'));
    NavigationVerdict main(String url, {GameOrigins? o, bool initial = false}) =>
        decideGameNavigation(origins: o ?? home, target: url, isMainFrame: true, initialLoad: initial);
    NavigationVerdict sub(String url) => decideGameNavigation(origins: home, target: url, isMainFrame: false);

    test('originOf normalises scheme, host and default ports', () {
      expect(originOf(Uri.parse('https://Claude.AI:443/x')), 'https://claude.ai');
      expect(originOf(Uri.parse('https://example.com:8443/')), 'https://example.com:8443');
      expect(originOf(Uri.parse('http://example.com:80/')), 'http://example.com');
      expect(originOf(Uri.parse('data:text/plain,hi')), isNull);
    });

    test('main frame: same https origin stays inside', () {
      expect(main('https://claude.ai/public/artifacts/other'), NavigationVerdict.allow);
      expect(main('https://CLAUDE.ai:443/login?next=/'), NavigationVerdict.allow);
      expect(main('about:blank'), NavigationVerdict.allow);
    });

    test('main frame: other origins open externally after confirmation', () {
      expect(main('https://anthropic.com/'), NavigationVerdict.askExternal);
      expect(main('https://sub.claude.ai/'), NavigationVerdict.askExternal);
      expect(main('https://claude.ai:8443/'), NavigationVerdict.askExternal);
      // http is never loaded in the game view, even on the same host.
      expect(main('http://claude.ai/public/artifacts/abc'), NavigationVerdict.askExternal);
    });

    test('main frame: dangerous schemes are blocked', () {
      for (final s in [
        'javascript:alert(1)',
        'data:text/html,hi',
        'blob:https://claude.ai/x',
        'file:///etc/passwd',
        'content://media/external/images/1',
        'intent://x#Intent;end',
        'market://details?id=x',
        'mailto:a@b.c',
        'tel:123',
        'about:config',
        'https://user@claude.ai/',
        'https:///nohost',
      ]) {
        expect(main(s), NavigationVerdict.block, reason: s);
      }
    });

    test('initial redirects adopt the landing origin (bounded)', () {
      final o = GameOrigins(Uri.parse('https://example.com/'));
      expect(main('https://www.example.com/', o: o, initial: true), NavigationVerdict.adopt);
      final adopted = o.adopt(Uri.parse('https://www.example.com/'));
      expect(adopted.contains(Uri.parse('https://www.example.com/play')), isTrue);
      expect(main('https://www.example.com/b', o: adopted), NavigationVerdict.allow);
      // After the first load, leaving asks.
      expect(main('https://other.example/', o: adopted), NavigationVerdict.askExternal);
      // Never http, never more than maxAdoptedOrigins.
      expect(main('http://www.example.com/', o: o, initial: true), NavigationVerdict.askExternal);
      var many = o;
      for (var i = 0; i < maxAdoptedOrigins + 2; i++) {
        many = many.adopt(Uri.parse('https://h$i.example.com/'));
      }
      expect(many.adopted.length, maxAdoptedOrigins);
      expect(main('https://new.example.com/', o: many, initial: true), NavigationVerdict.askExternal);
    });

    test('sub-frames: embedded https, blank, data and blob load; the rest is blocked', () {
      expect(sub('https://www.claudeusercontent.com/sandbox'), NavigationVerdict.allow);
      expect(sub('about:srcdoc'), NavigationVerdict.allow);
      expect(sub('data:text/html,hi'), NavigationVerdict.allow);
      expect(sub('blob:https://claude.ai/uuid'), NavigationVerdict.allow);
      expect(sub('http://ads.example/'), NavigationVerdict.block);
      expect(sub('file:///sdcard/x'), NavigationVerdict.block);
      expect(sub('intent://x#Intent;end'), NavigationVerdict.block);
      expect(sub('javascript:alert(1)'), NavigationVerdict.block);
      expect(sub('content://x/y'), NavigationVerdict.block);
    });

    test('unparseable targets are blocked', () {
      expect(main('https://[::1'), NavigationVerdict.block);
    });

    test('planHush: prayer needs certain silence, the rest never unloads', () {
      expect(planHush(reason: HushReason.prayer, sealedFrames: 0), HushPlan.inPlace);
      expect(planHush(reason: HushReason.prayer, sealedFrames: 1), HushPlan.unload);
      expect(planHush(reason: HushReason.prayer, sealedFrames: null), HushPlan.unload);
      expect(planHush(reason: HushReason.user, sealedFrames: 3), HushPlan.inPlace);
      expect(planHush(reason: HushReason.background, sealedFrames: null), HushPlan.inPlace);
    });
  });

  group('page meta', () {
    final base = Uri.parse('https://games.example.org/play/index.html');

    test('prefers og:title, drops a repeated site-name suffix, decodes entities', () {
      const html = '''<html><head>
        <title>Ignored | Example</title>
        <meta property="og:site_name" content="Example">
        <meta property="og:title" content="Tom &amp; Jerry&#39;s Race | Example">
      </head><body><title>not this</title></body></html>''';
      expect(parsePageMeta(html, base).title, "Tom & Jerry's Race");
    });

    test('falls back to <title>, strips tags, controls and bidi overrides', () {
      const html = '<head><TITLE>\n  Star\u202E Tiles <b>2</b>\u0007 </TITLE></head>';
      expect(parsePageMeta(html, base).title, 'Star Tiles 2');
      expect(parsePageMeta('<head></head>', base).title, isNull);
    });

    test('titles are cut to the stored bound', () {
      final html = '<title>${'ب' * 300}</title>';
      expect(parsePageMeta(html, base).title!.length, SavedGamesLimits.maxTitle);
    });

    test('ranks icons: touch icon, then size; skips svg/http; adds /favicon.ico', () {
      const html = '''<head>
        <link rel="icon" href="/small.png" sizes="16x16">
        <link rel="icon" type="image/svg+xml" href="/logo.svg">
        <link rel="icon" href="icons/big.png" sizes="192x192">
        <link rel="apple-touch-icon" href="https://cdn.example.org/touch.png">
        <link rel="icon" href="http://insecure.example/i.png">
      </head>''';
      final icons = parsePageMeta(html, base).icons.map((u) => u.toString()).toList();
      expect(icons, [
        'https://cdn.example.org/touch.png',
        'https://games.example.org/play/icons/big.png',
        'https://games.example.org/small.png',
        'https://games.example.org/favicon.ico',
      ]);
    });

    test('decodeHtmlEntities handles numeric and named entities safely', () {
      expect(decodeHtmlEntities('&#x645;&#1583;&#x627;&#x631; &mdash; &unknown; &#0; &#xD800;'), 'مدار — &unknown;  ');
    });
  });

  group('SavedWebGame', () {
    final game = SavedWebGame(
      id: 'a',
      title: '  Space\n\tTiles  ',
      url: Uri.parse('https://example.com/'),
      art: const GameArt(glyph: 3, hue: 2),
      addedAt: DateTime(2026, 9, 1, 8, 30),
      notes: 'line one\nline two',
      playCount: 4,
      lastPlayedAt: DateTime(2026, 9, 29, 21),
      orientation: GameOrientation.portrait,
      clearDataPending: true,
    ).bounded();

    test('round-trips through JSON', () {
      final back = SavedWebGame.fromJson(jsonDecode(jsonEncode(game.toJson())) as Map);
      expect(back, game);
      expect(back.title, 'Space Tiles');
      expect(back.notes, 'line one\nline two');
    });

    test('refuses untrusted identity fields', () {
      Map<String, Object?> j(Map<String, Object?> patch) => {...game.toJson(), ...patch};
      expect(() => SavedWebGame.fromJson(j({'url': 'http://example.com/'})), throwsFormatException);
      expect(() => SavedWebGame.fromJson(j({'url': 'javascript:alert(1)'})), throwsFormatException);
      expect(() => SavedWebGame.fromJson(j({'url': 'HTTPS://EXAMPLE.com'})), throwsFormatException);
      expect(() => SavedWebGame.fromJson(j({'id': ''})), throwsFormatException);
      expect(() => SavedWebGame.fromJson(j({'addedAt': 'soon'})), throwsFormatException);
    });

    test('clamps text and repairs art', () {
      final g = SavedWebGame.fromJson({
        ...game.toJson(),
        'title': 'x' * 500,
        'notes': 'n' * 5000,
        'art': {'glyph': 99, 'hue': -3, 'favicon': base64Encode(Uint8List(SavedGamesLimits.maxIconBytes + 1))},
        'playCount': -5,
        'orientation': 'sideways',
      });
      expect(g.title.length, SavedGamesLimits.maxTitle);
      expect(g.notes.length, SavedGamesLimits.maxNotes);
      expect(g.art.glyph, 99 % SavedGamesLimits.glyphCount);
      expect(g.art.hue, inInclusiveRange(0, SavedGamesLimits.hueCount - 1));
      expect(g.art.favicon, isNull);
      expect(g.playCount, 0);
      expect(g.orientation, GameOrientation.auto);
    });

    test('generated art is deterministic and in range; the glyph set matches the bound', () {
      expect(GameArt.seeded('https://a.example/'), GameArt.seeded('https://a.example/'));
      for (var i = 0; i < 50; i++) {
        final a = GameArt.seeded('seed$i');
        expect(a.glyph, inInclusiveRange(0, SavedGamesLimits.glyphCount - 1));
        expect(a.hue, inInclusiveRange(0, SavedGamesLimits.hueCount - 1));
      }
      expect(GameArtPalette.glyphs.length, SavedGamesLimits.glyphCount);
    });
  });
}
