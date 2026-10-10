/// # «خطة مدار» – the Madar plan contract, version 1
///
/// The answer half of the AI bridge (Part 3). Madar hands any AI app one
/// JSON file plus a ready prompt ([PlanRequest] / [PlanPrompt]); the AI
/// answers with **one JSON object in this shape**, which comes back to the
/// phone as a file, a share intent or a paste. No login, no API key, no
/// network anywhere in this feature.
///
/// Everything here is pure Dart: no Flutter, no database, no file system.
/// The validator ([PlanValidator]) is the only gate, and it is strict on
/// purpose – a plan that cannot be trusted item by item must never reach
/// his data.
///
/// ## The envelope
///
/// ```json
/// {
///   "madar": "plan",            // REQUIRED, exactly this
///   "version": 1,               // REQUIRED, integer, must be 1
///   "title": "خطة أسبوع الهدوء", // optional, ≤ 120 chars
///   "summary": "…",             // optional, ≤ 1000 chars, plain language
///   "requestId": "…",           // optional, echo of the request's id
///   "generatedFor": "2026-10-10",// optional, ISO day (yyyy-MM-dd)
///   "source": { … },            // optional, see below
///   "items": [ … ]              // REQUIRED, 1‥200 items
/// }
/// ```
///
/// A validator **rejects the whole payload** (nothing to review) when:
///
/// * it is not JSON, or not a JSON object  → `notJson` / `notAnObject`;
/// * `madar` is missing or is not `"plan"` → `notAMadarPlan`. This is the
///   marker that tells an AI plan apart from a Madar data export, a
///   prototype export or any other file he may share by mistake;
/// * `version` is missing, not an integer, or not 1 → `unsupportedVersion`.
///   Forward compatibility is deliberate and loud: a future Madar reads
///   version 2, this one says so in plain Arabic instead of guessing;
/// * the text is larger than [maxPayloadBytes] (2 MiB) → `tooBig`, or
///   nested deeper than [maxDepth] (12) → `tooDeep`. A plan is a short list
///   of suggestions; a 5 MB file is either a data dump or an attack;
/// * `items` is missing, is not a list, or is empty → `noItems`;
/// * `items` holds more than [maxItems] (200) entries → `tooManyItems`;
/// * any top-level key is not one of the keys above → `unknownField`.
///   Strictness here is what stops free text we never sent from riding back
///   in: a payload carrying `"painNotes"` or `"quotedNote"` is refused
///   rather than silently ignored.
///
/// ### `source` (optional, for Part 6's "learn from a source")
///
/// ```json
/// "source": {
///   "kind": "video",            // video | article | channel | book | chat | other
///   "title": "…",               // optional, ≤ 160
///   "url": "https://…",         // optional, ≤ 400, http/https only, never fetched
///   "completeness": "…",        // optional, ≤ 300: what the source did NOT cover
///   "claimsFlagged": ["…", "…"] // optional, ≤ 20 × ≤ 300: claims to show, never apply
/// }
/// ```
///
/// `claimsFlagged` is how an over-claiming source ("this cures 99 % of
/// chronic disease") is carried honestly: Madar shows the claim as a
/// warning beside the plan and never turns it into an item.
///
/// ## An item
///
/// ```json
/// {
///   "id": "h1",                 // REQUIRED, unique in the plan, ≤ 64, [A-Za-z0-9_.:-]
///   "kind": "habit",            // REQUIRED, one of PlanItemKind
///   "title": "نوم قبل منتصف الليل", // REQUIRED, 1‥120 chars, ONE short line
///   "reason": "…",              // REQUIRED, 3‥500 chars – why, from HIS data
///   "area": "health",           // optional planet key: faith|health|money|family|
///                               //   work|growth|body|travel
///   "evidence": "…",            // optional, ≤ 300: which of his own numbers it came from
///   "confidence": 0.8,          // optional number 0‥1
///   "dependsOn": ["f1"],        // optional item ids of THIS plan that must be applied first
///   "data": { … }               // REQUIRED object, keys per kind (below)
/// }
/// ```
///
/// The validator **rejects that one item** (the rest of the plan stays
/// reviewable) when:
///
/// * `id` is missing, blank, too long, holds characters outside
///   `[A-Za-z0-9_.:-]`, or repeats another item's id → `missingField` /
///   `wrongType` / `tooLong` / `duplicateItemId`. Ids are what makes
///   applying idempotent, so a duplicate id is a hard error, not a nuisance;
/// * `kind` is missing or unknown → `unknownKind`;
/// * `title` is missing, blank after trimming, or longer than 120 →
///   `missingField` / `blankText` / `tooLong`. The title has to read as
///   **one line of a checklist**: the suggestions he approves gather into a
///   named list he ticks off one by one («خطة تشرين الأول» → ☐ مشي ٢٠ دقيقة
///   بعد العشا), so the prompt asks for at most about 60 characters, no
///   full stops and no two sentences. [PlanItemPreview.oneLine] is the line
///   the checklist shows;
/// * **`reason` is missing or blank** → `missingReason`. An item with no
///   reason is invalid, full stop: the whole point of the round trip is that
///   he sees *why* before he says yes;
/// * `data` is missing or is not an object → `missingField` / `wrongType`;
/// * any key of the item or of `data` is not in this contract →
///   `unknownField`;
/// * a text holds control characters → `controlCharacters`;
/// * a number is not finite, or falls outside its documented range →
///   `wrongType` / `outOfRange`;
/// * a day is not `yyyy-MM-dd`, or is more than 365 days from today →
///   `badDay`; a time is not `HH:mm` 00:00‥23:59 → `badTime`; a weekday is
///   outside 1‥7 or repeats → `badWeekday`;
/// * a reference names something that is not in his data (and is not
///   introduced by another item of the same plan) → `unknownReference`.
///   A budget tweak on an envelope he does not have, a meal change naming a
///   food he never logged: both are refused. Madar sends him the list of
///   his own envelopes, foods, habits and trackers in the request, so the
///   AI has no excuse to invent one;
/// * `dependsOn` names an item that is not in this plan → `missingDependency`,
///   or forms a cycle → `circularDependency`;
/// * the item reads as **medical advice**: a diagnosis, a treatment, a drug,
///   a dose, or "stop / change your medicine" → `healthAdvice`. See
///   [HealthGuard]. This is checked on every item of every kind, because a
///   dose hidden in a task title is still a dose. A health suggestion may
///   only ever be something to **track** or to **practise**.
///
/// Items of a kind this version cannot write yet ([PlanItemKind.recipe],
/// [PlanItemKind.pantryItem] – Part 5's kitchen) are **not** rejected: they
/// validate, they are shown, and they are stored in the history as
/// `deferred`. The same pipe will apply them when «السفرة» exists.
///
/// ## `data` by kind
///
/// Numbers are plain JSON numbers; money is in **currency units** (not
/// milli-units) and is converted exactly on apply. Every key is optional
/// unless marked REQUIRED.
///
/// * **task** – one thing to do, which becomes a line of the plan's
///   checklist (and nothing else): `day` (ISO day), `window`
///   (`fajr|dhuhr|asr|maghrib|isha|anytime`), `priority` (int 0‥3),
///   `top3` (bool), `notes` (≤ 500),
///   `repeat` (`{"every":"day"|"week"|"month","weekdays":[1‥7]}`),
///   `projectRef` (an existing project id or exact name). The day, window
///   and repeat are shown on the line; they are not written into his task
///   list.
/// * **habit** – `category` (≤ 40, his own word), `planetKey`,
///   `existingRef` (one of his habits: the apply switches it back on
///   instead of adding a second one).
/// * **routine** – `times` REQUIRED (1‥6 × `HH:mm`), `weekdays` ([1‥7]),
///   `category`, `steps` (≤ 12 × `{"title":"…","note":"…"}`).
///   Applies as one habit plus one reminder row per time on that habit –
///   the same kind of row the app already stores for a tracker's reminder.
/// * **reminder** – `time` REQUIRED unless `at` is given, `at` (ISO date-time),
///   `repeat` (`day|week`), `weekdays`, `ownerRef`
///   (`{"table":"habits","id":"…"}` – one of his own records, which must
///   exist). With an owner the apply sets that record's reminder; without
///   one the item is a checklist line only (it never invents a task to
///   hang on).
/// * **note** – `body` REQUIRED (1‥2000). Kept with the plan and shown on
///   its checklist line; no record of his is created or overwritten.
/// * **food** – `tags` (≤ 8 × ≤ 24), `portion` (> 0, ≤ 10000), `unit` (≤ 24),
///   `notes` (≤ 300). Adds a food to his library so a meal change can use
///   it; the food's name is the item's `title`.
/// * **mealChange** – `op` REQUIRED (`addFood|removeFood|newSlot|moveSlot`),
///   `slotRef` (one of his meals), `slotName` (≤ 60), `time` (`HH:mm`),
///   `weekdays`, `foodRef` (one of his foods **or** an id of a `food` item
///   of this plan), `portion`, `unit`, `planRef` (one of his meal plans).
///   `addFood`/`removeFood` need a food and a meal; `newSlot` needs
///   `slotName` + `time`; `moveSlot` needs `slotRef` + `time`.
/// * **avoidItem** – `note` (≤ 300). The avoid list on the Body planet; the
///   item's `reason` is stored as the row's reason.
/// * **trackedSign** – `scale` REQUIRED (`yesNo|zeroToTen`), `everyDay`
///   (bool, default true), `unit` (≤ 24). Becomes a tracker (custom module)
///   with one field, so "puffy face 0‥10" is something he follows, never a
///   diagnosis.
/// * **labTracker** – `unit` (≤ 24), `low` / `high` (numbers, low < high),
///   `category` (≤ 40). Adds a lab test **to track**; it never says to take
///   one, and it carries no interpretation.
/// * **budgetTweak** – `envelopeRef` REQUIRED (one of his budget items, by
///   id or exact name), `newAmount` (≥ 0, ≤ 1 000 000) **or** `newPercent`
///   (0‥100), `period` (`monthly|weekly`), `currency` (an existing code).
///   Exactly one of `newAmount` / `newPercent`.
/// * **learningProgram** – `target` (> 0, ≤ 100 000), `unit` (≤ 24),
///   `deadline` (ISO day), `steps` (≤ 60 × `{"title":"…","day":"…","note":"…"}`).
///   Applies as a learning goal on the Growth planet; its steps are shown
///   on the card and kept with the item (never written as tasks).
/// * **recipe**, **pantryItem** – accepted, shown, deferred (Part 5).
///
/// ## The checklist, and what an apply may touch
///
/// Approving an item does two things: it writes the item's own change (a
/// habit, a food, an envelope amount …) and it adds **one line to the
/// plan's checklist**, which he ticks off as he does it. The checklist is
/// the plan's own rows (`applied_plan_items`) – an approved suggestion is
/// never turned into a task in the home panel's task list, and no apply in
/// this engine writes to `tasks`. Items whose only effect is the line
/// itself ([PlanItemKind.task], [PlanItemKind.note], a reminder with no
/// owner) say so in their preview.
///
/// ## What the validator deliberately does *not* do
///
/// It never repairs, never rounds, never guesses a missing reference and
/// never drops a field quietly. A problem is a sentence he reads; a plan is
/// either reviewable item by item or refused with reasons.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

/// The one contract version this build reads and writes.
const int madarPlanVersion = 1;

/// The envelope marker: `"madar": "plan"`.
const String madarPlanMarker = 'plan';

/// The key that carries [madarPlanMarker].
const String madarPlanMarkerKey = 'madar';

/// Hard limits. They are part of the contract: the prompt states them, and
/// the validator enforces them.
abstract final class PlanLimits {
  static const int maxPayloadBytes = 2 * 1024 * 1024;
  static const int maxDepth = 12;
  static const int maxItems = 200;
  static const int maxIdLength = 64;
  static const int maxTitleLength = 120;
  static const int maxReasonLength = 500;
  static const int minReasonLength = 3;
  static const int maxSummaryLength = 1000;
  static const int maxEvidenceLength = 300;
  static const int maxNoteLength = 2000;
  static const int maxTextLength = 300;
  static const int maxUnitLength = 24;
  static const int maxCategoryLength = 40;
  static const int maxNameLength = 60;
  static const int maxSourceTitleLength = 160;
  static const int maxUrlLength = 400;
  static const int maxClaims = 20;
  static const int maxTags = 8;
  static const int maxTagLength = 24;
  static const int maxRoutineTimes = 6;
  static const int maxRoutineSteps = 12;
  static const int maxProgramSteps = 60;

  /// How far a suggested day may lie from today, either way.
  static const int maxDayDistance = 365;

  static const double maxPortion = 10000;
  static const double maxMoney = 1000000;
  static const double maxTarget = 100000;
  static const int maxPriority = 3;
}

/// What a suggestion is.
enum PlanItemKind {
  /// One task on the home panel, in a prayer window.
  task,

  /// A habit of the tracker.
  habit,

  /// A habit with times: a morning or evening routine.
  routine,

  /// A reminder on a task (new or existing).
  reminder,

  /// Something to read later, applied to nothing.
  note,

  /// A food for his library (so a meal change can name it).
  food,

  /// A change to the meal plan.
  mealChange,

  /// A line on the avoid list, with its reason.
  avoidItem,

  /// Something to watch daily (yes/no or 0‥10) – the tracking half of the
  /// health rule.
  trackedSign,

  /// A lab value to follow over time (tracking only).
  labTracker,

  /// A change to one budget envelope.
  budgetTweak,

  /// A learning goal with its steps.
  learningProgram,

  /// Part 5 (the kitchen): accepted and shown, applied by a later version.
  recipe,

  /// Part 5 (the pantry): accepted and shown, applied by a later version.
  pantryItem;

  /// Kinds this build can write to his data.
  bool get isApplicable => this != recipe && this != pantryItem;

  static PlanItemKind? parse(String? raw) {
    for (final k in values) {
      if (k.name == raw) return k;
    }
    return null;
  }
}

/// What the AI read, how complete it was, and what it refused to pass on.
@immutable
class PlanSource {
  const PlanSource({this.kind, this.title, this.url, this.completeness, this.claimsFlagged = const []});

  /// `video`, `article`, `channel`, `book`, `chat`, `other`.
  final String? kind;
  final String? title;

  /// Never fetched by Madar – shown so he knows where this came from.
  final String? url;

  /// What the source did not cover (a transcript that stops halfway).
  final String? completeness;

  /// Claims to show as a warning, never to apply.
  final List<String> claimsFlagged;

  bool get isEmpty =>
      kind == null && title == null && url == null && completeness == null && claimsFlagged.isEmpty;

  /// Known values of [kind].
  static const Set<String> kinds = {'video', 'article', 'channel', 'book', 'chat', 'other'};

  Map<String, Object?> toJson() => {
    'kind': ?kind,
    'title': ?title,
    'url': ?url,
    'completeness': ?completeness,
    if (claimsFlagged.isNotEmpty) 'claimsFlagged': claimsFlagged,
  };
}

/// One suggestion.
@immutable
class PlanItem {
  const PlanItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.reason,
    this.area,
    this.evidence,
    this.confidence,
    this.dependsOn = const [],
    this.data = const {},
  });

  /// Unique inside the plan. Together with the plan's key it is what makes
  /// an apply idempotent.
  final String id;
  final PlanItemKind kind;

  /// The line he reads on the card.
  final String title;

  /// Why – never empty (an item without a reason is invalid).
  final String reason;

  /// Planet key for grouping (`health`, `money`, …).
  final String? area;

  /// Which of his own numbers this came from.
  final String? evidence;

  /// 0‥1, the AI's own confidence.
  final double? confidence;

  /// Ids of items of the same plan that must be applied first.
  final List<String> dependsOn;

  /// The kind's payload, already validated.
  final Map<String, Object?> data;

  /// A validated string field of [data] (null when absent).
  String? str(String key) {
    final v = data[key];
    return v is String && v.trim().isNotEmpty ? v.trim() : null;
  }

  double? number(String key) {
    final v = data[key];
    return v is num && v.isFinite ? v.toDouble() : null;
  }

  int? integer(String key) {
    final v = number(key);
    return v?.round();
  }

  bool? flag(String key) {
    final v = data[key];
    return v is bool ? v : null;
  }

  List<int> ints(String key) {
    final v = data[key];
    return v is List ? [for (final e in v) if (e is num) e.toInt()] : const [];
  }

  List<String> strings(String key) {
    final v = data[key];
    return v is List
        ? [
            for (final e in v)
              if (e is String && e.trim().isNotEmpty) e.trim(),
          ]
        : const [];
  }

  List<Map<String, Object?>> maps(String key) {
    final v = data[key];
    return v is List
        ? [
            for (final e in v)
              if (e is Map) e.cast<String, Object?>(),
          ]
        : const [];
  }

  Map<String, Object?> get map => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'reason': reason,
    'area': ?area,
    'evidence': ?evidence,
    if (confidence != null) 'confidence': confidence,
    if (dependsOn.isNotEmpty) 'dependsOn': dependsOn,
    'data': data,
  };
}

/// A validated plan, ready to preview item by item.
@immutable
class MadarPlan {
  const MadarPlan({
    required this.version,
    required this.items,
    this.title,
    this.summary,
    this.requestId,
    this.generatedFor,
    this.source = const PlanSource(),
  });

  final int version;
  final String? title;
  final String? summary;

  /// Echo of the request this answers, when the AI kept it.
  final String? requestId;

  /// The day the AI wrote it for.
  final DateTime? generatedFor;
  final PlanSource source;
  final List<PlanItem> items;

  PlanItem? item(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    madarPlanMarkerKey: madarPlanMarker,
    'version': version,
    'title': ?title,
    'summary': ?summary,
    'requestId': ?requestId,
    if (generatedFor != null) 'generatedFor': planDay(generatedFor!),
    if (!source.isEmpty) 'source': source.toJson(),
    'items': [for (final i in items) i.map],
  };

  /// Stable fingerprint input: the canonical JSON of the plan, so the same
  /// answer imported twice is recognised as the same plan whatever
  /// whitespace or key order it arrived in.
  String canonical() => jsonEncode(_canonical(toJson()));

  static Object? _canonical(Object? value) => switch (value) {
    Map<String, Object?> m => {
      for (final k in m.keys.toList()..sort()) k: _canonical(m[k]),
    },
    List<Object?> l => [for (final e in l) _canonical(e)],
    _ => value,
  };
}

/// Keys the envelope may carry (anything else is `unknownField`).
const Set<String> planEnvelopeKeys = {
  madarPlanMarkerKey,
  'version',
  'title',
  'summary',
  'requestId',
  'generatedFor',
  'source',
  'items',
};

/// Keys an item may carry.
const Set<String> planItemKeys = {
  'id',
  'kind',
  'title',
  'reason',
  'area',
  'evidence',
  'confidence',
  'dependsOn',
  'data',
};

/// Keys a `source` block may carry.
const Set<String> planSourceKeys = {'kind', 'title', 'url', 'completeness', 'claimsFlagged'};

/// `data` keys allowed per kind.
const Map<PlanItemKind, Set<String>> planDataKeys = {
  PlanItemKind.task: {'day', 'window', 'priority', 'top3', 'notes', 'repeat', 'projectRef'},
  PlanItemKind.habit: {'category', 'planetKey', 'existingRef'},
  PlanItemKind.routine: {'times', 'weekdays', 'category', 'steps'},
  PlanItemKind.reminder: {'time', 'at', 'repeat', 'weekdays', 'ownerRef'},
  PlanItemKind.note: {'body'},
  PlanItemKind.food: {'tags', 'portion', 'unit', 'notes'},
  PlanItemKind.mealChange: {
    'op',
    'slotRef',
    'slotName',
    'time',
    'weekdays',
    'foodRef',
    'portion',
    'unit',
    'planRef',
  },
  PlanItemKind.avoidItem: {'note'},
  PlanItemKind.trackedSign: {'scale', 'everyDay', 'unit'},
  PlanItemKind.labTracker: {'unit', 'low', 'high', 'category'},
  PlanItemKind.budgetTweak: {'envelopeRef', 'newAmount', 'newPercent', 'period', 'currency'},
  PlanItemKind.learningProgram: {'target', 'unit', 'deadline', 'steps'},
  PlanItemKind.recipe: {'ingredients', 'steps', 'servings', 'minutes', 'tags', 'notes'},
  PlanItemKind.pantryItem: {'quantity', 'unit', 'place', 'expires', 'notes'},
};

/// Prayer windows a task or a routine may name.
const Set<String> planWindows = {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'anytime'};

/// Planet keys an item's `area` may name.
const Set<String> planAreas = {'faith', 'health', 'money', 'family', 'work', 'growth', 'body', 'travel'};

/// `mealChange.op` values.
const Set<String> planMealOps = {'addFood', 'removeFood', 'newSlot', 'moveSlot'};

/// `trackedSign.scale` values.
const Set<String> planScales = {'yesNo', 'zeroToTen'};

/// `budgetTweak.period` values.
const Set<String> planPeriods = {'monthly', 'weekly'};

/// `repeat.every` values.
const Set<String> planRepeats = {'day', 'week', 'month'};

/// `yyyy-MM-dd` of [day].
String planDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// `HH:mm` of [minutes] after midnight.
String planTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Minutes after midnight of a `HH:mm` string, or null when it is not one.
int? planMinutes(String raw) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.parse(m[2]!);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

/// The calendar day of a `yyyy-MM-dd` string, or null.
DateTime? planParseDay(String raw) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (m == null) return null;
  final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final day = DateTime(y, mo, d);
  return day.month == mo && day.day == d ? day : null;
}
