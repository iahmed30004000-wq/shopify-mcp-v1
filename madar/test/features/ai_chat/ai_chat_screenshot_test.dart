@Tags(['screenshot'])
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/ai_chat/presentation/widgets/composer.dart';
import 'package:madar/features/ai_chat/presentation/widgets/key_sheet.dart';
import 'package:madar/features/ai_chat/presentation/widgets/model_sheet.dart';
import 'package:madar/features/ai_chat/presentation/widgets/will_send_sheet.dart';
import 'package:madar/features/ai_chat/presentation/widgets/will_send_strip.dart';

import '../../helpers/screenshot_harness.dart';
import 'ai_chat_fakes.dart';
import 'ai_chat_harness.dart';

const _keys = {'madar.ai.anthropic.apiKey.v1': testAnthropicKey};

String _summary(String lang) => lang == 'ar'
    ? '# ملخّص مَدار – 2026-09-30\n\nملخّص شخصي اختار صاحبه مشاركته.\n\n## الإيمان\n\n- الصلوات: 34/35 خلال 7 أيام\n\n'
          '## الصحة\n\n- الألم: متوسط 3/10\n\n## المال\n\n- الميزانية: صُرف 62% من الشهر'
    : '# Madar summary – 2026-09-30\n\nA personal summary the user chose to share.\n\n## Faith\n\n- Prayers: 34/35 in 7 days\n\n'
          '## Health\n\n- Pain: 3/10 average\n\n## Money\n\n- Budget: 62% of the month spent';

String _question(String lang) => lang == 'ar'
    ? 'كيف كان أسبوعي؟ وما الذي أركّز عليه غدًا؟'
    : 'How was my week, and what should I focus on tomorrow?';

String _answer(String lang) => lang == 'ar'
    ? '''أسبوعك كان **متوازنًا** في أغلبه:

- الصلاة: ٣٤ من ٣٥ في وقتها تقريبًا — أحسنت.
- المال: صرفت 62% من ميزانية الشهر، وبقي 11 يومًا.
- الألم: متوسط 3/10، وهذا للمتابعة فقط؛ ناقشه مع طبيبك إن استمر.

## غدًا

1. ابدأ بعد الفجر بمهمة **التقرير** (45 دقيقة).
2. مشي 20 دقيقة بعد العصر.

| البند | المتبقي |
|:--|--:|
| الطعام | 120 JOD |
| المواصلات | 35 JOD |

Tip: try the *Pomodoro* method for the report.'''
    : '''Your week was mostly **steady**:

- Prayer: 34 of 35 on time — well done.
- Money: 62% of the month's budget spent with 11 days left.
- Pain: 3/10 on average. That's for tracking only; mention it to your clinician if it continues.

## Tomorrow

1. After Fajr, start the **report** (45 min).
2. A 20-minute walk after Asr.

| Item | Left |
|:--|--:|
| Food | 120 JOD |
| Transport | 35 JOD |

`Tip:` keep evenings light — ليلة هادئة.''';

Future<void> _seedConversation(MadarDatabase db, String lang, {bool failed = false, bool link = false}) async {
  final t = aiTestNow;
  await ConversationStore(db).save(
    Conversation(
      id: 'c1',
      createdAt: t,
      updatedAt: t,
      title: lang == 'ar' ? 'مراجعة الأسبوع' : 'Weekly review',
      context: ChatContext.personal(_summary(lang), approvedAt: t),
      messages: [
        ChatMessage(id: 'u1', role: ChatRole.user, text: _question(lang), createdAt: t),
        ChatMessage(
          id: 'a1',
          role: ChatRole.assistant,
          text: link
              ? (lang == 'ar'
                    ? 'خطة المشي موضّحة في [هذا الدليل](https://walking.example.org/plan?week=39&pain=3) إن أردت التفاصيل.'
                    : 'The walking plan is in [this guide](https://walking.example.org/plan?week=39&pain=3) if you want details.')
              : _answer(lang),
          createdAt: t,
          provider: AiProviderId.anthropic,
          model: 'claude-sonnet-5-5',
        ),
        if (failed) ...[
          ChatMessage(
            id: 'u2',
            role: ChatRole.user,
            text: lang == 'ar' ? 'وماذا عن الشهر القادم؟' : 'And next month?',
            createdAt: t,
          ),
          ChatMessage(
            id: 'a2',
            role: ChatRole.assistant,
            text: '',
            createdAt: t,
            status: MessageStatus.failed,
            error: AiErrorKind.rateLimited,
            provider: AiProviderId.anthropic,
            model: 'claude-sonnet-5-5',
          ),
        ],
      ],
    ),
  );
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home, {
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  Map<String, String> keys = _keys,
  Future<void> Function(MadarDatabase db)? seed,
  void Function(AiTestEnv env)? script,
  Future<void> Function(WidgetTester tester, AiTestEnv env)? drive,
  int trailingFrames = 24,
  double textScale = 1,
}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final (app, env) = await buildAiApp(tester, home: home, theme: theme, locale: locale, keys: keys, beforePump: seed);
  script?.call(env);
  final scale = textScale == 1 ? '' : '_x${(textScale * 10).round()}';
  await captureScreen(
    tester,
    app,
    'ai_chat/${name}_${locale.languageCode}_${theme.name}$scale',
    trailingFrames: trailingFrames,
    beforeCapture: (t) async {
      await settleAsync(t);
      await drive?.call(t, env);
    },
  );
}

/// Every AI chat screen in [locale] / [theme] at [textScale].
void _scenes(Locale locale, MadarThemeId theme, {double textScale = 1}) {
  final lang = locale.languageCode;
  final tag = textScale == 1 ? '' : ' x$textScale';

  testWidgets('link sheet $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'link_sheet',
      const AiChatScreen(conversationId: 'c1'),
      locale: locale,
      theme: theme,
      textScale: textScale,
      seed: (db) => _seedConversation(db, lang, link: true),
      drive: (t, _) async {
        TextSpan? link;
        for (final r in t.widgetList<RichText>(find.byType(RichText))) {
          r.text.visitChildren((s) {
            if (s is TextSpan && s.recognizer is TapGestureRecognizer) link ??= s;
            return true;
          });
        }
        (link!.recognizer! as TapGestureRecognizer).onTap!();
        await frames(t, 16);
      },
    );
  });

  testWidgets('conversation $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'conversation',
      const AiChatScreen(conversationId: 'c1'),
      locale: locale,
      theme: theme,
      textScale: textScale,
      seed: (db) => _seedConversation(db, lang),
    );
  });

  testWidgets('empty chat $lang ${theme.name}$tag', (tester) async {
    await _shot(tester, 'empty', const AiChatScreen(), locale: locale, theme: theme, textScale: textScale);
  });

  testWidgets('setup $lang ${theme.name}$tag', (tester) async {
    await _shot(tester, 'setup', const AiChatScreen(), locale: locale, theme: theme, keys: const {}, textScale: textScale);
  });

  testWidgets('error $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'error',
      const AiChatScreen(conversationId: 'c1'),
      locale: locale,
      theme: theme,
      textScale: textScale,
      seed: (db) => _seedConversation(db, lang, failed: true),
    );
  });

  testWidgets('streaming $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'streaming',
      const AiChatScreen(conversationId: 'c1'),
      locale: locale,
      theme: theme,
      textScale: textScale,
      seed: (db) => _seedConversation(db, lang),
      script: (env) => env.anthropic.script('live'),
      drive: (t, env) async {
        await t.enterText(
          find.byKey(ChatComposer.fieldKey),
          lang == 'ar' ? 'اقترح خطة للجمعة' : 'Suggest a plan for Friday',
        );
        await t.pump();
        await t.tap(find.byKey(ChatComposer.sendKey));
        await frames(t, 6);
        env.anthropic.live.single.add(
          AiTextDelta(
            lang == 'ar'
                ? 'خطة هادئة ليوم الجمعة:\n\n- بعد الفجر: ورد القرآن\n- قبل الصلاة: '
                : 'A calm plan for Friday:\n\n- After Fajr: your Quran wird\n- Before Jumuah: ',
          ),
        );
        await frames(t, 4);
      },
    );
  });

  testWidgets('will-send sheet $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'will_send',
      const AiChatScreen(conversationId: 'c1'),
      locale: locale,
      theme: theme,
      textScale: textScale,
      seed: (db) => _seedConversation(db, lang),
      drive: (t, _) async {
        await t.enterText(
          find.byKey(ChatComposer.fieldKey),
          lang == 'ar' ? 'وماذا عن الادخار؟' : 'What about savings?',
        );
        await t.pump();
        await t.tap(find.byKey(WillSendStrip.stripKey));
        await frames(t, 16);
      },
    );
  });

  testWidgets('payload sheet $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'payload',
      const AiChatScreen(conversationId: 'c1'),
      locale: locale,
      theme: theme,
      textScale: textScale,
      seed: (db) => _seedConversation(db, lang),
      drive: (t, _) async {
        await t.enterText(
          find.byKey(ChatComposer.fieldKey),
          lang == 'ar' ? 'وماذا عن الادخار؟' : 'What about savings?',
        );
        await t.pump();
        await t.tap(find.byKey(WillSendStrip.stripKey));
        await frames(t, 16);
        await t.tap(find.byKey(WillSendSheet.payloadKey));
        await frames(t, 16);
      },
    );
  });

  testWidgets('key sheet $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'key_sheet',
      const AiSettingsScreen(),
      locale: locale,
      theme: theme,
      textScale: textScale,
      drive: (t, _) async {
        await frames(t, 10);
        await t.tap(find.byKey(AiSettingsScreen.keyRow(AiProviderId.anthropic)));
        await frames(t, 16);
        await t.tap(find.byKey(AiKeySheet.testKey));
        await settleAsync(t, rounds: 3);
      },
    );
  });

  testWidgets('model sheet $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'model_sheet',
      const AiChatScreen(),
      locale: locale,
      theme: theme,
      textScale: textScale,
      drive: (t, _) async {
        await t.tap(find.byKey(const ValueKey('ai-model-chip')));
        await frames(t, 16);
        await t.tap(find.byKey(ModelPickerSheet.refreshKey));
        await settleAsync(t, rounds: 3);
      },
    );
  });

  testWidgets('list $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'list',
      const AiChatListScreen(),
      locale: locale,
      theme: theme,
      textScale: textScale,
      seed: (db) async {
        await _seedConversation(db, lang);
        final store = ConversationStore(db);
        final titles = lang == 'ar'
            ? ['خطة رمضان', 'Budget في رمضان', 'أسئلة للطبيب']
            : ['Ramadan plan', 'Budget for Eid', 'Questions for my doctor'];
        for (var i = 0; i < titles.length; i++) {
          await store.save(
            Conversation(
              id: 'x$i',
              createdAt: aiTestNow,
              updatedAt: aiTestNow.subtract(Duration(days: i + 1, hours: 3)),
              title: titles[i],
              messages: [
                ChatMessage(id: 'xm$i', role: ChatRole.user, text: titles[i], createdAt: aiTestNow),
                ChatMessage(
                  id: 'xa$i',
                  role: ChatRole.assistant,
                  text: lang == 'ar' ? 'إليك خطة من ثلاث خطوات…' : 'Here is a three-step plan…',
                  createdAt: aiTestNow,
                ),
              ],
            ),
          );
        }
      },
    );
  });

  testWidgets('settings $lang ${theme.name}$tag', (tester) async {
    await _shot(tester, 'settings', const AiSettingsScreen(), locale: locale, theme: theme, textScale: textScale);
  });

  testWidgets('ask ai entry $lang ${theme.name}$tag', (tester) async {
    await _shot(
      tester,
      'ask_entry',
      MadarScaffold(
        title: lang == 'ar' ? 'الصحة' : 'Health',
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              AskAiEntry(area: lang == 'ar' ? 'صحتك' : 'your health'),
              const SizedBox(height: 12),
              const AskAiEntry(),
            ],
          ),
        ),
        actions: const [AskAiButton()],
      ),
      locale: locale,
      theme: theme,
      textScale: textScale,
    );
  });
}

void main() {
  final combos = [(const Locale('ar'), MadarThemeId.lapis), (const Locale('en'), MadarThemeId.pearl)];

  // Every screen at 100 % in the two main combinations, and at 130 % text
  // (a common accessibility setting; an overflow fails the test) in Arabic
  // on dark Aurora and English on light Pearl. Layout doesn't depend on the
  // theme; the full ar/en × Lapis/Pearl/Aurora set at 130 % was reviewed
  // once in the privacy/UX review – add combinations here to render it again.
  for (final (locale, theme) in combos) {
    _scenes(locale, theme);
  }
  for (final (locale, theme) in [(const Locale('ar'), MadarThemeId.aurora), (const Locale('en'), MadarThemeId.pearl)]) {
    _scenes(locale, theme, textScale: 1.3);
  }

  // Other themes, one screen each.
  for (final theme in [MadarThemeId.emerald, MadarThemeId.desert, MadarThemeId.aurora]) {
    testWidgets('conversation ar ${theme.name}', (tester) async {
      await _shot(
        tester,
        'conversation',
        const AiChatScreen(conversationId: 'c1'),
        theme: theme,
        seed: (db) => _seedConversation(db, 'ar'),
      );
    });
  }
  testWidgets('conversation en lapis (reduced width check)', (tester) async {
    await _shot(
      tester,
      'conversation',
      const AiChatScreen(conversationId: 'c1'),
      locale: const Locale('en'),
      seed: (db) => _seedConversation(db, 'en'),
    );
  });
}
