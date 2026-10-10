/// The gate of the AI bridge: text in, a validated plan plus a list of
/// problems out. Never throws, never repairs, never guesses.
///
/// See `plan_contract.dart` for the contract itself (every field, what is
/// required and what is refused and why).
///
/// Two kinds of outcome:
///
/// * **fatal** – nothing is reviewable (not JSON, not a Madar plan, a
///   version from the future, no items, too big). [PlanValidation.plan] is
///   null;
/// * **per item** – the payload is a plan, and each item is either accepted
///   or refused with its own reasons. One bad item never costs him the
///   other nine.
///
/// Pure Dart.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import 'health_guard.dart';
import 'plan_catalog.dart';
import 'plan_contract.dart';
import 'plan_problems.dart';

/// The result of validating one payload.
@immutable
class PlanValidation {
  const PlanValidation({required this.problems, this.plan, this.accepted = const [], this.rejected = const {}});

  /// The plan, with **every** item it carried (including refused ones, so
  /// the review screen can show them greyed out with their reason); null
  /// when the payload is not a plan at all.
  final MadarPlan? plan;

  /// Every problem found, payload-level first, then per item in order.
  final List<PlanProblem> problems;

  /// Items with no refusing problem – the only ones that may be applied.
  final List<PlanItem> accepted;

  /// Ids of refused items.
  final Set<String> rejected;

  /// Problems that stop the whole payload.
  List<PlanProblem> get fatal => [
    for (final p in problems)
      if (p.isFatal) p,
  ];

  /// Problems of one item, in order.
  List<PlanProblem> problemsFor(String itemId) => [
    for (final p in problems)
      if (p.itemId == itemId) p,
  ];

  /// Whether there is anything to review.
  bool get isUsable => plan != null && accepted.isNotEmpty;

  bool get hasProblems => problems.isNotEmpty;
}

/// Validates one payload against the contract and against [catalog] – what
/// he actually has right now.
class PlanValidator {
  PlanValidator(this.catalog);

  final PlanCatalog catalog;

  List<PlanProblem> _problems = [];

  /// Parses [text] (tolerating a Markdown code fence and a sentence the AI
  /// wrote around the JSON, which is reported as a problem but not fatal)
  /// and validates it.
  PlanValidation parse(String text) {
    _problems = [];
    final bytes = utf8.encode(text).length;
    if (bytes > PlanLimits.maxPayloadBytes) {
      return _fatal(PlanProblem(PlanProblemCode.tooBig, detail: '$bytes', limit: PlanLimits.maxPayloadBytes));
    }
    final stripped = _stripFence(text).trim();
    if (stripped.isEmpty) return _fatal(const PlanProblem(PlanProblemCode.notJson));

    Object? decoded;
    try {
      decoded = jsonDecode(stripped);
    } catch (_) {
      final inner = _firstObject(stripped);
      if (inner == null) return _fatal(const PlanProblem(PlanProblemCode.notJson));
      try {
        decoded = jsonDecode(inner);
      } catch (_) {
        return _fatal(const PlanProblem(PlanProblemCode.notJson));
      }
      // The JSON object is in there, wrapped in the AI's own chatter. We
      // take the object and say so, rather than refusing a good plan.
      _problems.add(const PlanProblem(PlanProblemCode.trailingText));
    }
    return _run(decoded);
  }

  /// Validates an already decoded payload (a share intent that handed us
  /// parsed JSON, or a test fixture).
  PlanValidation validate(Object? decoded) {
    _problems = [];
    return _run(decoded);
  }

  PlanValidation _run(Object? decoded) {
    if (decoded is! Map) {
      return _fatal(const PlanProblem(PlanProblemCode.notAnObject));
    }
    final root = decoded.cast<String, Object?>();
    if (_depth(root) > PlanLimits.maxDepth) {
      return _fatal(const PlanProblem(PlanProblemCode.tooDeep, limit: PlanLimits.maxDepth));
    }
    if (root[madarPlanMarkerKey] != madarPlanMarker) {
      return _fatal(PlanProblem(PlanProblemCode.notAMadarPlan, detail: _preview(root[madarPlanMarkerKey])));
    }
    final version = root['version'];
    if (version is! int || version != madarPlanVersion) {
      return _fatal(PlanProblem(PlanProblemCode.unsupportedVersion, detail: _preview(version)));
    }
    _unknownKeys(root, planEnvelopeKeys, '');

    final title = _text(root, 'title', '', max: PlanLimits.maxTitleLength);
    final summary = _text(root, 'summary', '', max: PlanLimits.maxSummaryLength);
    final requestId = _text(root, 'requestId', '', max: PlanLimits.maxIdLength);
    final generatedFor = _day(root, 'generatedFor', '', checkDistance: false);
    final source = _source(root['source']);

    final rawItems = root['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      return _fatal(const PlanProblem(PlanProblemCode.noItems));
    }
    if (rawItems.length > PlanLimits.maxItems) {
      return _fatal(PlanProblem(PlanProblemCode.tooManyItems, detail: '${rawItems.length}', limit: PlanLimits.maxItems));
    }

    // Pass 1: the shape of every item, and what the plan itself introduces
    // (a food another item may then point at).
    final items = <PlanItem>[];
    final rejected = <String>{};
    final seen = <String>{};
    for (var i = 0; i < rawItems.length; i++) {
      final path = 'items[$i]';
      final raw = rawItems[i];
      if (raw is! Map) {
        _problems.add(PlanProblem(PlanProblemCode.wrongType, path: path, detail: _preview(raw)));
        continue;
      }
      final map = raw.cast<String, Object?>();
      final id = _itemId(map, path, seen);
      if (id == null) continue;
      seen.add(id);
      final before = _problems.length;
      final item = _item(map, path, id);
      if (item == null) {
        rejected.add(id);
        continue;
      }
      items.add(item);
      if (_problems.length > before && _problems.skip(before).any((p) => p.itemId == id && p.rejects)) {
        rejected.add(id);
      }
    }
    if (items.isEmpty) return _fatal(const PlanProblem(PlanProblemCode.noItems));

    final locals = _Locals(items);

    // Pass 2: references, dependencies and the health rule – they need the
    // whole plan in hand.
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final path = 'items[$i]';
      final before = _problems.length;
      _references(item, path, locals);
      _dependencies(item, path, locals);
      _health(item);
      if (_problems.skip(before).any((p) => p.itemId == item.id && p.rejects)) rejected.add(item.id);
    }

    final plan = MadarPlan(
      version: version,
      title: title,
      summary: summary,
      requestId: requestId,
      generatedFor: generatedFor,
      source: source,
      items: items,
    );
    return PlanValidation(
      plan: plan,
      problems: List.unmodifiable(_problems),
      accepted: [
        for (final i in items)
          if (!rejected.contains(i.id)) i,
      ],
      rejected: Set.unmodifiable(rejected),
    );
  }

  // ------------------------------------------------------------- envelope --

  PlanValidation _fatal(PlanProblem problem) =>
      PlanValidation(problems: List.unmodifiable([..._problems, problem]));

  PlanSource _source(Object? raw) {
    if (raw == null) return const PlanSource();
    if (raw is! Map) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, path: 'source', detail: _preview(raw)));
      return const PlanSource();
    }
    final map = raw.cast<String, Object?>();
    _unknownKeys(map, planSourceKeys, 'source');
    final kind = _text(map, 'kind', 'source', max: PlanLimits.maxUnitLength);
    if (kind != null && !PlanSource.kinds.contains(kind)) {
      _problems.add(PlanProblem(PlanProblemCode.unknownValue, path: 'source.kind', detail: kind));
    }
    final url = _text(map, 'url', 'source', max: PlanLimits.maxUrlLength);
    if (url != null && !(url.startsWith('http://') || url.startsWith('https://'))) {
      _problems.add(PlanProblem(PlanProblemCode.unknownValue, path: 'source.url', detail: url));
    }
    final claims = <String>[];
    final rawClaims = map['claimsFlagged'];
    if (rawClaims != null) {
      if (rawClaims is! List) {
        _problems.add(PlanProblem(PlanProblemCode.wrongType, path: 'source.claimsFlagged'));
      } else {
        for (final c in rawClaims.take(PlanLimits.maxClaims)) {
          if (c is String && c.trim().isNotEmpty) claims.add(_clip(c.trim(), PlanLimits.maxTextLength));
        }
      }
    }
    return PlanSource(
      kind: kind,
      title: _text(map, 'title', 'source', max: PlanLimits.maxSourceTitleLength),
      url: url,
      completeness: _text(map, 'completeness', 'source', max: PlanLimits.maxTextLength),
      claimsFlagged: claims,
    );
  }

  // ----------------------------------------------------------------- item --

  static final RegExp _idShape = RegExp(r'^[A-Za-z0-9_.:-]+$');

  String? _itemId(Map<String, Object?> map, String path, Set<String> seen) {
    final raw = map['id'];
    if (raw == null) {
      _problems.add(PlanProblem(PlanProblemCode.missingField, path: '$path.id', detail: 'id'));
      return null;
    }
    if (raw is! String || raw.trim().isEmpty) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, path: '$path.id', detail: _preview(raw)));
      return null;
    }
    final id = raw.trim();
    if (id.length > PlanLimits.maxIdLength) {
      _problems.add(PlanProblem(PlanProblemCode.tooLong, path: '$path.id', detail: id, limit: PlanLimits.maxIdLength));
      return null;
    }
    if (!_idShape.hasMatch(id)) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, path: '$path.id', detail: id));
      return null;
    }
    if (seen.contains(id)) {
      _problems.add(PlanProblem(PlanProblemCode.duplicateItemId, itemId: id, path: '$path.id', detail: id));
      return null;
    }
    return id;
  }

  PlanItem? _item(Map<String, Object?> map, String path, String id) {
    _unknownKeys(map, planItemKeys, path, itemId: id);
    final kind = PlanItemKind.parse(map['kind'] is String ? (map['kind']! as String).trim() : null);
    if (kind == null) {
      _problems.add(
        PlanProblem(PlanProblemCode.unknownKind, itemId: id, path: '$path.kind', detail: _preview(map['kind'])),
      );
      return null;
    }
    final title = _text(map, 'title', path, itemId: id, max: PlanLimits.maxTitleLength, required: true);
    final reasonRaw = map['reason'];
    String? reason;
    if (reasonRaw == null || (reasonRaw is String && reasonRaw.trim().isEmpty)) {
      // The rule: no reason, no item.
      _problems.add(PlanProblem(PlanProblemCode.missingReason, itemId: id, path: '$path.reason'));
    } else if (reasonRaw is! String) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: id, path: '$path.reason', detail: _preview(reasonRaw)));
    } else {
      reason = reasonRaw.trim();
      if (reason.length < PlanLimits.minReasonLength) {
        _problems.add(
          PlanProblem(PlanProblemCode.blankText, itemId: id, path: '$path.reason', limit: PlanLimits.minReasonLength),
        );
        reason = null;
      } else if (reason.length > PlanLimits.maxReasonLength) {
        _problems.add(
          PlanProblem(PlanProblemCode.tooLong, itemId: id, path: '$path.reason', limit: PlanLimits.maxReasonLength),
        );
        reason = _clip(reason, PlanLimits.maxReasonLength);
      }
      _controls(reason, '$path.reason', id);
    }
    if (title == null || reason == null) return null;

    final area = _text(map, 'area', path, itemId: id, max: PlanLimits.maxUnitLength);
    if (area != null && !planAreas.contains(area)) {
      _problems.add(PlanProblem(PlanProblemCode.unknownValue, itemId: id, path: '$path.area', detail: area));
    }
    final confidence = _number(map, 'confidence', path, itemId: id, min: 0, max: 1);
    final dependsOn = _ids(map, 'dependsOn', path, id);

    final rawData = map['data'];
    if (rawData == null) {
      _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: id, path: '$path.data', detail: 'data'));
      return null;
    }
    if (rawData is! Map) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: id, path: '$path.data', detail: _preview(rawData)));
      return null;
    }
    final data = rawData.cast<String, Object?>();
    _unknownKeys(data, planDataKeys[kind] ?? const {}, '$path.data', itemId: id);
    _data(kind, data, '$path.data', id);
    if (!kind.isApplicable) {
      _problems.add(PlanProblem(PlanProblemCode.deferredKind, itemId: id, detail: kind.name));
    }

    return PlanItem(
      id: id,
      kind: kind,
      title: title,
      reason: reason,
      area: area,
      evidence: _text(map, 'evidence', path, itemId: id, max: PlanLimits.maxEvidenceLength),
      confidence: confidence,
      dependsOn: dependsOn,
      data: Map.unmodifiable(data),
    );
  }

  // ----------------------------------------------------------- data, by kind

  void _data(PlanItemKind kind, Map<String, Object?> d, String p, String id) {
    switch (kind) {
      case PlanItemKind.task:
        _day(d, 'day', p, itemId: id);
        _enum(d, 'window', p, id, planWindows);
        _number(d, 'priority', p, itemId: id, min: 0, max: PlanLimits.maxPriority);
        _bool(d, 'top3', p, id);
        _text(d, 'notes', p, itemId: id, max: PlanLimits.maxReasonLength);
        _repeat(d, p, id);
        _text(d, 'projectRef', p, itemId: id, max: PlanLimits.maxNameLength);
      case PlanItemKind.habit:
        _text(d, 'category', p, itemId: id, max: PlanLimits.maxCategoryLength);
        _enum(d, 'planetKey', p, id, planAreas);
        _text(d, 'existingRef', p, itemId: id, max: PlanLimits.maxNameLength);
      case PlanItemKind.routine:
        final times = _times(d, 'times', p, id, required: true);
        if (times.length > PlanLimits.maxRoutineTimes) {
          _problems.add(
            PlanProblem(PlanProblemCode.outOfRange, itemId: id, path: '$p.times', limit: PlanLimits.maxRoutineTimes),
          );
        }
        _weekdays(d, p, id);
        _text(d, 'category', p, itemId: id, max: PlanLimits.maxCategoryLength);
        _steps(d, p, id, PlanLimits.maxRoutineSteps);
      case PlanItemKind.reminder:
        final time = _times(d, 'time', p, id);
        final at = _text(d, 'at', p, itemId: id, max: PlanLimits.maxUnitLength + 16);
        if (time.isEmpty && at == null) {
          _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: id, path: '$p.time', detail: 'time'));
        }
        if (at != null && DateTime.tryParse(at) == null) {
          _problems.add(PlanProblem(PlanProblemCode.badTime, itemId: id, path: '$p.at', detail: at));
        }
        _enum(d, 'repeat', p, id, const {'day', 'week'});
        _weekdays(d, p, id);
        _ownerRef(d, p, id);
      case PlanItemKind.note:
        _text(d, 'body', p, itemId: id, max: PlanLimits.maxNoteLength, required: true);
      case PlanItemKind.food:
        _tags(d, p, id);
        _number(d, 'portion', p, itemId: id, min: 0, max: PlanLimits.maxPortion, exclusiveMin: true);
        _text(d, 'unit', p, itemId: id, max: PlanLimits.maxUnitLength);
        _text(d, 'notes', p, itemId: id, max: PlanLimits.maxTextLength);
      case PlanItemKind.mealChange:
        final op = _enum(d, 'op', p, id, planMealOps, required: true);
        _text(d, 'slotRef', p, itemId: id, max: PlanLimits.maxNameLength);
        _text(d, 'slotName', p, itemId: id, max: PlanLimits.maxNameLength);
        _times(d, 'time', p, id);
        _weekdays(d, p, id);
        _text(d, 'foodRef', p, itemId: id, max: PlanLimits.maxNameLength);
        _number(d, 'portion', p, itemId: id, min: 0, max: PlanLimits.maxPortion, exclusiveMin: true);
        _text(d, 'unit', p, itemId: id, max: PlanLimits.maxUnitLength);
        _text(d, 'planRef', p, itemId: id, max: PlanLimits.maxNameLength);
        switch (op) {
          case 'addFood':
          case 'removeFood':
            if (d['foodRef'] == null) {
              _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: id, path: '$p.foodRef', detail: 'foodRef'));
            }
            if (d['slotRef'] == null) {
              _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: id, path: '$p.slotRef', detail: 'slotRef'));
            }
          case 'newSlot':
            if (d['slotName'] == null) {
              _problems.add(
                PlanProblem(PlanProblemCode.missingField, itemId: id, path: '$p.slotName', detail: 'slotName'),
              );
            }
            if (d['time'] == null) {
              _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: id, path: '$p.time', detail: 'time'));
            }
          case 'moveSlot':
            if (d['slotRef'] == null) {
              _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: id, path: '$p.slotRef', detail: 'slotRef'));
            }
            if (d['time'] == null) {
              _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: id, path: '$p.time', detail: 'time'));
            }
          default:
            break;
        }
      case PlanItemKind.avoidItem:
        _text(d, 'note', p, itemId: id, max: PlanLimits.maxTextLength);
      case PlanItemKind.trackedSign:
        _enum(d, 'scale', p, id, planScales, required: true);
        _bool(d, 'everyDay', p, id);
        _text(d, 'unit', p, itemId: id, max: PlanLimits.maxUnitLength);
      case PlanItemKind.labTracker:
        _text(d, 'unit', p, itemId: id, max: PlanLimits.maxUnitLength);
        final low = _number(d, 'low', p, itemId: id, min: -100000, max: 100000);
        final high = _number(d, 'high', p, itemId: id, min: -100000, max: 100000);
        if (low != null && high != null && low >= high) {
          _problems.add(PlanProblem(PlanProblemCode.outOfRange, itemId: id, path: '$p.low', detail: '$low'));
        }
        _text(d, 'category', p, itemId: id, max: PlanLimits.maxCategoryLength);
      case PlanItemKind.budgetTweak:
        _text(d, 'envelopeRef', p, itemId: id, max: PlanLimits.maxNameLength, required: true);
        final amount = _number(d, 'newAmount', p, itemId: id, min: 0, max: PlanLimits.maxMoney);
        final percent = _number(d, 'newPercent', p, itemId: id, min: 0, max: 100);
        if ((amount == null) == (percent == null)) {
          _problems.add(
            PlanProblem(
              PlanProblemCode.missingField,
              itemId: id,
              path: '$p.newAmount',
              detail: amount == null ? 'newAmount' : 'newPercent',
            ),
          );
        }
        _enum(d, 'period', p, id, planPeriods);
        final currency = _text(d, 'currency', p, itemId: id, max: PlanLimits.maxUnitLength);
        if (currency != null && catalog.currencyCodes.isNotEmpty && !catalog.currencyCodes.contains(currency)) {
          _problems.add(PlanProblem(PlanProblemCode.unknownReference, itemId: id, path: '$p.currency', detail: currency));
        }
      case PlanItemKind.learningProgram:
        _number(d, 'target', p, itemId: id, min: 0, max: PlanLimits.maxTarget, exclusiveMin: true);
        _text(d, 'unit', p, itemId: id, max: PlanLimits.maxUnitLength);
        _day(d, 'deadline', p, itemId: id);
        _steps(d, p, id, PlanLimits.maxProgramSteps);
      case PlanItemKind.recipe:
      case PlanItemKind.pantryItem:
        // Part 5 owns their payloads; the texts are still checked for
        // control characters, length and the health rule.
        for (final MapEntry(:key, :value) in d.entries) {
          if (value is String) _text(d, key, p, itemId: id, max: PlanLimits.maxNoteLength);
        }
    }
  }

  // --------------------------------------------------------- field helpers --

  void _unknownKeys(Map<String, Object?> map, Set<String> allowed, String path, {String? itemId}) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        _problems.add(
          PlanProblem(
            PlanProblemCode.unknownField,
            itemId: itemId,
            path: path.isEmpty ? key : '$path.$key',
            detail: key,
          ),
        );
      }
    }
  }

  String? _text(
    Map<String, Object?> map,
    String key,
    String path, {
    String? itemId,
    required int max,
    bool required = false,
  }) {
    final raw = map[key];
    final at = path.isEmpty ? key : '$path.$key';
    if (raw == null) {
      if (required) _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: itemId, path: at, detail: key));
      return null;
    }
    if (raw is! String) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(raw)));
      return null;
    }
    final text = raw.trim();
    if (text.isEmpty) {
      if (required) _problems.add(PlanProblem(PlanProblemCode.blankText, itemId: itemId, path: at));
      return null;
    }
    _controls(text, at, itemId);
    if (text.length > max) {
      _problems.add(PlanProblem(PlanProblemCode.tooLong, itemId: itemId, path: at, limit: max));
      return _clip(text, max);
    }
    return text;
  }

  double? _number(
    Map<String, Object?> map,
    String key,
    String path, {
    String? itemId,
    required num min,
    required num max,
    bool exclusiveMin = false,
  }) {
    final raw = map[key];
    final at = '$path.$key';
    if (raw == null) return null;
    if (raw is! num || !raw.isFinite) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(raw)));
      return null;
    }
    final v = raw.toDouble();
    if (v > max || v < min || (exclusiveMin && v == min)) {
      _problems.add(PlanProblem(PlanProblemCode.outOfRange, itemId: itemId, path: at, detail: '$v', limit: max));
      return null;
    }
    return v;
  }

  void _bool(Map<String, Object?> map, String key, String path, String itemId) {
    final raw = map[key];
    if (raw != null && raw is! bool) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: '$path.$key', detail: _preview(raw)));
    }
  }

  String? _enum(
    Map<String, Object?> map,
    String key,
    String path,
    String itemId,
    Set<String> allowed, {
    bool required = false,
  }) {
    final raw = map[key];
    final at = '$path.$key';
    if (raw == null) {
      if (required) _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: itemId, path: at, detail: key));
      return null;
    }
    if (raw is! String || !allowed.contains(raw.trim())) {
      _problems.add(PlanProblem(PlanProblemCode.unknownValue, itemId: itemId, path: at, detail: _preview(raw)));
      return null;
    }
    return raw.trim();
  }

  DateTime? _day(Map<String, Object?> map, String key, String path, {String? itemId, bool checkDistance = true}) {
    final raw = map[key];
    final at = path.isEmpty ? key : '$path.$key';
    if (raw == null) return null;
    if (raw is! String) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(raw)));
      return null;
    }
    final day = planParseDay(raw);
    if (day == null) {
      _problems.add(PlanProblem(PlanProblemCode.badDay, itemId: itemId, path: at, detail: raw.trim()));
      return null;
    }
    if (checkDistance) {
      final today = DateTime(catalog.today.year, catalog.today.month, catalog.today.day);
      if (day.difference(today).inDays.abs() > PlanLimits.maxDayDistance) {
        _problems.add(
          PlanProblem(
            PlanProblemCode.badDay,
            itemId: itemId,
            path: at,
            detail: raw.trim(),
            limit: PlanLimits.maxDayDistance,
          ),
        );
        return null;
      }
    }
    return day;
  }

  /// `times` (a list) or `time` (a single string) as minutes after
  /// midnight.
  List<int> _times(Map<String, Object?> map, String key, String path, String itemId, {bool required = false}) {
    final raw = map[key];
    final at = '$path.$key';
    if (raw == null) {
      if (required) _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: itemId, path: at, detail: key));
      return const [];
    }
    final list = raw is List ? raw : [raw];
    if (raw is List && raw.isEmpty && required) {
      _problems.add(PlanProblem(PlanProblemCode.missingField, itemId: itemId, path: at, detail: key));
    }
    final out = <int>[];
    for (final e in list) {
      if (e is! String) {
        _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(e)));
        continue;
      }
      final m = planMinutes(e);
      if (m == null) {
        _problems.add(PlanProblem(PlanProblemCode.badTime, itemId: itemId, path: at, detail: e.trim()));
        continue;
      }
      out.add(m);
    }
    return out;
  }

  void _weekdays(Map<String, Object?> map, String path, String itemId) {
    final raw = map['weekdays'];
    if (raw == null) return;
    final at = '$path.weekdays';
    if (raw is! List) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(raw)));
      return;
    }
    final seen = <int>{};
    for (final e in raw) {
      if (e is! num || !e.isFinite || e != e.roundToDouble() || e < 1 || e > 7 || !seen.add(e.toInt())) {
        _problems.add(PlanProblem(PlanProblemCode.badWeekday, itemId: itemId, path: at, detail: _preview(e)));
      }
    }
  }

  void _repeat(Map<String, Object?> map, String path, String itemId) {
    final raw = map['repeat'];
    if (raw == null) return;
    final at = '$path.repeat';
    if (raw is! Map) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(raw)));
      return;
    }
    final m = raw.cast<String, Object?>();
    _unknownKeys(m, const {'every', 'weekdays'}, at, itemId: itemId);
    _enum(m, 'every', at, itemId, planRepeats, required: true);
    _weekdays(m, at, itemId);
  }

  void _tags(Map<String, Object?> map, String path, String itemId) {
    final raw = map['tags'];
    if (raw == null) return;
    final at = '$path.tags';
    if (raw is! List) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(raw)));
      return;
    }
    if (raw.length > PlanLimits.maxTags) {
      _problems.add(PlanProblem(PlanProblemCode.outOfRange, itemId: itemId, path: at, limit: PlanLimits.maxTags));
    }
    for (final e in raw) {
      if (e is! String || e.trim().isEmpty) {
        _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(e)));
      } else if (e.trim().length > PlanLimits.maxTagLength) {
        _problems.add(
          PlanProblem(PlanProblemCode.tooLong, itemId: itemId, path: at, detail: e.trim(), limit: PlanLimits.maxTagLength),
        );
      } else {
        _controls(e, at, itemId);
      }
    }
  }

  void _steps(Map<String, Object?> map, String path, String itemId, int max) {
    final raw = map['steps'];
    if (raw == null) return;
    final at = '$path.steps';
    if (raw is! List) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(raw)));
      return;
    }
    if (raw.length > max) {
      _problems.add(PlanProblem(PlanProblemCode.outOfRange, itemId: itemId, path: at, limit: max));
    }
    for (final e in raw) {
      if (e is! Map) {
        _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(e)));
        continue;
      }
      final m = e.cast<String, Object?>();
      _unknownKeys(m, const {'title', 'day', 'note'}, at, itemId: itemId);
      _text(m, 'title', at, itemId: itemId, max: PlanLimits.maxTitleLength, required: true);
      _day(m, 'day', at, itemId: itemId);
      _text(m, 'note', at, itemId: itemId, max: PlanLimits.maxTextLength);
    }
  }

  void _ownerRef(Map<String, Object?> map, String path, String itemId) {
    final raw = map['ownerRef'];
    if (raw == null) return;
    final at = '$path.ownerRef';
    if (raw is! Map) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(raw)));
      return;
    }
    final m = raw.cast<String, Object?>();
    _unknownKeys(m, const {'table', 'id'}, at, itemId: itemId);
    _enum(m, 'table', at, itemId, planOwnerTables, required: true);
    _text(m, 'id', at, itemId: itemId, max: PlanLimits.maxNameLength, required: true);
  }

  List<String> _ids(Map<String, Object?> map, String key, String path, String itemId) {
    final raw = map[key];
    if (raw == null) return const [];
    final at = '$path.$key';
    if (raw is! List) {
      _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(raw)));
      return const [];
    }
    final out = <String>[];
    for (final e in raw) {
      if (e is! String || e.trim().isEmpty || e.trim().length > PlanLimits.maxIdLength) {
        _problems.add(PlanProblem(PlanProblemCode.wrongType, itemId: itemId, path: at, detail: _preview(e)));
        continue;
      }
      out.add(e.trim());
    }
    return out;
  }

  static final RegExp _control = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');

  void _controls(String text, String path, String? itemId) {
    if (_control.hasMatch(text)) {
      _problems.add(PlanProblem(PlanProblemCode.controlCharacters, itemId: itemId, path: path));
    }
  }

  // ------------------------------------------------------------ references --

  void _references(PlanItem item, String path, _Locals locals) {
    void check(String key, PlanRefSet set, {Set<String> alsoInPlan = const {}}) {
      final raw = item.str(key);
      if (raw == null) return;
      if (set.resolve(raw) != null) return;
      if (alsoInPlan.contains(raw) || alsoInPlan.contains(HealthGuard.fold(raw))) return;
      _problems.add(
        PlanProblem(PlanProblemCode.unknownReference, itemId: item.id, path: '$path.data.$key', detail: raw),
      );
    }

    switch (item.kind) {
      case PlanItemKind.task:
        check('projectRef', catalog.projects);
      case PlanItemKind.habit:
        check('existingRef', catalog.habits);
      case PlanItemKind.mealChange:
        check('foodRef', catalog.foods, alsoInPlan: locals.foods);
        check('slotRef', catalog.mealSlots, alsoInPlan: locals.slots);
        check('planRef', catalog.mealPlans);
      case PlanItemKind.budgetTweak:
        check('envelopeRef', catalog.budgetItems);
      case PlanItemKind.reminder:
        final owner = item.data['ownerRef'];
        if (owner is Map) {
          final table = owner['table'], id = owner['id'];
          if (table is String && id is String) {
            final set = _ownerSet(table);
            if (set == null || set.resolve(id) == null) {
              _problems.add(
                PlanProblem(
                  PlanProblemCode.unknownReference,
                  itemId: item.id,
                  path: '$path.data.ownerRef',
                  detail: '$table:$id',
                ),
              );
            }
          }
        }
      case PlanItemKind.routine:
      case PlanItemKind.note:
      case PlanItemKind.food:
      case PlanItemKind.avoidItem:
      case PlanItemKind.trackedSign:
      case PlanItemKind.labTracker:
      case PlanItemKind.learningProgram:
      case PlanItemKind.recipe:
      case PlanItemKind.pantryItem:
        break;
    }
  }

  PlanRefSet? _ownerSet(String table) => switch (table) {
    'habits' => catalog.habits,
    'custom_modules' => catalog.trackers,
    'learning_goals' => catalog.learningGoals,
    'meal_slots' => catalog.mealSlots,
    _ => null,
  };

  void _dependencies(PlanItem item, String path, _Locals locals) {
    for (final dep in item.dependsOn) {
      if (!locals.ids.contains(dep)) {
        _problems.add(
          PlanProblem(PlanProblemCode.missingDependency, itemId: item.id, path: '$path.dependsOn', detail: dep),
        );
      }
    }
    if (locals.inCycle(item.id)) {
      _problems.add(PlanProblem(PlanProblemCode.circularDependency, itemId: item.id, path: '$path.dependsOn'));
    }
  }

  void _health(PlanItem item) {
    final flag = HealthGuard.scan(_texts(item));
    if (flag != null) {
      _problems.add(PlanProblem(PlanProblemCode.healthAdvice, itemId: item.id, detail: flag.match));
    }
  }

  /// Every text of an item, including the ones nested in `data`.
  static Iterable<String> _texts(PlanItem item) {
    final out = <String>[item.title, item.reason, ?item.evidence];
    void walk(Object? v) {
      if (v is String) {
        out.add(v);
      } else if (v is List) {
        v.forEach(walk);
      } else if (v is Map) {
        v.values.forEach(walk);
      }
    }

    walk(item.data);
    return out;
  }

  // ------------------------------------------------------------- utilities --

  static String _stripFence(String text) {
    final t = text.trim();
    if (!t.startsWith('```')) return t;
    final firstBreak = t.indexOf('\n');
    if (firstBreak < 0) return t;
    final end = t.lastIndexOf('```');
    return end > firstBreak ? t.substring(firstBreak + 1, end) : t.substring(firstBreak + 1);
  }

  /// The first balanced `{…}` block of [text] (quotes and escapes aware).
  static String? _firstObject(String text) {
    final start = text.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final c = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      switch (c) {
        case '"':
          inString = true;
        case '{':
          depth++;
        case '}':
          depth--;
          if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }

  static int _depth(Object? value, [int depth = 1]) {
    if (depth > PlanLimits.maxDepth + 1) return depth;
    if (value is Map) {
      var deepest = depth;
      for (final v in value.values) {
        final d = _depth(v, depth + 1);
        if (d > deepest) deepest = d;
        if (deepest > PlanLimits.maxDepth + 1) return deepest;
      }
      return deepest;
    }
    if (value is List) {
      var deepest = depth;
      for (final v in value) {
        final d = _depth(v, depth + 1);
        if (d > deepest) deepest = d;
        if (deepest > PlanLimits.maxDepth + 1) return deepest;
      }
      return deepest;
    }
    return depth;
  }

  static String _clip(String text, int max) => text.length <= max ? text : text.substring(0, max);

  static String? _preview(Object? value) {
    if (value == null) return null;
    final text = value is String ? value : jsonEncode(value);
    return _clip(text.replaceAll(RegExp(r'\s+'), ' ').trim(), 60);
  }
}

/// Tables a reminder may hang on (never `tasks`: an approved suggestion is
/// a checklist line, not a task of the home panel).
const Set<String> planOwnerTables = {'habits', 'custom_modules', 'learning_goals', 'meal_slots'};

/// What the plan itself introduces, so one item may point at another's.
class _Locals {
  _Locals(this.items)
    : ids = {for (final i in items) i.id},
      foods = {
        for (final i in items)
          if (i.kind == PlanItemKind.food) ...[i.id, HealthGuard.fold(i.title)],
      },
      slots = {
        for (final i in items)
          if (i.kind == PlanItemKind.mealChange && i.data['op'] == 'newSlot') ...[
            i.id,
            if (i.str('slotName') != null) HealthGuard.fold(i.str('slotName')!),
          ],
      };

  final List<PlanItem> items;
  final Set<String> ids;

  /// Ids and folded names of foods this plan adds.
  final Set<String> foods;

  /// Ids and folded names of meals this plan adds.
  final Set<String> slots;

  /// Whether [id] can be reached from itself through `dependsOn`.
  bool inCycle(String id) {
    final deps = {for (final i in items) i.id: i.dependsOn};
    final stack = <String>[...?deps[id]];
    final seen = <String>{};
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      if (current == id) return true;
      if (!seen.add(current)) continue;
      stack.addAll(deps[current] ?? const []);
    }
    return false;
  }
}
