/// The last gate before a chat request is written: the personal context is
/// cut down to what may leave the phone, where the text is assembled.
///
/// The owner's rule of 2026-10-16: «لازم ما يبعت أبدًا صحتي ولا أدويتي ولا
/// أكلي ولا عيلتي حتى وهو شغّال» – even with his switch on, and whatever he
/// approved in the preview, his health, his medication, his food and his
/// family never leave the phone through the chat.
///
/// The first gate is structural and lives in the summary itself
/// (`ChatSummaryScope` + `AiSummaryBuilder(forChat: true)`): those sections
/// are never built for the chat, so there is nothing to choose or store.
/// This is the second gate, and it does not trust its caller: whatever
/// Markdown a conversation carries – approved by an older version of the
/// app, restored from a backup, or handed over by a screen written later –
/// every forbidden section and sub-section is dropped here, inside
/// `AiSystemPrompt.build`, the one place every request's text is put
/// together. A clean document comes back byte for byte.
///
/// The headings are matched by text because the context is plain Markdown
/// by the time it gets here. The tables below must stay equal to the
/// summary's own headings: `test/features/ai_chat/chat_scope_test.dart`
/// compares them against the generated strings in both languages, so renaming a heading
/// in the string files fails that test instead of opening a hole.
library;

abstract final class ChatContextFilter {
  /// `## ` headings of the sections that may never travel (health, family
  /// and body), in every language the app ships.
  static const List<String> forbiddenSections = [
    'الصحة', 'Health', // dataSumHealth
    'العائلة', 'Family', // dataSumFamily
    'الجسد', 'Body', // dataSumBody
  ];

  /// `### ` sub-headings of everything the three sections are made of –
  /// his medication, his conditions, his labs, his pain and mood, what he
  /// avoids, his exercise plan, his food log, his meal plan and his own
  /// food rules. Matched as a prefix, because the meal-plan heading
  /// carries the plan's name.
  static const List<String> forbiddenSubSections = [
    'تنبيهات دائمة', 'Standing alerts', // dataSumAlertsTitle
    'الحالات الصحية', 'Conditions', // dataSumConditionsTitle
    'الأدوية الحالية', 'Active medications', // dataSumMedsTitle
    'أحدث التحاليل', 'Recent labs', // dataSumLabsTitle
    'الألم (متابعة)', 'Pain (tracking)', // dataSumPainTitle
    'المزاج (متابعة)', 'Mood (tracking)', // dataSumMoodTitle
    'تجنّب', 'Avoid', // dataSumAvoidTitle
    'خطة التمارين', 'Exercise plan', // dataSumExercisePlanTitle
    'الأكل (متابعة)', 'Food (tracking)', // systemShellSumFoodTitle
    'خطة الوجبات', 'Meal plan', // systemShellSumMealPlanTitle (carries the name)
    'قواعدي للأكل', 'My own food rules', // systemShellSumFoodRulesTitle
  ];

  static bool isForbiddenSection(String heading) => forbiddenSections.contains(heading.trim());

  static bool isForbiddenSubSection(String heading) {
    final h = heading.trim();
    return forbiddenSubSections.any((f) => h == f || h.startsWith(f));
  }

  /// Whether [markdown] carries anything the chat may not send.
  static bool hasForbidden(String markdown) => sanitize(markdown) != markdown;

  /// [markdown] without the forbidden sections and sub-sections. A
  /// document that carries none of them is returned unchanged (byte for
  /// byte, so what he approved is what goes out); when nothing is left,
  /// the result is empty and the request carries no context at all.
  static String sanitize(String markdown) {
    if (markdown.isEmpty) return markdown;
    final out = <String>[];
    var dropped = false;
    // Inside a forbidden `## ` section / a forbidden `### ` sub-section.
    var inSection = false, inSub = false;
    for (final line in markdown.split('\n')) {
      if (line.startsWith('## ')) {
        inSection = isForbiddenSection(line.substring(3));
        inSub = false;
      } else if (line.startsWith('### ')) {
        inSub = isForbiddenSubSection(line.substring(4));
      }
      if (inSection || inSub) {
        dropped = true;
        continue;
      }
      out.add(line);
    }
    if (!dropped) return markdown;
    final text = out.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight();
    // Only the document's own header left: nothing of his is in there.
    return RegExp(r'^## ', multiLine: true).hasMatch(text) ? text : '';
  }
}
