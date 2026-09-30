/// The system prompt of every AI call: language, tone, the health boundary
/// and – only when the user approved it – their Madar summary. Pure Dart.
library;

import 'conversation.dart';

abstract final class AiSystemPrompt {
  /// Markers around the personal context (plain text the model can see).
  static const String contextStart = '<<<MADAR_CONTEXT';
  static const String contextEnd = 'MADAR_CONTEXT>>>';

  /// The complete system prompt for a conversation in [languageCode] ('ar'
  /// or 'en') with [context].
  static String build({required String languageCode, required ChatContext context}) {
    final fallback = languageCode == 'ar' ? 'Arabic' : 'English';
    final b = StringBuffer()
      ..writeln('You are the assistant inside Madar, a private personal life app. The user brought their own API key.')
      ..writeln()
      ..writeln('How to answer:')
      ..writeln(
        '- Reply in the language of the user\'s latest message (Arabic or English, matching their dialect '
        'where natural). If it is unclear, reply in $fallback.',
      )
      ..writeln('- Be concise, warm and practical: short paragraphs or a brief list. Use Markdown sparingly.')
      ..writeln(
        '- You are not a clinician. Never give a medical diagnosis, never interpret symptoms or lab results as a '
        'diagnosis, and never recommend starting, stopping or changing a treatment, medication or dose. For '
        'health questions you may describe what the user has tracked and suggest they ask their clinician.',
      )
      ..writeln('- If you do not know something or it is not in the context, say so instead of guessing.');
    if (context.isPersonal) {
      b
        ..writeln(
          '- The user chose to share the summary below from Madar. It is private: use it only where it helps '
          'the question, and do not repeat it back in full.',
        )
        ..writeln()
        ..writeln(contextStart)
        ..writeln(context.markdown!.trimRight())
        ..write(contextEnd);
    } else {
      b.write('- The user chose not to share personal context from Madar for this conversation.');
    }
    return b.toString();
  }
}

/// Spots replies that talk about health, so the chat can add its small
/// "not medical advice" note. Keyword based (whole words), Arabic and
/// English.
abstract final class HealthMentions {
  static final RegExp _en = RegExp(
    r'\b(health|healthy|medical|medicines?|medications?|doses?|dosage|symptoms?|diagnos\w*|doctors?|clinicians?|'
    r'physicians?|pain|painful|blood pressure|glucose|blood sugar|cholesterol|lab (results?|tests?)|hemoglobin|'
    r'vitamins?|pills?|treatments?|therap(y|ies)|diseases?|illness(es)?|infections?|fever|headaches?|migraines?|'
    r'insulin|diabet\w*|pregnan\w*|prescri\w*|\d+ ?mg)\b',
    caseSensitive: false,
  );

  /// Arabic stems (normalised spelling), matched as whole words with the
  /// usual prefixes (و ف ب ل ك، ال) and pronoun suffixes.
  static const List<String> _arStems = [
    'صحة',
    'صحي',
    'صحية',
    'طبي',
    'طبية',
    'طبيب',
    'طبيبة',
    'دكتور',
    'دواء',
    'ادوية',
    'علاج',
    'جرعة',
    'جرعات',
    'اعراض',
    'تشخيص',
    'الم',
    'الام',
    'وجع',
    'اوجاع',
    'ضغط الدم',
    'سكر الدم',
    'السكري',
    'سكري',
    'كوليسترول',
    'تحاليل',
    'تحليل الدم',
    'فيتامين',
    'فيتامينات',
    'حبوب',
    'مرض',
    'امراض',
    'مريض',
    'عدوي',
    'حمي',
    'صداع',
    'انسولين',
    'وصفة طبية',
  ];

  static final RegExp _ar = RegExp(
    '(?<![\\p{L}])(?:و|ف|ب|ل|ك)?(?:ال|لل)?(?:${_arStems.join('|')})(?:ا|ك|كم|ه|ها|هم|نا|ي)?(?![\\p{L}])',
    unicode: true,
  );

  /// Whether [text] mentions health topics.
  static bool mentions(String text) => _en.hasMatch(text) || _ar.hasMatch(normalizeArabic(text));

  /// Folds Arabic spelling variants: harakat and tatweel dropped, alef
  /// forms → ا, ى → ي, ة → ة (kept), ه at a word end left alone.
  static String normalizeArabic(String s) => s
      .replaceAll(RegExp('[ً-ٰٟـ]'), '')
      .replaceAll(RegExp('[آأإٱ]'), 'ا')
      .replaceAll('ى', 'ي');
}
