// The owner's rule of 2026-10-16, on top of the switch he got the night
// before:
//
//   «لازم ما يبعت أبدًا صحتي ولا أدويتي ولا أكلي ولا عيلتي حتى وهو شغّال،
//    مع اختبار بيثبت هيك»
//
// So this is the proof: his switch ON, a key saved, and a database with
// real rows in every area – medication and a dose he answered, pain, a
// condition, a food he logged, a meal plan, a food rule he wrote, a person
// and a contact log, and a debt in that person's name – then the chat is
// driven the way he drives it (type, Send, the real summary preview, "use
// and send"), and the assertions are on the **bytes handed to the
// transport**, not on any helper's return value. Nothing about how the
// prompt is assembled can slip past that.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/ai_chat/ai_chat.dart';
import 'package:madar/features/ai_chat/domain/system_prompt.dart';
import 'package:madar/features/ai_chat/presentation/ai_labels.dart';
import 'package:madar/features/ai_chat/presentation/widgets/composer.dart';
import 'package:madar/features/data/data.dart' show ChatSummaryScope, ExportPreviewSheet, SummarySectionId;

import '../data/data_fixtures.dart' show seedSummaryScenario;
import 'ai_chat_fakes.dart';
import 'ai_chat_harness.dart';

const _keys = {'madar.ai.anthropic.apiKey.v1': testAnthropicKey};

Future<L10n> _l10n(String lang) => L10n.delegate.load(Locale(lang));

/// The four things he named, each in words that appear nowhere else, on top
/// of the shared "every area" scenario (`seedSummaryScenario`, which already
/// fills faith, health, money, family, work, growth, body, travel and his
/// custom trackers with his own Arabic words).
Future<void> _seedHisLife(MadarDatabase db) async {
  await seedSummaryScenario(db, lang: 'ar');
  final repos = Repositories(db);

  // His medication, and a dose he answered.
  await repos.conditions.insert(ConditionsCompanion.insert(id: const Value('c-pressure'), name: 'ارتفاع الضغط'));
  await repos.medications.insert(
    MedicationsCompanion.insert(
      id: const Value('m-amox'),
      name: 'أموكسيسيلين',
      dose: const Value('625 ملغ'),
      times: const Value(['14:00']),
      takenWith: const Value(TakenWith.lunch),
    ),
  );
  await repos.medDoses.insert(
    MedDosesCompanion.insert(
      medicationId: 'm-amox',
      scheduledAt: Value(DateTime(2026, 9, 29, 14)),
      takenAt: Value(DateTime(2026, 9, 29, 14, 20)),
      status: DoseStatus.taken,
      dose: const Value('625 ملغ'),
    ),
  );
  await repos.painEntries.insert(
    PainEntriesCompanion.insert(
      at: DateTime(2026, 9, 29, 20),
      score: 7,
      locations: const Value(['الكتف الأيمن']),
      triggers: const Value(['حمل الأغراض']),
    ),
  );

  // His food: the library, the log, the plan and the rule he wrote himself.
  await repos.foods.insert(
    FoodsCompanion.insert(
      id: const Value('f-mulukhiyah'),
      name: 'ملوخية خضراء',
      tags: const Value(['أكل بيتي', 'ملح عالي']),
    ),
  );
  await repos.foodLogs.insert(
    FoodLogsCompanion.insert(
      foodId: const Value('f-mulukhiyah'),
      name: 'ملوخية خضراء',
      at: DateTime(2026, 9, 29, 13),
      tags: const Value(['غدا الجمعة']),
    ),
  );
  await repos.mealPlans.insert(
    MealPlansCompanion.insert(id: const Value('p-summer'), name: 'خطة الصيف', active: const Value(true)),
  );
  await repos.mealSlots.insert(
    MealSlotsCompanion.insert(id: const Value('s-breakfast'), planId: 'p-summer', name: 'فطور الصبح', timeMinutes: 450),
  );
  await repos.mealSlotFoods.insert(
    MealSlotFoodsCompanion.insert(slotId: 's-breakfast', foodId: const Value('f-mulukhiyah'), name: 'ملوخية خضراء'),
  );
  await repos.foodRules.insert(
    FoodRulesCompanion.insert(
      conditionId: const Value('c-pressure'),
      target: const Value(FoodRuleTarget.tag),
      tag: const Value('ملح عالي'),
      weight: const Value(RiskWeight.high),
    ),
  );

  // His family, and a debt that carries one of their names.
  await repos.people.insert(
    PeopleCompanion.insert(
      id: const Value('p-aunt'),
      name: 'خالتي نجاح',
      relation: const Value('خالة'),
      rhythmDays: const Value(14),
      createdAt: Value(DateTime(2026, 1, 1)),
    ),
  );
  await repos.contactLogs.insert(
    ContactLogsCompanion.insert(personId: 'p-aunt', at: DateTime(2026, 9, 27, 19)),
  );
  await repos.debts.insert(
    DebtsCompanion.insert(
      direction: DebtDirection.iOwe,
      person: 'خالتي نجاح',
      amountMilli: 75000,
      currency: 'JOD',
    ),
  );
}

/// Every word of his health, his medication, his food and his family that
/// the chat must never carry – the rows above and the shared scenario's.
const _private = <String, String>{
  // Medication and doses.
  'medication name': 'أموكسيسيلين',
  'medication name (scenario)': 'ميتفورمين',
  'supplement (scenario)': 'فيتامين د',
  'dose': '625 ملغ',
  'dose (scenario)': '500 mg',
  // Conditions, alerts, labs, pain.
  'condition': 'ارتفاع الضغط',
  'condition (scenario)': 'ربو',
  'standing alert (scenario)': 'لا كورتيزون',
  'lab test (scenario)': 'HbA1c',
  'pain place': 'الكتف الأيمن',
  'pain trigger': 'حمل الأغراض',
  // Food.
  'food': 'ملوخية خضراء',
  'food tag': 'أكل بيتي',
  'food tag (rule)': 'ملح عالي',
  'entry tag': 'غدا الجمعة',
  'meal plan': 'خطة الصيف',
  'meal slot': 'فطور الصبح',
  // Body.
  'exercise (scenario)': 'قرفصاء',
  'avoided thing (scenario)': 'القرفصاء العميقة',
  // Family – the person, the relation, and the debt in their name.
  'person': 'خالتي نجاح',
  'relation': 'خالة',
  'person (scenario)': 'أخي أحمد',
  'person (scenario, 2)': 'سامي',
};

/// Taps the sheet button whose label is [label] (the preview's footer).
Future<void> _tapLabel(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target.first);
  await frames(tester, 4);
  await tester.tap(target.first);
}

void main() {
  testWidgets('switch ON, key saved, every area filled: the request carries none of the four', (tester) async {
    usePhone(tester);
    final l = await _l10n('ar');
    final transport = FakeTransport([
      FakeReply.sse([anthropicSse(['تمام.'])]),
    ]);
    final (app, env) = await buildAiApp(
      tester,
      home: const AiChatScreen(),
      locale: const Locale('ar'),
      keys: _keys,
      // His own switch is ON – this is the case he worried about.
      transport: transport,
      realPicker: true,
      beforePump: _seedHisLife,
    );
    await tester.pumpWidget(app);
    await settleAsync(tester);
    await frames(tester, 10);

    await tester.enterText(find.byKey(ChatComposer.fieldKey), 'كيف كان أسبوعي؟');
    await tester.pump();
    await tester.tap(find.byKey(ChatComposer.sendKey));
    await frames(tester, 6);
    await settleAsync(tester, rounds: 16);
    await frames(tester, 10);

    // The real preview opened, and nothing has been sent yet.
    expect(find.byType(ExportPreviewSheet), findsOneWidget);
    expect(transport.requests, isEmpty);

    // He approves everything the preview offers – no trimming at all.
    await _tapLabel(tester, l.aiChatContextUseAndSend);
    await frames(tester, 6);
    await settleAsync(tester, rounds: 10);
    await frames(tester, 10);

    // The bytes that went to the service.
    expect(transport.requests, hasLength(1));
    final request = transport.requests.single;
    expect(request.url.host, 'api.anthropic.com');
    final bytes = utf8.encode(request.body!);
    final sent = utf8.decode(bytes);

    for (final MapEntry(key: what, value: secret) in _private.entries) {
      expect(sent.contains(secret), isFalse, reason: 'the request body carries his $what ("$secret")');
    }
    // The headings of the three sections, in both languages.
    for (final heading in ChatContextFilter.forbiddenSections) {
      expect(sent.contains('## $heading'), isFalse, reason: 'a "$heading" section went out');
    }

    // It really did carry a summary – the proof above is not a sent-nothing
    // accident.
    final body = jsonDecode(sent) as Map<String, Object?>;
    final system = body['system']! as String;
    expect(system, contains(AiSystemPrompt.contextStart));
    expect(system, contains('## ${l.dataSumFaith}'), reason: 'the areas he may share did go out');
    expect(system, contains('## ${l.dataSumMoney}'));
    expect(system, contains('## ${l.dataSumWork}'));
    expect(jsonEncode(body['messages']), contains('كيف كان أسبوعي؟'));

    // Money went out, but the debt's other side is a person of his.
    expect(system, contains(l.dataSumDebtsTitle));
    expect(system, contains('75.000 JOD'));

    // The conversation stored with it (the approved summary included)
    // cannot bring any of it back on a later Send either. His own
    // medication, food and family rows of course stay in his database –
    // that is the whole point: they live on the phone.
    final rows = await tester.runAsync(
      () => env.db.customSelect("SELECT key, value FROM key_values WHERE key LIKE 'aiChat.%'").get(),
    );
    expect(rows, isNotEmpty, reason: 'the conversation is stored');
    final dump = rows!.map((r) => r.read<String>('value')).join('\n');
    for (final MapEntry(key: what, value: secret) in _private.entries) {
      expect(dump.contains(secret), isFalse, reason: 'the stored chat carries his $what ("$secret")');
    }
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('[$lang] the preview does not offer what it cannot send, and says what is left out', (tester) async {
      usePhone(tester);
      final l = await _l10n(lang);
      final (app, _) = await buildAiApp(
        tester,
        home: const AiChatScreen(),
        locale: Locale(lang),
        keys: _keys,
        realPicker: true,
        beforePump: _seedHisLife,
      );
      await tester.pumpWidget(app);
      await settleAsync(tester);
      await frames(tester, 10);
      await tester.enterText(find.byKey(ChatComposer.fieldKey), 'hi');
      await tester.pump();
      await tester.tap(find.byKey(ChatComposer.sendKey));
      await frames(tester, 6);
      await settleAsync(tester, rounds: 16);
      await frames(tester, 10);
      expect(find.byType(ExportPreviewSheet), findsOneWidget, reason: lang);

      // The three sections are not offered – no switch, not even a
      // disabled row.
      for (final id in ChatSummaryScope.forbidden) {
        final title = l.summaryTitles()[id]!;
        expect(find.text(title), findsNothing, reason: '[$lang] "$title" is offered in the chat preview');
      }
      // What he may share is still there.
      expect(find.text(l.dataSumFaith), findsOneWidget, reason: lang);
      expect(find.text(l.dataSumMoney), findsOneWidget, reason: lang);

      // And the sheet says, before he looks for them, that they never go.
      expect(find.byKey(ExportPreviewSheet.excludedNote), findsOneWidget, reason: lang);
      expect(find.text(l.dataSummaryChatExcluded), findsOneWidget, reason: lang);
    });
  }

  test('the two scopes are the whole document, and the headings follow the strings', () async {
    expect(ChatSummaryScope.forbidden.intersection(ChatSummaryScope.allowed), isEmpty);
    expect({...ChatSummaryScope.forbidden, ...ChatSummaryScope.allowed}, SummarySectionId.values.toSet());
    expect(ChatSummaryScope.filter(SummarySectionId.values), ChatSummaryScope.allowed);

    // The text tables of the last gate must stay equal to the summary's own
    // headings: renaming one in the string files fails here instead of
    // quietly opening a hole.
    for (final lang in ['ar', 'en']) {
      final l = await _l10n(lang);
      for (final id in ChatSummaryScope.forbidden) {
        expect(
          ChatContextFilter.forbiddenSections,
          contains(l.summaryTitles()[id]!),
          reason: '[$lang] ${id.name}: "${l.summaryTitles()[id]}" is not in the filter',
        );
      }
      for (final sub in [
        l.dataSumAlertsTitle,
        l.dataSumConditionsTitle,
        l.dataSumMedsTitle,
        l.dataSumLabsTitle,
        l.dataSumPainTitle,
        l.dataSumMoodTitle,
        l.dataSumAvoidTitle,
        l.dataSumExercisePlanTitle,
        l.systemShellSumFoodTitle,
        l.systemShellSumMealPlanTitle('س'),
        l.systemShellSumFoodRulesTitle,
      ]) {
        expect(ChatContextFilter.isForbiddenSubSection(sub), isTrue, reason: '[$lang] "$sub"');
      }
    }
  });

  group('ChatContextFilter (the last gate, whatever a conversation carries)', () {
    const clean = '# ملخّص مَدار — 2026-09-30\n\nمقدّمة\n\n## الإيمان\n\n- تمام\n\n## المال\n\n- تمام\n';

    test('a document with nothing forbidden comes back byte for byte', () {
      expect(ChatContextFilter.sanitize(clean), clean);
      expect(ChatContextFilter.hasForbidden(clean), isFalse);
    });

    test('a section the chat may not carry is cut, with everything under it', () {
      const md =
          '# ملخّص\n\nمقدّمة\n\n## الإيمان\n\n- تمام\n\n## الصحة\n\n### الأدوية الحالية\n'
          '- أموكسيسيلين · 625 ملغ\n\n### الألم (متابعة)\n- 7/10\n\n## المال\n\n- تمام\n';
      final out = ChatContextFilter.sanitize(md);
      expect(out, isNot(contains('الصحة')));
      expect(out, isNot(contains('أموكسيسيلين')));
      expect(out, isNot(contains('625 ملغ')));
      expect(out, isNot(contains('7/10')));
      expect(out, contains('## الإيمان'));
      expect(out, contains('## المال'));
      expect(RegExp(r'^## ', multiLine: true).allMatches(out).length, 2);
    });

    test('food and medication sub-sections are cut even from a section that may travel', () {
      const md = '# ملخّص\n\n## المال\n\n- تمام\n\n### الأكل (متابعة)\n- ملوخية خضراء\n\n### خطة الوجبات «خطة الصيف»\n- فطور\n';
      final out = ChatContextFilter.sanitize(md);
      expect(out, contains('## المال'));
      expect(out, contains('- تمام'));
      expect(out, isNot(contains('ملوخية')));
      expect(out, isNot(contains('خطة الصيف')));
      expect(out, isNot(contains('الأكل (متابعة)')));
    });

    test('English documents are cut the same way', () {
      const md = '# Madar summary\n\n## Health\n\n- Metformin\n\n## Family\n\n- Mother\n\n## Body\n\n- Squats\n\n## Faith\n\n- ok\n';
      final out = ChatContextFilter.sanitize(md);
      expect(out, '# Madar summary\n\n## Faith\n\n- ok');
    });

    test('nothing left but the header: the request carries no context at all', () {
      expect(ChatContextFilter.sanitize('# Madar summary\n\n## Health\n\n- Metformin\n'), '');
      expect(ChatContextFilter.sanitize('## الصحة\n\n- سرّي'), '');
    });

    test('the system prompt drops it even when the conversation was approved elsewhere', () {
      // A context no screen can produce any more (an older version, a
      // restored backup, a screen written later).
      const md = '# Madar summary\n\n## Health\n\n- Metformin 500 mg\n\n## Money\n\n- ok';
      final system = AiSystemPrompt.build(
        languageCode: 'en',
        context: const ChatContext.personal(md),
      );
      expect(system, isNot(contains('Metformin')));
      expect(system, isNot(contains('## Health')));
      expect(system, contains('## Money'));
      expect(system, contains(AiSystemPrompt.contextStart));

      // And one that is nothing but health: no context block at all.
      final onlyHealth = AiSystemPrompt.build(
        languageCode: 'ar',
        context: const ChatContext.personal('## الصحة\n\n- أموكسيسيلين'),
      );
      expect(onlyHealth, isNot(contains('أموكسيسيلين')));
      expect(onlyHealth, isNot(contains(AiSystemPrompt.contextStart)));
      expect(onlyHealth, contains('chose not to share'));
    });

    test('the strip and the preview never name a section the request will not carry', () {
      const ctx = ChatContext.personal('# م\n\n## الصحة\n\n- سرّي\n\n## المال\n\n- تمام');
      expect(ctx.sectionTitles, ['المال']);
      expect(ctx.isPersonal, isTrue);
    });
  });
}
