// The documented policy for a very long input.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ondevice_ai/domain/input_policy.dart';
import 'package:madar/features/ondevice_ai/domain/on_device_model.dart';

void main() {
  const policy = InputPolicy(maxChars: 1000, minInputChars: 100);

  String lines(int n) => [for (var i = 0; i < n; i++) 'line-${i.toString().padLeft(3, '0')} ${'x' * 30}'].join('\n');

  test('an input that fits is untouched', () {
    final r = policy.apply(const ModelRequest(instructions: 'rules', input: 'short chat'));
    expect(r.wasTruncated, isFalse);
    expect(r.request.input, 'short chat');
    expect(r.droppedChars, 0);
  });

  test('a long chat loses its OLDEST lines first, in whole lines, marked', () {
    final input = lines(100);
    final r = policy.apply(ModelRequest(instructions: 'r' * 200, input: input));
    expect(r.wasTruncated, isTrue);
    final out = r.request.input;
    expect(out, startsWith(truncationMarker));
    expect(out.contains('line-099'), isTrue, reason: 'the newest line survives');
    expect(out.contains('line-000'), isFalse, reason: 'the oldest is dropped');
    expect(200 + out.length, lessThanOrEqualTo(1000), reason: 'instructions + input fit the budget');
    // Whole lines only: every kept line is a complete original line.
    final kept = out.split('\n').skip(1);
    for (final k in kept) {
      expect(input.split('\n'), contains(k));
    }
    // The kept lines are the LAST ones, contiguous.
    final all = input.split('\n');
    expect(kept.toList(), all.sublist(all.length - kept.length));
    expect(r.droppedChars, input.length - kept.join('\n').length);
  });

  test('the instructions are never cut', () {
    final r = policy.apply(ModelRequest(instructions: 'RULES' * 20, input: lines(100)));
    expect(r.request.instructions, 'RULES' * 20);
  });

  test('instructions that leave no room for the input are refused', () {
    expect(
      () => policy.apply(ModelRequest(instructions: 'r' * 950, input: 'hello')),
      throwsA(isA<InputTooLong>()),
    );
  });

  test('one single huge line keeps its end', () {
    final big = '${'a' * 3000}END';
    final r = policy.apply(ModelRequest(instructions: 'r', input: big));
    expect(r.request.input, startsWith(truncationMarker));
    expect(r.request.input, endsWith('END'));
    expect(1 + r.request.input.length, lessThanOrEqualTo(1000));
  });

  test('exactly at the limit nothing is dropped', () {
    final input = 'y' * (1000 - 10);
    final r = policy.apply(ModelRequest(instructions: 'r' * 10, input: input));
    expect(r.wasTruncated, isFalse);
  });
}
