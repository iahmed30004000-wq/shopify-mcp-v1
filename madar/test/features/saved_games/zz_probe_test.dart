import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/saved_games/domain/game_url.dart';
import 'package:madar/features/saved_games/domain/navigation_policy.dart';

void main() {
  test('probe', () {
    final inputs = [
      'HTTPS://CLAUDE.AI@EVIL.EXAMPLE/',
      'https://claude.ai%40evil.example/',
      'https://claude.ai\\@evil.example/',
      'https://evil.example\\@claude.ai/',
      'https://evil.example\\.claude.ai/',
      'https://claude.ai\\evil.example/',
      'https://claude.ai:443@evil.example/',
      'https://сlaude.ai/public/artifacts/x',
      'https://ｃｌａｕｄｅ.ai/',
      'https://claude。ai/',
      'https://xn--laude-4ve.ai/public/artifacts/x',
      'https://مثال.السعودية/',
      'https://claude.ai​.evil.example/',
      '​javascript:alert(1)',
      'java\tscript:alert(1)',
      '﻿https://claude.ai/x',
      'https://claude.ai/x ',
      'https://claude.ai/‮gnp.exe',
      'ｊａｖａｓｃｒｉｐｔ:alert(1)',
      'https://127.0.0.1/',
      'https://[::1]/',
      'https://0x7f.1/',
      'https://%63laude.ai/',
      'https://claude.ai./x',
      'https:/\\evil.example',
      'https:\\\\evil.example',
      'HtTpS://Example.COM',
      ' javascript:alert(1)',
      'https://evil.example#@claude.ai',
      'https://evil.example?@claude.ai',
      'https://claude.ai\r\n.evil.example/',
      'intent://claude.ai#Intent;scheme=https;end',
      'https://a.b.c.d.e.f.example.com:65535/',
    ];
    for (final i in inputs) {
      final r = validateGameUrl(i);
      // ignore: avoid_print
      print('${Uri.encodeFull(i)} => $r ${r.url?.host}');
    }
    final o = GameOrigins(Uri.parse('https://claude.ai/public/artifacts/abc'));
    for (final t in [
      'HTTPS://CLAUDE.AI/x',
      'https://claude.ai@evil.example/',
      'https://evil.example\\@claude.ai/',
      'https://claude.ai\\@evil.example/',
      'https://claude.ai%2eevil.example/',
      'INTENT://x#Intent;end',
      ' javascript:alert(1)',
      'https://claude.ai:443/',
      'https://claude.ai./x',
      'https://evil.example/',
      'jav\tascript:alert(1)',
    ]) {
      // ignore: avoid_print
      print('nav $t => ${decideGameNavigation(origins: o, target: t, isMainFrame: true)}');
    }
  });
}
