/// Everything that can be wrong with a plan, as codes the UI turns into
/// plain Arabic sentences (`AiBridgeTexts.problem`). Pure Dart: the engine
/// never builds user-facing text itself, exactly as the prototype importer
/// reports [ImportIssueCode]s.
library;

import 'package:meta/meta.dart';

enum PlanProblemCode {
  /// Not JSON at all (he pasted a chat reply, or the file is truncated).
  notJson,

  /// Valid JSON, but not an object.
  notAnObject,

  /// No `"madar": "plan"` marker – this is some other file.
  notAMadarPlan,

  /// `version` missing, not an integer, or from a newer Madar.
  unsupportedVersion,

  /// Bigger than [PlanLimits.maxPayloadBytes].
  tooBig,

  /// Nested deeper than [PlanLimits.maxDepth].
  tooDeep,

  /// Text after the JSON object (trailing junk).
  trailingText,

  /// `items` missing, not a list, or empty.
  noItems,

  /// More than [PlanLimits.maxItems] items.
  tooManyItems,

  /// Two items share one `id`.
  duplicateItemId,

  /// A required field is missing.
  missingField,

  /// **The** rule: an item with no reason is invalid.
  missingReason,

  /// A field is there but is the wrong JSON type.
  wrongType,

  /// A text is only spaces.
  blankText,

  /// A text is longer than its limit.
  tooLong,

  /// A key this contract does not know (how free text we never sent is kept
  /// out).
  unknownField,

  /// `kind` is not one of [PlanItemKind].
  unknownKind,

  /// An enum-like value (`window`, `op`, `scale`, `period`) is unknown.
  unknownValue,

  /// A number is outside its documented range.
  outOfRange,

  /// Not a `yyyy-MM-dd` day, or too far from today.
  badDay,

  /// Not a `HH:mm` time.
  badTime,

  /// A weekday outside 1‥7, or repeated.
  badWeekday,

  /// A reference names something he does not have.
  unknownReference,

  /// `dependsOn` names an item that is not in this plan.
  missingDependency,

  /// `dependsOn` goes round in a circle.
  circularDependency,

  /// A control character inside a text.
  controlCharacters,

  /// Medical advice: a diagnosis, a treatment, a medicine or a dose.
  healthAdvice,

  /// Not a rejection: this kind is accepted and shown, and a later version
  /// applies it (Part 5's kitchen).
  deferredKind,
}

/// One problem, with where it is and what it is about. [detail] carries the
/// raw value so the Arabic sentence can quote it («مصروف ما عندك: مطاعم»).
@immutable
class PlanProblem {
  const PlanProblem(this.code, {this.itemId, this.path, this.detail, this.limit});

  final PlanProblemCode code;

  /// The item's `id`, or null for a problem with the whole payload.
  final String? itemId;

  /// JSON path (`items[2].data.newAmount`).
  final String? path;

  /// The offending value, field name or reference.
  final String? detail;

  /// The limit that was passed, for the sentences that quote one.
  final num? limit;

  /// Whether this problem makes the payload unusable as a whole (as opposed
  /// to refusing one item).
  bool get isFatal =>
      itemId == null && code != PlanProblemCode.deferredKind && code != PlanProblemCode.trailingText;

  /// Whether the problem refuses the item it belongs to.
  bool get rejects => code != PlanProblemCode.deferredKind;

  Map<String, Object?> toJson() => {
    'code': code.name,
    'itemId': ?itemId,
    'path': ?path,
    'detail': ?detail,
    if (limit != null) 'limit': limit,
  };

  @override
  String toString() => 'PlanProblem(${code.name} ${itemId ?? ''} ${path ?? ''} ${detail ?? ''})';
}
