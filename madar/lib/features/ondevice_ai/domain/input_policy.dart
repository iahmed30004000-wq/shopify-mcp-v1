/// What happens to a very long input (a whole day of chat, a long summary).
///
/// A phone model has a small context window and a slow first token; a day
/// with two hundred lines must not become a minute of waiting or an
/// out-of-memory. The policy, written down so it can be tested and explained:
///
///  1. [ModelRequest.instructions] are never cut. If they alone are longer
///     than the budget the request is refused ([InputTooLong]) and the router
///     uses the bridge.
///  2. The input gets what is left of [maxChars] after the instructions
///     (never less than [minInputChars]).
///  3. When it does not fit, the **oldest lines are dropped first** (a day's
///     chat: what he said last matters most), whole lines at a time, and the
///     cut is marked with one fixed line so the model knows the start is
///     missing. A single line longer than the budget keeps its end.
///  4. The result says that it was cut and by how much, so the screen can
///     tell him («اختصرنا المحادثة الطويلة») instead of hiding it.
library;

import 'package:meta/meta.dart';

import 'on_device_model.dart';

/// Stands in for the dropped lines. Plain ASCII on purpose: it is read by the
/// model, not shown to the owner.
const String truncationMarker = '[... earlier lines omitted ...]';

@immutable
class TruncatedRequest {
  const TruncatedRequest(this.request, {required this.droppedChars});

  final ModelRequest request;

  /// Characters of the input that were left out (0 = untouched).
  final int droppedChars;

  bool get wasTruncated => droppedChars > 0;
}

/// The instructions alone use up the whole budget.
class InputTooLong implements Exception {
  const InputTooLong();

  @override
  String toString() => 'InputTooLong';
}

@immutable
class InputPolicy {
  const InputPolicy({this.maxChars = 12000, this.minInputChars = 500});

  /// Instructions plus input, in characters. ≈ 3000 tokens of Arabic; a
  /// placeholder until the real first-token time is measured.
  final int maxChars;

  /// Room the input must keep. Instructions leaving less than this are too
  /// long.
  final int minInputChars;

  TruncatedRequest apply(ModelRequest request) {
    final room = maxChars - request.instructions.length;
    if (room < minInputChars) throw const InputTooLong();
    final input = request.input;
    if (input.length <= room) return TruncatedRequest(request, droppedChars: 0);

    final budget = room - truncationMarker.length - 1;
    final lines = input.split('\n');
    final kept = <String>[];
    var used = 0;
    for (var i = lines.length - 1; i >= 0; i--) {
      final cost = lines[i].length + (kept.isEmpty ? 0 : 1);
      if (used + cost > budget) {
        if (kept.isEmpty) {
          // One huge line: keep its end.
          kept.add(lines[i].substring(lines[i].length - budget));
          used = budget;
        }
        break;
      }
      kept.add(lines[i]);
      used += cost;
    }
    final text = '$truncationMarker\n${kept.reversed.join('\n')}';
    return TruncatedRequest(request.withInput(text), droppedChars: input.length - used);
  }
}
