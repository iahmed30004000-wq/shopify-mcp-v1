// The key never leaves secure storage: not the database (so not exports or
// backups), not logs, not shared preferences, not crash text, not the
// screen. Exercised through the real providers over a fake network.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/snapshot.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/ai_chat/presentation/widgets/composer.dart';
import 'package:madar/features/ai_chat/presentation/widgets/key_sheet.dart';
import 'package:madar/features/ai_chat/presentation/widgets/model_sheet.dart';
import 'package:madar/features/ai_chat/presentation/widgets/will_send_sheet.dart';
import 'package:madar/features/ai_chat/presentation/widgets/will_send_strip.dart';

import 'ai_chat_fakes.dart';
import 'ai_chat_harness.dart';

/// Distinctive parts of the test key that must never show up.
const _fragments = ['TESTKEY0123456789', 'api03-TESTKEY', testAnthropicKey];

void _expectClean(String where, String text) {
  for (final f in _fragments) {
    expect(text.contains(f), isFalse, reason: '$where contains the key');
  }
}

void main() {
  testWidgets('a full session never writes the key anywhere but secure storage', (tester) async {
    usePhone(tester);
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    final errors = <String>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      errors.add(d.toString());
      previousOnError?.call(d);
    };

    // Clipboard holds the key for the "Paste" button.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': '  $testAnthropicKey\n'};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final transport = FakeTransport([
      // Test key.
      FakeReply.json({'data': <Object>[], 'has_more': false}),
      // Refresh models.
      FakeReply.json({
        'data': [
          {'id': 'claude-sonnet-5-5', 'display_name': 'Claude Sonnet 5.5', 'type': 'model'},
        ],
      }),
      // First send: the service echoes the key in its error.
      FakeReply.json({
        'type': 'error',
        'error': {'type': 'invalid_request_error', 'message': 'Key $testAnthropicKey is not allowed here'},
      }, status: 400),
      // Try again: a streamed answer.
      FakeReply.sse([
        anthropicSse(['All good.']),
      ]),
    ]);

    try {
      await runZoned(() async {
        final (app, env) = await buildAiApp(tester, home: const AiChatScreen(), transport: transport);
        await tester.pumpWidget(app);
        await settleAsync(tester);

        // Paste + save the key.
        await tester.tap(find.text('Add Anthropic key'));
        await frames(tester, 12);
        await tester.tap(find.byKey(AiKeySheet.pasteKey));
        await frames(tester, 4);
        await tester.tap(find.byKey(AiKeySheet.saveKey));
        await settleAsync(tester, rounds: 4);
        // Test key (explicit tap).
        await tester.tap(find.byKey(AiKeySheet.testKey));
        await settleAsync(tester, rounds: 4);
        await frames(tester, 6);
        expect(find.text('The key works.'), findsOneWidget);
        Navigator.of(tester.element(find.byType(AiKeySheet))).pop();
        await frames(tester, 12);

        // Refresh models (explicit tap).
        await tester.tap(find.byKey(const ValueKey('ai-model-chip')));
        await frames(tester, 12);
        await tester.tap(find.byKey(ModelPickerSheet.refreshKey));
        await settleAsync(tester, rounds: 4);
        await frames(tester, 6);
        expect(find.text('1 model available'), findsOneWidget);
        Navigator.of(tester.element(find.byType(ModelPickerSheet))).pop();
        await frames(tester, 12);

        // No personal context, then send → error → try again.
        await tester.tap(find.byKey(WillSendStrip.stripKey));
        await frames(tester, 14);
        await tester.tap(find.byKey(WillSendSheet.noneSwitchKey));
        await frames(tester, 4);
        await tester.tap(find.text('Done').last);
        await frames(tester, 12);
        await tester.enterText(find.byKey(ChatComposer.fieldKey), 'Hello');
        await tester.pump();
        await tester.tap(find.byKey(ChatComposer.sendKey));
        await settleAsync(tester, rounds: 6);
        await frames(tester, 8);
        expect(find.textContaining('is not allowed here'), findsOneWidget, reason: 'the redacted detail is shown');
        // A rejected request is not offered for retry: ask again.
        expect(find.text('Try again'), findsNothing);
        await tester.enterText(find.byKey(ChatComposer.fieldKey), 'Hello again');
        await tester.pump();
        await tester.tap(find.byKey(ChatComposer.sendKey));
        await settleAsync(tester, rounds: 6);
        await frames(tester, 8);
        expect(find.text('All good.'), findsOneWidget);

        // Every request carried the key only in its auth header.
        expect(transport.requests.length, 4);
        for (final r in transport.requests) {
          expect(r.headers['x-api-key'], testAnthropicKey);
          _expectClean('request body', r.body ?? '');
          _expectClean('request url', r.url.toString());
        }

        // Screen.
        for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
          _expectClean('screen text', t.text.toPlainText());
        }
        for (final t in tester.widgetList<EditableText>(find.byType(EditableText))) {
          _expectClean('text field', t.controller.text);
        }

        // Database = exports and backups.
        final snapshot = await tester.runAsync(() => exportSnapshot(env.db));
        final dump = jsonEncode(snapshot);
        expect(dump, contains('aiChat.'), reason: 'the conversation itself is stored');
        _expectClean('database snapshot', dump);

        // Shared preferences.
        _expectClean('shared preferences', jsonEncode({for (final k in env.prefs.getKeys()) k: '${env.prefs.get(k)}'}));

        // Secure storage holds it – and only there.
        expect(env.secrets.values, {AiKeyStore.storageKey(AiProviderId.anthropic): testAnthropicKey});
      }, zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => logs.add(line)));
    } finally {
      // Restored before the binding checks its debug variables.
      debugPrint = previousDebugPrint;
      FlutterError.onError = previousOnError;
    }

    _expectClean('logs', logs.join('\n'));
    _expectClean('flutter errors', errors.join('\n'));
    expect(tester.takeException(), isNull);
  });

  test('exception text never carries provider details', () {
    const e = AiException(AiErrorKind.badRequest, statusCode: 400, detail: 'secret sk-ant-api03-abc');
    expect(e.toString(), 'AiException(badRequest, HTTP 400)');
    expect(AiRedactor.redact('Incorrect API key provided: sk-proj-abcd****WXYZ.'), isNot(contains('sk-proj')));
    expect(AiRedactor.redact('bad $testAnthropicKey!', secrets: [testAnthropicKey]), 'bad ••••!');
  });
}
