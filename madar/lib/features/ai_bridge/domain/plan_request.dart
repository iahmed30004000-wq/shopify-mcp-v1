/// The going-out half of the AI bridge: one JSON file that carries his
/// data **and** the prompt that tells any AI app what to do with it.
///
/// There is no account, no key and no network: Madar writes a file (or puts
/// the same text on the clipboard), he opens Gemini / ChatGPT / Claude
/// himself, drops the file in, and brings the answer back.
///
/// The prompt is machine-facing text, not UI text, so – like
/// `AiSystemPrompt` of the own-key chat – it lives in Dart and not in the
/// ARB files: it must stay byte-stable, it quotes JSON with digits in it
/// (which the ARB lint forbids on purpose), and no part of it is ever
/// rendered as an app string.
///
/// Pure Dart.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import 'plan_catalog.dart';
import 'plan_contract.dart';

/// Marker of the request envelope (`"madar": "request"`).
const String madarRequestMarker = 'request';

/// What his export carries, and what the AI must send back.
@immutable
class PlanRequest {
  const PlanRequest({
    required this.requestId,
    required this.generatedAt,
    required this.languageCode,
    required this.summaryMarkdown,
    required this.sections,
    required this.catalog,
    this.ask = '',
    this.omitted = const [],
  });

  /// A short id the answer may echo back, so an old answer is recognisable.
  final String requestId;
  final DateTime generatedAt;

  /// `ar` or `en`: the language of the prompt and of the answer we ask for.
  final String languageCode;

  /// The AI-ready summary exactly as he reviewed it in the export sheet.
  final String summaryMarkdown;

  /// Which sections of the summary went out (`faith`, `money` …).
  final List<String> sections;

  /// What he already has, so the AI names his own things.
  final PlanCatalog catalog;

  /// His own question in his own words ("شو أحسن شي أعمله الشهر الجاي؟").
  /// Empty unless he typed one.
  final String ask;

  /// What was deliberately left on the phone, stated so the AI does not
  /// invent it (see [PlanOmissions]).
  final List<String> omitted;

  bool get isArabic => languageCode == 'ar';

  /// The file's contents.
  Map<String, Object?> toJson() => {
    madarPlanMarkerKey: madarRequestMarker,
    'version': madarPlanVersion,
    'requestId': requestId,
    'generatedAt': planDay(generatedAt),
    'language': languageCode,
    if (ask.trim().isNotEmpty) 'ask': ask.trim(),
    'instructions': PlanPrompt.lines(this),
    'answerContract': PlanPrompt.contract(languageCode),
    'answerExample': PlanPrompt.exampleAnswer,
    'leftOutOnPurpose': omitted,
    'myThings': catalog.toJson(),
    'mySummary': summaryMarkdown,
  };

  /// Pretty JSON, as the file and the clipboard carry it.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// The clipboard form: the prompt first (so an AI chat that shows only
  /// the first lines still has its instructions), then the JSON.
  String asText() {
    final b = StringBuffer();
    for (final line in PlanPrompt.lines(this)) {
      b.writeln(line);
    }
    b
      ..writeln()
      ..writeln('```json')
      ..writeln(encode())
      ..writeln('```');
    return b.toString();
  }

  int get byteSize => utf8.encode(encode()).length;
}

/// The things Madar never sends, by name. The AI is told about them so it
/// does not fill the gap with guesses.
abstract final class PlanOmissions {
  /// Codes that travel in `leftOutOnPurpose`. They match what
  /// `AiSummaryBuilder` keeps on the phone.
  static const List<String> all = [
    'free-text notes',
    'journal and worry text',
    'pain and mood notes',
    'food and rule notes',
    'doctor answers',
    'phone numbers',
    'document numbers and holders',
    'account numbers',
    'exact wallet balances',
  ];
}

/// The prompt: what to analyse, and the exact shape of the answer.
abstract final class PlanPrompt {
  /// The instruction lines, in his language.
  static List<String> lines(PlanRequest r) => r.isArabic ? _arabic(r) : _english(r);

  static List<String> _arabic(PlanRequest r) => [
    'أنت مستشار شخصي بيقرأ ملف من تطبيق «مَدار».',
    'هذا الملف فيه خلاصة بيانات صاحب التطبيق بنفسه: صلاته، صحته، مصاريفه، أهله، شغله، تعلّمه، جسمه وسفره.',
    if (r.ask.trim().isNotEmpty) 'سؤاله بالنص: ${r.ask.trim()}',
    '',
    'المطلوب منك شغلتين:',
    '١) اقرأ البيانات وشوف شو بيتكرر وشو ناقص وشو بيتحسن وشو بيتعب.',
    '٢) ارجع بـ «خطة مدار»: ملف JSON واحد بالشكل المكتوب تحت، بدون أي كلام قبله أو بعده.',
    '',
    'قواعد لازمة:',
    '- كل اقتراح لازم يكون معه سبب من بياناته هو (reason). اقتراح بدون سبب التطبيق برفضه.',
    '- عنوان الاقتراح (title) سطر واحد قصير، لأنه بيصير بند بقائمة بيشطّبها بإيده (٦٠ حرف أو أقل، بدون نقطة).',
    '- الصحة: متابعة وممارسة فقط. ممنوع تشخيص، ممنوع علاج، ممنوع دواء، ممنوع جرعة، وممنوع تقول له يوقف أو يغيّر دوا. التطبيق برفض أي بند فيه هيك إشي.',
    '- لما تحكي عن مصروف أو أكل أو عادة، استعمل بالظبط الأسماء الموجودة في "myThings". ممنوع تخترع اسم مش موجود، لأن التطبيق برفضه.',
    '- اللي مكتوب في "leftOutOnPurpose" ما انبعت لك على قصد (ملاحظاته الشخصية مثلاً). لا تفترض محتواه ولا تعلّق عليه.',
    '- إذا مصدرك فيه ادّعاء كبير (مثل «بشفي ٩٩٪ من الأمراض») لا تبنيه خطة: حطّه في source.claimsFlagged كتنبيه.',
    '- إذا البيانات ما بتكفي لاقتراح، لا تخمّن. اقتراحات أقل وأصدق أحسن.',
    '- من ٣ لـ ١٢ اقتراح كحد أقصى، مرتبة من الأهم للأقل.',
    '',
    'شكل الجواب موصوف في "answerContract"، ومثال كامل صغير في "answerExample". التزم بنفس أسماء الحقول حرف بحرف، وأي حقل مش مذكور هناك لا تضيفه.',
    'ابعت JSON واحد فقط. بلا شرح، بلا مقدمة، بلا علامات اقتباس حوله.',
  ];

  static List<String> _english(PlanRequest r) => [
    'You are a personal adviser reading a file exported from the app "Madar".',
    'The file holds a summary of its owner\'s own data: prayers, health, money, family, work, learning, body and travel.',
    if (r.ask.trim().isNotEmpty) 'His question, in his words: ${r.ask.trim()}',
    '',
    'Do two things:',
    '1) Read the data and find what repeats, what is missing, what is improving and what is draining him.',
    '2) Answer with a "Madar plan": one JSON object in the shape described below, with no text before or after it.',
    '',
    'Rules:',
    '- Every suggestion must carry its reason, drawn from his own data ("reason"). A suggestion without a reason is rejected by the app.',
    '- Keep "title" to one short line (60 characters or fewer, no full stop): it becomes a line of a checklist he ticks off.',
    '- Health is tracking and practising only. No diagnosis, no treatment, no medicine, no dose, and never tell him to stop or change a medication. The app rejects any item like that.',
    '- When you name an envelope, a food, a habit or a tracker, use exactly the names given in "myThings". An invented name is rejected.',
    '- Everything listed in "leftOutOnPurpose" was deliberately not sent (his private notes, for instance). Do not assume what it says and do not comment on it.',
    '- If a source makes a big claim (for example "cures 99% of disease"), do not build a plan on it: put it in source.claimsFlagged as a warning.',
    '- If the data is not enough for a suggestion, do not guess. Fewer, truer suggestions are better.',
    '- Between 3 and 12 suggestions, most important first.',
    '',
    'The answer shape is in "answerContract" and a small complete example is in "answerExample". Use those field names exactly, and add no field that is not listed there.',
    'Send one JSON object only. No explanation, no preamble, no quotes around it.',
  ];

  /// The contract, as data the AI can read field by field.
  static Map<String, Object?> contract(String languageCode) => {
    'envelope': {
      madarPlanMarkerKey: 'plan (required, exactly this)',
      'version': '$madarPlanVersion (required integer)',
      'title': 'optional short name for the plan',
      'summary': 'optional, up to ${PlanLimits.maxSummaryLength} characters',
      'requestId': 'optional, copy it from this file so he can match answer to request',
      'generatedFor': 'optional day, yyyy-MM-dd',
      'source': {
        'kind': PlanSource.kinds.toList(),
        'title': 'optional',
        'url': 'optional http(s) link, never opened by the app',
        'completeness': 'optional: what the source did not cover',
        'claimsFlagged': 'optional list of claims to show as warnings, never applied',
      },
      'items': 'required list, 1 to ${PlanLimits.maxItems}',
    },
    'item': {
      'id': 'required, unique in this plan, letters/digits/._:- only',
      'kind': [for (final k in PlanItemKind.values) k.name],
      'title': 'required, one short line (<= ${PlanLimits.maxTitleLength} characters)',
      'reason': 'required, ${PlanLimits.minReasonLength} to ${PlanLimits.maxReasonLength} characters, from his data',
      'area': planAreas.toList(),
      'evidence': 'optional: the number of his it came from',
      'confidence': 'optional 0..1',
      'dependsOn': 'optional ids of items in this plan that must be applied first',
      'data': 'required object, keys per kind (below)',
    },
    'data': {
      'task': {
        'day': 'yyyy-MM-dd',
        'window': planWindows.toList(),
        'priority': '0..${PlanLimits.maxPriority}',
        'top3': 'true/false',
        'notes': 'optional',
        'repeat': {'every': planRepeats.toList(), 'weekdays': '1..7'},
        'projectRef': 'one of myThings.projects',
      },
      'habit': {
        'category': 'his own word',
        'planetKey': planAreas.toList(),
        'existingRef': 'one of myThings.habits, to switch an old habit back on',
      },
      'routine': {
        'times': 'required list of HH:mm, up to ${PlanLimits.maxRoutineTimes}',
        'weekdays': '1..7',
        'category': 'his own word',
        'steps': 'optional list of {title, note}, up to ${PlanLimits.maxRoutineSteps}',
      },
      'reminder': {
        'time': 'HH:mm (or "at" as a full date-time)',
        'repeat': ['day', 'week'],
        'weekdays': '1..7',
        'ownerRef': '{table: habits|custom_modules|learning_goals|meal_slots, id: one of myThings}',
      },
      'note': {'body': 'required, up to ${PlanLimits.maxNoteLength} characters'},
      'food': {
        'tags': 'up to ${PlanLimits.maxTags} of his own words',
        'portion': 'number > 0',
        'unit': 'his own unit word',
        'notes': 'optional',
      },
      'mealChange': {
        'op': planMealOps.toList(),
        'slotRef': 'one of myThings.mealSlots',
        'slotName': 'for op=newSlot',
        'time': 'HH:mm',
        'weekdays': '1..7',
        'foodRef': 'one of myThings.foods, or the id of a food item in this plan',
        'portion': 'number > 0',
        'unit': 'his own unit word',
        'planRef': 'one of myThings.mealPlans',
      },
      'avoidItem': {'note': 'optional'},
      'trackedSign': {'scale': planScales.toList(), 'everyDay': 'true/false', 'unit': 'optional'},
      'labTracker': {'unit': 'optional', 'low': 'number', 'high': 'number > low', 'category': 'optional'},
      'budgetTweak': {
        'envelopeRef': 'required, one of myThings.budgetItems',
        'newAmount': 'number >= 0 in his base currency (use this when the envelope is set by amount)',
        'newPercent': '0..100 (use this when the envelope is set by percentage)',
        'period': planPeriods.toList(),
        'currency': 'one of his currency codes',
      },
      'learningProgram': {
        'target': 'number > 0',
        'unit': 'his own unit word',
        'deadline': 'yyyy-MM-dd',
        'steps': 'list of {title, day, note}, up to ${PlanLimits.maxProgramSteps}',
      },
      'recipe': 'kept for the kitchen planet; shown, applied by a later version',
      'pantryItem': 'kept for the pantry; shown, applied by a later version',
    },
    'rejected': {
      'noReason': 'an item without "reason"',
      'invented': 'a name that is not in myThings',
      'medical': 'a diagnosis, a treatment, a medicine, a dose, or stopping / changing a medication',
      'unknownField': 'any key not listed here',
      'outOfRange': 'a number outside the range written here',
      'newerVersion': 'a version other than $madarPlanVersion',
    },
    'answerIn': languageCode,
  };

  /// One small complete answer, valid against the contract. It deliberately
  /// uses only kinds that need no reference, so it is correct for anyone.
  static const Map<String, Object?> exampleAnswer = {
    madarPlanMarkerKey: madarPlanMarker,
    'version': madarPlanVersion,
    'title': 'مثال قصير',
    'summary': 'مثال للشكل المطلوب فقط، مش اقتراح حقيقي.',
    'items': [
      {
        'id': 'h1',
        'kind': 'habit',
        'title': 'مشي عشر دقائق بعد العشا',
        'reason': 'بيانات المشي عندك فاضية بعد المغرب بـ ١٨ يوم من ٣٠.',
        'area': 'body',
        'confidence': 0.7,
        'data': {'category': 'حركة', 'planetKey': 'body'},
      },
      {
        'id': 't1',
        'kind': 'task',
        'title': 'راجع فاتورة الكهربا',
        'reason': 'آخر ثلاث فواتير كانت أعلى من المعدل بنسبة واضحة.',
        'area': 'money',
        'data': {'window': 'asr'},
      },
    ],
  };
}
